// Does a radio still fit next to the policy?
//
// The actor's weights live in SRAM -- 235 KiB of the AtomS3's 320 -- because
// reading them from flash costs 9.8 ms a forward pass instead of 3.0. That
// leaves little room, and every wireless option here wants some of it: the
// Wi-Fi driver, and on top of it lwIP for anything speaking UDP.
//
// This measures what is actually left, in the order the options cost:
// bare, then with the weights, then Wi-Fi station, then ESP-NOW, then a
// SoftAP with a UDP socket open. Anything that fails to initialise says so
// rather than being inferred from a heap number.
//
//   pio run -e wifi-probe -t upload -t monitor

#include <Arduino.h>
#include <M5Unified.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <esp_now.h>
#include <policy.h>

namespace {

WiFiUDP udp;

void report(const char* stage) {
    Serial.printf("%-34s free heap %7u   largest block %7u   min ever %7u\n",
                  stage, ESP.getFreeHeap(), ESP.getMaxAllocHeap(),
                  ESP.getMinFreeHeap());
}

void onSent(const uint8_t*, esp_now_send_status_t) {}

}  // namespace

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    Serial.begin(115200);
    const uint32_t deadline = millis() + 10000;
    while (!Serial && millis() < deadline) delay(10);
    delay(500);

    Serial.println("\n=== how much room is left beside the policy ===");
    report("after M5.begin");

    policy::begin();
    report("after policy::begin (weights)");

    // A forward pass, to be sure the weights are usable and not merely
    // allocated.
    float obs[POLICY_OBS_DIM] = {0.0f};
    float action[POLICY_ACT_DIM];
    policy::run(obs, action);
    Serial.printf("  policy runs: action[0] = %+.4f  weights in RAM: %s\n",
                  action[0], policy::weightsInRam() ? "yes" : "no");

    WiFi.mode(WIFI_STA);
    report("after WiFi.mode(WIFI_STA)");

    const esp_err_t now_err = esp_now_init();
    Serial.printf("  esp_now_init: %s\n", now_err == ESP_OK ? "OK" : "FAILED");
    if (now_err == ESP_OK) esp_now_register_send_cb(onSent);
    report("after esp_now_init");
    Serial.printf("  this device's STA MAC: %s\n", WiFi.macAddress().c_str());

    esp_now_deinit();
    WiFi.mode(WIFI_OFF);
    delay(200);
    report("after turning the radio off");

    // The other end of the choice: a SoftAP a phone can join, with lwIP and a
    // UDP socket on top of it.
    const bool ap = WiFi.softAP("kxr-hand", "kxrhand12345");
    Serial.printf("  softAP: %s  ip %s\n", ap ? "up" : "FAILED",
                  WiFi.softAPIP().toString().c_str());
    report("after softAP");

    udp.begin(9000);
    report("after UDP socket on :9000");

    // Whether it still has room to actually run: one forward pass and the
    // buffers a control step needs.
    const uint32_t t0 = micros();
    policy::run(obs, action);
    Serial.printf("\n  forward pass with the radio up: %lu us\n",
                  static_cast<unsigned long>(micros() - t0));
    report("after a forward pass");

    M5.Display.clear();
    M5.Display.setCursor(0, 0);
    M5.Display.setTextSize(2);
    M5.Display.printf("WIFI\nprobe\n\n%uk", ESP.getFreeHeap() / 1024);
}

void loop() { delay(1000); }
