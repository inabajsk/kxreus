#include "ble_link.h"

#include <NimBLEDevice.h>

namespace BleLink {
namespace {

NimBLEClient* g_client = nullptr;
NimBLERemoteCharacteristic* g_query_char = nullptr;
NimBLERemoteCharacteristic* g_response_char = nullptr;
volatile bool g_want_scan = true;

// Filled by the notify callback, read by query() -- the two run on
// different tasks (NimBLE's own host task delivers notifies; query()
// runs on whichever task called it), so both the buffer and the flag
// are only ever touched with g_mutex held.
SemaphoreHandle_t g_mutex = nullptr;
uint8_t g_response_buf[MAX_PAYLOAD];
size_t g_response_len = 0;
bool g_response_ready = false;

void onResponseNotify(NimBLERemoteCharacteristic*, uint8_t* data, size_t len,
                       bool) {
    xSemaphoreTake(g_mutex, portMAX_DELAY);
    const size_t n = len < MAX_PAYLOAD ? len : MAX_PAYLOAD;
    memcpy(g_response_buf, data, n);
    g_response_len = n;
    g_response_ready = true;
    xSemaphoreGive(g_mutex);
}

class ClientCallbacks : public NimBLEClientCallbacks {
    void onDisconnect(NimBLEClient*) override {
        g_query_char = nullptr;
        g_response_char = nullptr;
        g_want_scan = true;
    }
} g_client_callbacks;

/// Connects, discovers both characteristics, and subscribes to
/// RESPONSE's own notify -- everything a successful scan hit needs
/// before connected() can go true. Leaves g_client/g_query_char/
/// g_response_char null on any failure, so connected() stays false and
/// poll() knows to scan again.
void connectTo(NimBLEAdvertisedDevice* device) {
    if (g_client != nullptr) {
        NimBLEDevice::deleteClient(g_client);
        g_client = nullptr;
    }
    g_query_char = nullptr;
    g_response_char = nullptr;

    g_client = NimBLEDevice::createClient();
    g_client->setClientCallbacks(&g_client_callbacks, /*deleteCallbacks=*/false);
    if (!g_client->connect(device)) return;

    NimBLERemoteService* service = g_client->getService(SERVICE_UUID);
    if (service == nullptr) {
        g_client->disconnect();
        return;
    }
    g_query_char = service->getCharacteristic(QUERY_CHAR_UUID);
    g_response_char = service->getCharacteristic(RESPONSE_CHAR_UUID);
    if (g_query_char == nullptr || g_response_char == nullptr ||
        !g_response_char->canNotify()) {
        g_client->disconnect();
        g_query_char = nullptr;
        g_response_char = nullptr;
        return;
    }
    g_response_char->subscribe(/*notifications=*/true, onResponseNotify);
}

class ScanCallbacks : public NimBLEAdvertisedDeviceCallbacks {
    void onResult(NimBLEAdvertisedDevice* device) override {
        if (!device->isAdvertisingService(NimBLEUUID(SERVICE_UUID))) return;
        NimBLEDevice::getScan()->stop();
        connectTo(device);
    }
} g_scan_callbacks;

}  // namespace

void begin() {
    g_mutex = xSemaphoreCreateMutex();
    NimBLEDevice::init("");
    NimBLEScan* scan = NimBLEDevice::getScan();
    scan->setAdvertisedDeviceCallbacks(&g_scan_callbacks);
    scan->setInterval(97);
    scan->setWindow(37);
    scan->setActiveScan(true);
    g_want_scan = true;
}

void poll() {
    if (g_want_scan && !NimBLEDevice::getScan()->isScanning() &&
        g_query_char == nullptr) {
        g_want_scan = false;
        // 0 = scan forever until stopped (a hit in ScanCallbacks::onResult
        // stops it) -- there is no deadline an operator waiting for their
        // own phone app to come up front should be held to. No completion
        // callback: nothing here runs once scanning merely times out,
        // since it never does.
        NimBLEDevice::getScan()->start(0, nullptr);
    }
}

bool connected() {
    return g_client != nullptr && g_client->isConnected() &&
           g_query_char != nullptr && g_response_char != nullptr;
}

bool query(const uint8_t* req, size_t req_len, uint8_t* resp, size_t resp_cap,
           size_t* resp_len, uint32_t timeout_ms) {
    if (!connected()) return false;

    xSemaphoreTake(g_mutex, portMAX_DELAY);
    g_response_ready = false;
    xSemaphoreGive(g_mutex);

    // No response requested on the write itself: the actual answer comes
    // back later, over its own notify -- see RESPONSE_CHAR_UUID's own
    // comment for why they are two characteristics rather than one.
    if (!g_query_char->writeValue(req, req_len, /*response=*/false)) {
        return false;
    }

    const uint32_t deadline = millis() + timeout_ms;
    while (millis() < deadline) {
        xSemaphoreTake(g_mutex, portMAX_DELAY);
        const bool ready = g_response_ready;
        if (ready) {
            const size_t n =
                    g_response_len < resp_cap ? g_response_len : resp_cap;
            memcpy(resp, g_response_buf, n);
            *resp_len = n;
        }
        xSemaphoreGive(g_mutex);
        if (ready) return true;
        vTaskDelay(pdMS_TO_TICKS(20));
        if (!connected()) return false;  // dropped mid-wait
    }
    return false;
}

}  // namespace BleLink
