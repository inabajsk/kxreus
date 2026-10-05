// M5Camera Wi-Fi JPEG streamer.
//
// TCP :8000 (one client at a time), device -> PC, little-endian:
//   "M5CF" u32 seq  u64 capture_us  u64 send_us  u32 len  <len bytes JPEG>
//   capture_us/send_us are esp_timer_get_time() (us since boot); the PC maps
//   them to its own clock with the UDP time sync below.
// PC -> device over the same TCP socket, one ASCII line each:
//   "fs <n>"   framesize_t (5=QVGA 8=VGA 9=SVGA 10=XGA ...)
//   "q <n>"    JPEG quality 4..63 (lower = better)
// UDP :8001  PC sends "PING"+u64 pc_us, device answers "PONG"+u64 pc_us+u64 esp_us
//            from its own task, so the reply never queues behind a frame.
// UDP :8002  device broadcasts "M5CAM <ip> 8000" once a second for discovery.
// Serial     "wifi <ssid> <pass>", "info", "reboot".

#include <Arduino.h>
#include <ESPmDNS.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <esp_camera.h>
#include <esp_timer.h>

namespace {

constexpr uint16_t TCP_PORT = 8000;
constexpr uint16_t SYNC_PORT = 8001;
constexpr uint16_t BEACON_PORT = 8002;
constexpr char HOSTNAME[] = "m5camera";

// M5Camera came in two pinouts that differ only in SIOD/VSYNC; which one this
// unit is gets found at boot by trying both.
struct PinSet {
  const char *name;
  int siod, vsync;
};
constexpr PinSet kPinSets[] = {
    {"M5Camera A (SIOD25/VSYNC22)", 25, 22},
    {"M5Camera B (SIOD22/VSYNC25)", 22, 25},
};

Preferences prefs;
WiFiServer server(TCP_PORT);
WiFiUDP syncUdp;
WiFiUDP beaconUdp;
String serialLine;
const char *g_pinset = "none";

bool initCamera(const PinSet &p) {
  camera_config_t c = {};
  c.pin_pwdn = -1;
  c.pin_reset = 15;
  c.pin_xclk = 27;
  c.pin_sccb_sda = p.siod;
  c.pin_sccb_scl = 23;
  c.pin_d7 = 19;
  c.pin_d6 = 36;
  c.pin_d5 = 18;
  c.pin_d4 = 39;
  c.pin_d3 = 5;
  c.pin_d2 = 34;
  c.pin_d1 = 35;
  c.pin_d0 = 32;
  c.pin_vsync = p.vsync;
  c.pin_href = 26;
  c.pin_pclk = 21;
  c.xclk_freq_hz = 20000000;
  c.ledc_timer = LEDC_TIMER_0;
  c.ledc_channel = LEDC_CHANNEL_0;
  c.pixel_format = PIXFORMAT_JPEG;
  c.frame_size = (framesize_t)prefs.getUChar("fs", FRAMESIZE_VGA);
  c.jpeg_quality = prefs.getUChar("q", 12);
  c.fb_count = 2;
  c.fb_location = CAMERA_FB_IN_PSRAM;
  // Always hand out the newest frame: a stale one only adds latency.
  c.grab_mode = CAMERA_GRAB_LATEST;
  return esp_camera_init(&c) == ESP_OK;
}

bool startCamera() {
  for (const PinSet &p : kPinSets) {
    if (initCamera(p)) {
      g_pinset = p.name;
      Serial.printf("camera ok: %s\n", p.name);
      return true;
    }
    esp_camera_deinit();
    delay(100);
  }
  Serial.println("camera init FAILED on every pinout");
  return false;
}

void printInfo() {
  sensor_t *s = esp_camera_sensor_get();
  Serial.printf("ssid=%s status=%d ip=%s rssi=%d pins=%s fs=%d q=%d psram=%u\n",
                prefs.getString("ssid", "").c_str(), WiFi.status(),
                WiFi.localIP().toString().c_str(), WiFi.RSSI(), g_pinset,
                s ? s->status.framesize : -1, s ? s->status.quality : -1,
                (unsigned)ESP.getFreePsram());
}

void connectWifi() {
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("pass", "");
  if (ssid.isEmpty()) {
    Serial.println("no wifi configured: send \"wifi <ssid> <pass>\"");
    return;
  }
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);  // modem sleep costs tens of ms per frame
  WiFi.setHostname(HOSTNAME);
  WiFi.begin(ssid.c_str(), pass.c_str());
  Serial.printf("connecting to %s\n", ssid.c_str());
}

void handleSerialLine(const String &line) {
  if (line.startsWith("wifi ")) {
    String rest = line.substring(5);
    int sp = rest.indexOf(' ');
    String ssid = sp < 0 ? rest : rest.substring(0, sp);
    String pass = sp < 0 ? "" : rest.substring(sp + 1);
    prefs.putString("ssid", ssid);
    prefs.putString("pass", pass);
    Serial.printf("saved wifi ssid=%s\n", ssid.c_str());
    WiFi.disconnect();
    connectWifi();
  } else if (line == "info") {
    printInfo();
  } else if (line == "reboot") {
    ESP.restart();
  } else if (line.length()) {
    Serial.println("commands: wifi <ssid> <pass> | info | reboot");
  }
}

void pollSerial() {
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\r') continue;
    if (ch == '\n') {
      handleSerialLine(serialLine);
      serialLine = "";
    } else if (serialLine.length() < 200) {
      serialLine += ch;
    }
  }
}

void handleClientLine(const String &line) {
  sensor_t *s = esp_camera_sensor_get();
  if (!s) return;
  int v = line.substring(line.indexOf(' ') + 1).toInt();
  if (line.startsWith("fs ") && v >= FRAMESIZE_96X96 && v <= FRAMESIZE_UXGA) {
    s->set_framesize(s, (framesize_t)v);
    prefs.putUChar("fs", v);
  } else if (line.startsWith("q ") && v >= 4 && v <= 63) {
    s->set_quality(s, v);
    prefs.putUChar("q", v);
  }
}

// Time sync + discovery beacon, on its own task so neither waits on a frame
// being pushed out over TCP.
void netTask(void *) {
  uint32_t lastBeacon = 0;
  bool bound = false;
  for (;;) {
    if (WiFi.status() != WL_CONNECTED) {
      bound = false;
      vTaskDelay(pdMS_TO_TICKS(100));
      continue;
    }
    if (!bound) {
      syncUdp.begin(SYNC_PORT);
      bound = true;
    }
    int n = syncUdp.parsePacket();
    if (n == 12) {
      uint8_t in[12];
      syncUdp.read(in, 12);
      if (memcmp(in, "PING", 4) == 0) {
        uint8_t out[20];
        int64_t now = esp_timer_get_time();
        memcpy(out, "PONG", 4);
        memcpy(out + 4, in + 4, 8);
        memcpy(out + 12, &now, 8);
        syncUdp.beginPacket(syncUdp.remoteIP(), syncUdp.remotePort());
        syncUdp.write(out, sizeof(out));
        syncUdp.endPacket();
      }
    } else if (n > 0) {
      syncUdp.flush();
    }
    if (millis() - lastBeacon > 1000) {
      lastBeacon = millis();
      char msg[48];
      int len = snprintf(msg, sizeof(msg), "M5CAM %s %u",
                         WiFi.localIP().toString().c_str(), TCP_PORT);
      beaconUdp.beginPacket(IPAddress(255, 255, 255, 255), BEACON_PORT);
      beaconUdp.write((const uint8_t *)msg, len);
      beaconUdp.endPacket();
    }
    vTaskDelay(1);
  }
}

bool writeAll(WiFiClient &c, const uint8_t *p, size_t n) {
  uint32_t start = millis();
  while (n) {
    size_t w = c.write(p, n);
    if (w == 0) {
      if (!c.connected() || millis() - start > 3000) return false;
      delay(1);
      continue;
    }
    p += w;
    n -= w;
  }
  return true;
}

void streamTo(WiFiClient &client) {
  client.setNoDelay(true);
  Serial.printf("client %s connected\n", client.remoteIP().toString().c_str());
  uint32_t seq = 0;
  String line;
  while (client.connected()) {
    pollSerial();
    while (client.available()) {
      char ch = client.read();
      if (ch == '\n') {
        handleClientLine(line);
        line = "";
      } else if (line.length() < 32) {
        line += ch;
      }
    }
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
      delay(5);
      continue;
    }
    uint8_t hdr[28];
    int64_t cap = (int64_t)fb->timestamp.tv_sec * 1000000 + fb->timestamp.tv_usec;
    int64_t now = esp_timer_get_time();
    uint32_t len = fb->len;
    memcpy(hdr, "M5CF", 4);
    memcpy(hdr + 4, &seq, 4);
    memcpy(hdr + 8, &cap, 8);
    memcpy(hdr + 16, &now, 8);
    memcpy(hdr + 24, &len, 4);
    bool ok = writeAll(client, hdr, sizeof(hdr)) && writeAll(client, fb->buf, fb->len);
    esp_camera_fb_return(fb);
    if (!ok) break;
    seq++;
  }
  client.stop();
  Serial.println("client disconnected");
}

}  // namespace

void setup() {
  Serial.begin(115200);
  delay(200);
  prefs.begin("m5cam", false);
  Serial.println("\nM5Camera streamer");
  startCamera();
  connectWifi();
  xTaskCreatePinnedToCore(netTask, "net", 4096, nullptr, 2, nullptr, 0);
}

void loop() {
  static bool announced = false;
  pollSerial();
  if (WiFi.status() != WL_CONNECTED) {
    announced = false;
    delay(50);
    return;
  }
  if (!announced) {
    announced = true;
    server.begin();
    MDNS.begin(HOSTNAME);
    MDNS.addService("m5camera", "tcp", TCP_PORT);
    printInfo();
    Serial.printf("streaming on %s:%u (%s.local)\n",
                  WiFi.localIP().toString().c_str(), TCP_PORT, HOSTNAME);
  }
  WiFiClient client = server.available();
  if (client) streamTo(client);
  delay(5);
}
