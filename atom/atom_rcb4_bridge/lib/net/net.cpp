#include "net.h"

#include <ESPmDNS.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <WebServer.h>
#include <string.h>

#include "web_page.h"

namespace net {
namespace {

/// The port the control protocol listens on. Arbitrary, but fixed: the PC
/// finds the device by mDNS or by the QR code, not by scanning ports.
constexpr uint16_t PORT = 9000;

/// Advertised over mDNS as `kxr-hand.local`, so the PC needs no address.
constexpr char HOSTNAME[] = "kxr-hand";
constexpr char SERVICE[] = "kxrhand";

/// How long one connection attempt is given before it counts as failed, and
/// how long to wait before trying again. Retrying matters more than it looks:
/// an AP that reboots should not leave the robot needing a power cycle.
constexpr uint32_t CONNECT_TIMEOUT_MS = 15000;
constexpr uint32_t RETRY_INTERVAL_MS = 10000;

/// A peer is forgotten after this long, so telemetry stops being sent into
/// the dark when the operator's program exits.
constexpr uint32_t PEER_TIMEOUT_MS = 5000;

Preferences prefs;
WiFiUDP udp;
WebServer server(80);
bool g_http_open = false;

/// Core 0 runs the Wi-Fi stack, and Arduino's loop() -- with the control loop
/// in it -- runs on core 1. Putting the server task next to the radio keeps
/// the two apart.
constexpr BaseType_t SERVER_CORE = 0;
/// WebServer builds Strings and parses headers; 6 KiB is what that wants
/// without being generous with a heap the Wi-Fi stack has already taken
/// 52 KiB of.
constexpr uint32_t SERVER_STACK = 6144;
/// Below the Arduino loop's priority, so the control loop wins a tie.
constexpr UBaseType_t SERVER_PRIORITY = 1;
TaskHandle_t g_server_task = nullptr;

/// Guards the two things both cores touch. Held for a handful of memcpys and
/// never across anything that blocks.
portMUX_TYPE g_shared = portMUX_INITIALIZER_UNLOCKED;

/// What the page and the display show, published by the control loop.
struct Published {
    Telemetry t = {};
    Debug debug = {};
};
Published g_telemetry;

/// One command waiting to be picked up. One slot, not a queue: a command is a
/// setpoint, so the newest is the only one worth having and an older one
/// arriving late would fight the operator's hand.
constexpr size_t COMMAND_SIZE = 9;
uint8_t g_command[COMMAND_SIZE];
bool g_command_pending = false;
bool g_command_from_udp = false;

Status g_status = Status::UNCONFIGURED;
String g_ssid;
String g_password;
bool g_stored = false;
String g_url;
uint32_t g_deadline_ms = 0;
uint32_t g_retry_at_ms = 0;
bool g_udp_open = false;

/// Why the last disconnection happened, straight from the driver. WiFi
/// .status() only ever says "disconnected", which is the same answer for a
/// wrong password, a refused association and an access point that went away.
/// The reason code is the one thing that tells them apart.
uint8_t g_disconnect_reason = 0;

const char* reasonText(uint8_t reason) {
    switch (reason) {
        case 2:   return "auth leave";
        case 4:   return "assoc expire";
        case 15:  return "4-way handshake timeout: WRONG PASSWORD";
        case 200: return "beacon timeout";
        case 201: return "no AP found";
        case 202: return "auth fail: WRONG PASSWORD";
        case 203: return "assoc fail";
        case 204: return "handshake timeout: WRONG PASSWORD";
        case 205: return "connection lost";
        default:  return "";
    }
}

IPAddress g_peer_ip;
uint16_t g_peer_port = 0;
uint32_t g_peer_seen_ms = 0;

void onWiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info) {
    if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
        g_disconnect_reason = info.wifi_sta_disconnected.reason;
    }
}

void startConnecting() {
    // The Wi-Fi driver keeps its own copy of whatever it is asked to join,
    // in NVS, and does so by default -- WiFiGenericClass::_persistent is
    // true, and only a false there reaches esp_wifi_set_storage(RAM). So
    // without this line the password is written down twice: once here on
    // purpose, and once by a layer that was never asked. One place is
    // strictly better than two, whichever place it is.
    //
    // Must come before the first WiFi call: the storage mode is fixed during
    // low-level init, which the mode change below triggers.
    WiFi.persistent(false);
    WiFi.onEvent(onWiFiEvent);
    WiFi.mode(WIFI_STA);
    WiFi.setHostname(HOSTNAME);
    // The radio is next to a control loop with a 33 ms budget; sleeping the
    // Wi-Fi saves power this robot is not short of and adds latency it is.
    WiFi.setSleep(false);
    WiFi.begin(g_ssid.c_str(), g_password.c_str());
    g_status = Status::CONNECTING;
    g_deadline_ms = millis() + CONNECT_TIMEOUT_MS;
}

int hexDigit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/// The page's one request, served on core 0.
///
/// Answers from the published snapshot rather than reaching into the control
/// loop, and leaves the command in a slot for that loop to find. Neither side
/// waits for the other.
void handleCommandRequest() {
    const String hex = server.hasArg("f") ? server.arg("f") : String();
    bool accepted = false;
    if (hex.length() == COMMAND_SIZE * 2) {
        uint8_t frame[COMMAND_SIZE];
        bool ok = true;
        for (size_t i = 0; i < COMMAND_SIZE && ok; i++) {
            const int hi = hexDigit(hex[i * 2]);
            const int lo = hexDigit(hex[i * 2 + 1]);
            if (hi < 0 || lo < 0) {
                ok = false;
            } else {
                frame[i] = static_cast<uint8_t>((hi << 4) | lo);
            }
        }
        if (ok) {
            portENTER_CRITICAL(&g_shared);
            memcpy(g_command, frame, sizeof(frame));
            g_command_pending = true;
            g_command_from_udp = false;
            portEXIT_CRITICAL(&g_shared);
            accepted = true;
        }
    }

    Published snapshot;
    portENTER_CRITICAL(&g_shared);
    snapshot = g_telemetry;
    portEXIT_CRITICAL(&g_shared);
    const bool live = snapshot.t.updated_ms != 0 &&
                      millis() - snapshot.t.updated_ms < 1000;

    char body[352];
    snprintf(body, sizeof(body),
             "{\"state\":%u,\"vx\":%.3f,\"wz\":%.3f,\"loop_ms\":%.1f,"
             "\"err\":%lu,\"over\":%lu,\"draw_ms\":%.1f,"
             "\"req\":%u,\"actor\":%u,\"seq\":%u,"
             "\"quiet\":%lu,\"rx\":%lu,\"step\":%lu,"
             "\"try\":%u,\"home_err\":%d,"
             "\"live\":%s,\"ok\":%s}",
             static_cast<unsigned>(snapshot.t.state), snapshot.t.vx, snapshot.t.wz,
             snapshot.t.loop_us / 1000.0f,
             static_cast<unsigned long>(snapshot.t.errors),
             static_cast<unsigned long>(snapshot.t.overruns),
             snapshot.t.draw_us / 1000.0f,
             static_cast<unsigned>(snapshot.debug.request),
             static_cast<unsigned>(snapshot.debug.actor),
             static_cast<unsigned>(snapshot.debug.sequence_step),
             static_cast<unsigned long>(snapshot.debug.quiet_ms),
             static_cast<unsigned long>(snapshot.debug.host_frames),
             static_cast<unsigned long>(snapshot.debug.step),
             static_cast<unsigned>(snapshot.debug.homing_attempt),
             static_cast<int>(snapshot.debug.home_err),
             live ? "true" : "false", accepted ? "true" : "false");
    server.send(200, "application/json", body);
}

void serverTask(void*) {
    for (;;) {
        server.handleClient();
        // A yield rather than a spin: the radio and lwIP share this core, and
        // a task that never sleeps starves them.
        vTaskDelay(pdMS_TO_TICKS(2));
    }
}

void startServerTask() {
    if (g_server_task != nullptr) return;
    xTaskCreatePinnedToCore(serverTask, "kxr-http", SERVER_STACK, nullptr,
                            SERVER_PRIORITY, &g_server_task, SERVER_CORE);
}

void onConnected() {
    g_status = Status::CONNECTED;
    g_url = "http://" + WiFi.localIP().toString();
    if (!g_udp_open) {
        udp.begin(PORT);
        g_udp_open = true;
    }
    // mDNS is for the PC, which has a resolver; the phone gets the QR code,
    // because iOS will not resolve .local from a browser reliably.
    if (!g_http_open) {
        server.on("/", []() {
            server.send_P(200, "text/html", kWebPage);
        });
        server.on("/c", handleCommandRequest);
        server.onNotFound([]() { server.send(404, "text/plain", "no"); });
        server.begin();
        g_http_open = true;
    }
    startServerTask();
    if (MDNS.begin(HOSTNAME)) {
        MDNS.addService(SERVICE, "udp", PORT);
        MDNS.addService("http", "tcp", 80);
    }
}

}  // namespace

void begin() {
    // Opened read-write even though nothing is written here: a read-only open
    // of a namespace that does not exist yet fails, and the failure is logged
    // -- onto the USB CDC that carries the binary control protocol, in the
    // middle of a reply. Creating it costs nothing and says nothing.
    prefs.begin("kxrnet", /*readOnly=*/false);
    g_ssid = prefs.getString("ssid", "");
    g_password = prefs.getString("pass", "");
    prefs.end();
    g_stored = g_ssid.length() > 0;
    if (!g_stored) {
        g_status = Status::UNCONFIGURED;
        return;
    }
    startConnecting();
}

void poll() {
    switch (g_status) {
        case Status::UNCONFIGURED:
            return;
        case Status::CONNECTING:
            if (WiFi.status() == WL_CONNECTED) {
                onConnected();
            } else if (static_cast<int32_t>(millis() - g_deadline_ms) >= 0) {
                g_status = Status::FAILED;
                g_retry_at_ms = millis() + RETRY_INTERVAL_MS;
            }
            return;
        case Status::FAILED:
            if (static_cast<int32_t>(millis() - g_retry_at_ms) >= 0) {
                startConnecting();
            }
            return;
        case Status::CONNECTED:
            if (WiFi.status() != WL_CONNECTED) {
                g_status = Status::FAILED;
                g_retry_at_ms = millis() + RETRY_INTERVAL_MS;
                g_url = "";
            }
            return;
    }
}

Status status() { return g_status; }
IPAddress ip() { return WiFi.localIP(); }
const char* ssid() { return g_ssid.c_str(); }
const char* url() { return g_url.c_str(); }

void configure(const char* ssid_in, const char* password_in) {
    prefs.begin("kxrnet", /*readOnly=*/false);
    prefs.putString("ssid", ssid_in);
    prefs.putString("pass", password_in);
    prefs.end();
    g_stored = ssid_in[0] != '\0';
    g_ssid = ssid_in;
    g_password = password_in;
    g_url = "";
    if (g_ssid.length() == 0) {
        WiFi.disconnect(true);
        g_status = Status::UNCONFIGURED;
        return;
    }
    startConnecting();
}

void connect(const char* ssid_in, const char* password_in) {
    // Anything previously written down is erased, so "not stored" is true of
    // the device and not merely of this session.
    prefs.begin("kxrnet", /*readOnly=*/false);
    prefs.remove("ssid");
    prefs.remove("pass");
    prefs.end();
    g_stored = false;
    g_ssid = ssid_in;
    g_password = password_in;
    g_url = "";
    if (g_ssid.length() == 0) {
        WiFi.disconnect(true);
        g_status = Status::UNCONFIGURED;
        return;
    }
    startConnecting();
}

bool credentialsStored() { return g_stored; }

void setTelemetry(uint8_t state, float vx, float wz, uint32_t loop_us,
                  uint32_t errors, uint32_t overruns, uint32_t draw_us,
                  const Debug& debug) {
    portENTER_CRITICAL(&g_shared);
    g_telemetry.t.state = state;
    g_telemetry.t.vx = vx;
    g_telemetry.t.wz = wz;
    g_telemetry.t.loop_us = loop_us;
    g_telemetry.t.errors = errors;
    g_telemetry.t.overruns = overruns;
    g_telemetry.t.draw_us = draw_us;
    g_telemetry.debug = debug;
    g_telemetry.t.updated_ms = millis();
    portEXIT_CRITICAL(&g_shared);
}

bool policyLive() {
    uint32_t updated;
    portENTER_CRITICAL(&g_shared);
    updated = g_telemetry.t.updated_ms;
    portEXIT_CRITICAL(&g_shared);
    return updated != 0 && millis() - updated < 1000;
}

bool lastCommandWasUdp() { return g_command_from_udp; }

Telemetry telemetry() {
    Telemetry out;
    portENTER_CRITICAL(&g_shared);
    out = g_telemetry.t;
    portEXIT_CRITICAL(&g_shared);
    return out;
}

bool receiveCommand(uint8_t* frame, size_t len) {
    if (len != COMMAND_SIZE) return false;

    // UDP is read here, on the control loop's core: it is a socket read with
    // no server behind it, and moving it would buy nothing.
    if (g_udp_open) {
        const int size = udp.parsePacket();
        if (size > 0) {
            if (static_cast<size_t>(size) == len &&
                udp.read(frame, len) == static_cast<int>(len)) {
                g_peer_ip = udp.remoteIP();
                g_peer_port = udp.remotePort();
                g_peer_seen_ms = millis();
                g_command_from_udp = true;
                return true;
            }
            // One inbound frame size means anything else is not this
            // protocol. Draining it keeps the socket from stalling on it.
            uint8_t sink[64];
            while (udp.available() > 0) udp.read(sink, sizeof(sink));
        }
    }

    // Then whatever the server task left, which it has already answered.
    bool got = false;
    portENTER_CRITICAL(&g_shared);
    if (g_command_pending) {
        memcpy(frame, g_command, COMMAND_SIZE);
        g_command_pending = false;
        g_command_from_udp = false;
        got = true;
    }
    portEXIT_CRITICAL(&g_shared);
    return got;
}

void send(const uint8_t* frame, size_t len) {
    if (!g_udp_open || !hasPeer()) return;
    udp.beginPacket(g_peer_ip, g_peer_port);
    udp.write(frame, len);
    udp.endPacket();
}

bool hasPeer() {
    return g_peer_port != 0 && millis() - g_peer_seen_ms < PEER_TIMEOUT_MS;
}

}  // namespace net

namespace net {

bool handleSetupLine(const char* line, Print& out) {
    if (strcmp(line, "net?") == 0) {
        // wl is the Wi-Fi driver's own view, which says WHY rather than
        // just that it has not worked: 1 = the SSID was never seen (wrong
        // name, or a 5 GHz-only network this radio cannot reach), 4 = seen
        // but the key was rejected, 6 = disconnected.
        out.printf("ssid=%s status=%d wl=%d ip=%s stored=%d\n", ssid(),
                   static_cast<int>(status()),
                   static_cast<int>(WiFi.status()),
                   ip().toString().c_str(), credentialsStored() ? 1 : 0);
        out.printf("last disconnect reason=%u %s\n", g_disconnect_reason,
                   reasonText(g_disconnect_reason));
        out.printf("password length stored=%u\nOK\n",
                   static_cast<unsigned>(g_password.length()));
        return true;
    }
    if (strcmp(line, "net!") == 0) {
        configure("", "");
        out.println("OK cleared");
        return true;
    }
    if (strcmp(line, "net scan") == 0) {
        // What the radio can actually see, which is the first thing worth
        // knowing when a connection never completes. The ESP32-S3 has no
        // 5 GHz radio, so an access point that is not in this list is not one
        // it can ever join, whatever the password is.
        // A connection attempt in progress owns the radio, and a scan on top
        // of it fails rather than waiting. Stopping first is what makes the
        // answer mean anything; the retry timer brings the connection back.
        WiFi.disconnect(false, false);
        delay(100);
        const int found = WiFi.scanNetworks(/*async=*/false, /*hidden=*/true);
        // Not "no networks": scanNetworks returns -1 while one is already
        // running and -2 when it could not start, and reporting either of
        // those as an empty room is how a broken radio passes for a quiet
        // one.
        if (found < 0) {
            out.printf("scan did not run (%d: %s)\n", found,
                       found == -1 ? "one was already running"
                                   : "could not start");
        } else if (found == 0) {
            out.println("0 networks -- the radio ran a scan and heard nothing");
        } else {
            out.printf("%d networks:\n", found);
        }
        for (int i = 0; i < found; i++) {
            out.printf("%-32s ch%-3d %4d dBm %s\n", WiFi.SSID(i).c_str(),
                       WiFi.channel(i), WiFi.RSSI(i),
                       WiFi.encryptionType(i) == WIFI_AUTH_OPEN ? "open"
                       : WiFi.encryptionType(i) == WIFI_AUTH_WPA2_ENTERPRISE
                               ? "WPA2-ENTERPRISE (not supported)"
                               : "password");
        }
        WiFi.scanDelete();
        // Put the connection attempt back, since the scan tore it down --
        // through startConnecting(), which still has the password. Calling
        // WiFi.begin() from here would have to pass one, and passing none
        // would quietly try to join as though the network were open.
        if (g_ssid.length() > 0) startConnecting();
        out.println("OK");
        return true;
    }
    if (strncmp(line, "net ", 4) != 0) return false;

    // net <ssid>TAB<password>[TABvolatile]
    char buf[96];
    strncpy(buf, line + 4, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    char* ssid_in = buf;
    const char* password = "";
    const char* mode = "";
    char* tab = strchr(ssid_in, '\t');
    if (tab != nullptr) {
        *tab = '\0';
        password = tab + 1;
        char* tab2 = strchr(tab + 1, '\t');
        if (tab2 != nullptr) {
            *tab2 = '\0';
            mode = tab2 + 1;
        }
    }
    const bool keep = strcmp(mode, "volatile") != 0;
    if (keep) {
        configure(ssid_in, password);
    } else {
        connect(ssid_in, password);
    }
    out.printf("OK connecting to %s (%s)\n", ssid_in,
               keep ? "stored in NVS" : "not stored, lost on reset");
    return true;
}

}  // namespace net
