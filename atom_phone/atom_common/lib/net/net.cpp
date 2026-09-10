#include "net.h"

#include <DNSServer.h>
#include <ESPmDNS.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <WebServer.h>
#include <string.h>

#include <mode.h>
#include <policy.h>

#include "web_page.h"

namespace net {
namespace {

/// The port the control protocol listens on. Arbitrary, but fixed: the PC
/// finds the device by mDNS or by the QR code, not by scanning ports.
constexpr uint16_t PORT = 9000;

/// Advertised over mDNS as `<ROBOT_NAME>.local`, so a PC needs no address --
/// and, with several robots on one network, no address that would collide
/// with another one's either.
constexpr char HOSTNAME[] = ROBOT_NAME;
constexpr char SERVICE[] = "kxratom";

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

/// Set once by setServoIds(), from PolicyMode::enter() (core 1) right after
/// buildServoOrder(), and only ever read afterwards, by handleInfoRequest()
/// on the server task (core 0). No critical section around either side:
/// this is a one-time publish before the HTTP server sees any real traffic,
/// the same informal cross-core pattern g_status/g_url already rely on
/// elsewhere in this file, not a value that is ever read mid-write.
uint8_t g_servo_ids[POLICY_ACT_DIM];
uint8_t g_servo_id_count = 0;

/// The robot's own access point while nobody has told it which network to
/// join here. Open (no password): this is a physical machine in a room, not
/// a service on the internet, and a typo'd portal password is a worse
/// failure mode than a stranger briefly seeing a form that only accepts a
/// Wi-Fi SSID and password and immediately tears the AP down again.
///
/// Built from ROBOT_NAME rather than a literal, like everything else this
/// firmware shares across robots (see kWebPage's own comment) -- so with
/// several of these on at once, the phone's own Wi-Fi picker is what tells
/// them apart.
String provisionSsid() { return String(ROBOT_NAME) + "-wifi"; }
DNSServer dnsServer;
bool g_provisioning = false;
/// Whether STANDALONE_AP is what NVS asks for at boot -- see
/// useOwnAccessPoint(). Separate from g_provisioning: that one is a transient
/// setup screen, this is the thing it can leave the robot in permanently.
bool g_ap_mode = false;

// The form is submitted on the HTTP server's task, pinned to core 0 (see
// SERVER_CORE); configure() and the WiFi.* calls it makes were, until this
// existed, only ever reached from the Arduino loop on core 1 (BRIDGE/STATUS
// reading the USB text protocol). Rather than give configure() a second
// caller on a second core, the form just leaves what it asked for here,
// guarded the same way the command slot below is, and poll() -- already on
// core 1 -- is what actually calls configure().
bool g_save_pending = false;
/// Same reasoning, for the form's other button (see kProvisionPage's second
/// form): "there is no Wi-Fi here at all, use the robot's own network".
bool g_ap_pending = false;
/// Same reasoning again, for kWebPage's "Wi-Fi setup" link: a phone sitting
/// on this robot's own AP (STANDALONE_AP, or mid-operation with no other way
/// in) has no menu to reach beginProvisioning() from except this button --
/// the physical double-click (see status_mode.cpp's onDoubleClick) needs a
/// hand at the robot, which is exactly what a field log server across the
/// room does not have.
bool g_provision_pending = false;
/// Same reasoning a third time, for kProvisionPage's SSID picker: the actual
/// WiFi.scanNetworks() call (and the WiFi.mode(WIFI_AP_STA) it may need
/// first) is a radio call exactly like configure()'s, so it stays on core 1
/// too. Unlike the other three flags this one has a result the HTTP request
/// is waiting on, so handleScanRequest() spins on g_scan_ready instead of
/// answering immediately -- see its own comment for why that beats a second
/// poll-for-results endpoint.
bool g_scan_pending = false;
bool g_scan_ready = true;
/// Fixed buffer, not String, for the same reason g_save_ssid is: written
/// from poll() (core 1) inside a portMUX critical section and read from the
/// server task (core 0) inside the same one. Sized for a few dozen networks
/// -- comfortably more than one site ever has -- so a JSON array of them
/// never needs to grow.
constexpr size_t SCAN_BUF_SIZE = 2560;
char g_scan_buf[SCAN_BUF_SIZE] = "{\"networks\":[]}";
constexpr uint8_t SCAN_MAX_NETWORKS = 24;
/// How many networks' passwords this robot remembers (see rememberNetwork()
/// and knownPasswordFor()), most-recently-used first. Small on purpose: this
/// is "the handful of places this robot gets carried to", not a general
/// credential store.
constexpr uint8_t KNOWN_NET_MAX = 8;

// Fixed buffers rather than String: they are filled inside a portMUX
// critical section (a spinlock, not a mutex), where an allocation is not
// something to invite. 63 bytes matches the setup text protocol's own
// buffer (handleSetupLine) and WPA2's own 63-character maximum.
char g_save_ssid[64];
char g_save_pass[64];

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

/// The radio half of running this robot's own network, shared by the
/// transient setup screen (beginProvisioning()) and the permanent
/// STANDALONE_AP mode (useOwnAccessPoint()) -- they differ only in whether
/// NVS remembers to come back up this way after a reboot.
void startAccessPoint() {
    // Whatever the radio was doing, it can only be in one place: this robot
    // cannot be joining a lab network and broadcasting its own at the same
    // time on one antenna without a real AP+STA setup this does not need.
    WiFi.disconnect(true);
    WiFi.mode(WIFI_AP);
    WiFi.softAP(provisionSsid().c_str());
    dnsServer.start(53, "*", WiFi.softAPIP());
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

/// Static (per robot, not per control step) info the page fetches once on
/// load rather than carrying baked into its own HTML -- see kWebPage's own
/// comment: this is what makes that one page work, unmodified, on all of
/// this firmware's robots instead of each needing its own copy.
void handleInfoRequest() {
    char range[96];
    // Actor 0: this firmware's own convention (see policy.cpp's kActors[])
    // is that it is always the walking actor, whichever build -- see
    // commandVxMinOf()'s own comment for why this is not commandVxMin().
    snprintf(range, sizeof(range), "\"vxMin\":%.4f,\"vxMax\":%.4f,\"wzMax\":%.4f,",
            policy::commandVxMinOf(0), policy::commandVxMaxOf(0),
            policy::commandWzMaxOf(0));
    String body = "{\"robot\":\"" ROBOT_NAME "\",";
    body += range;
    body += "\"actors\":[";
    for (size_t i = 0; i < policy::count(); i++) {
        if (i > 0) body += ',';
        body += '"';
        body += policy::name(i);
        body += '"';
    }
    body += "],\"motions\":[";
    const size_t n = policy::motionCount();
    for (size_t i = 0; i < n; i++) {
        const policy::Motion& m = policy::motion(i);
        if (i > 0) body += ',';
        body += '[';
        body += static_cast<int>(m.number);
        body += ",\"";
        // Names come from a real Heart to Heart project (see
        // tools/motions_from_h4p.py), not from anyone typing into this
        // request, but a bare '"' or '\' in one would still break the JSON
        // it sits in -- escaped rather than assumed absent.
        for (const char* p = m.name; *p; p++) {
            if (*p == '"' || *p == '\\') body += '\\';
            body += *p;
        }
        body += "\"]";
    }
    body += "],\"servoIds\":[";
    // Static per robot (see setServoIds()) -- the fixed order every
    // Telemetry's servo_pulse/joint_target_rad line up with, so kWebPage's
    // FieldLog can label each column without also needing this every tick.
    for (uint8_t i = 0; i < g_servo_id_count; i++) {
        if (i > 0) body += ',';
        body += static_cast<int>(g_servo_ids[i]);
    }
    body += "]}";
    server.send(200, "application/json", body);
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

    // Sized for the fixed fields plus two POLICY_ACT_DIM-long arrays (pulse,
    // target) -- built with snprintf-and-advance rather than one format
    // string, since neither array's length is known at compile time.
    char body[420 + POLICY_ACT_DIM * 24];
    size_t len = snprintf(body, sizeof(body),
             "{\"state\":%u,\"vx\":%.3f,\"wz\":%.3f,\"loop_ms\":%.1f,"
             "\"err\":%lu,\"over\":%lu,\"draw_ms\":%.1f,"
             "\"req\":%u,\"actor\":%u,\"seq\":%u,"
             "\"quiet\":%lu,\"rx\":%lu,\"step\":%lu,"
             "\"try\":%u,\"home_err\":%d,"
             "\"gravity\":[%.3f,%.3f,%.3f],"
             "\"live\":%s,\"ok\":%s,",
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
             snapshot.t.gravity[0], snapshot.t.gravity[1], snapshot.t.gravity[2],
             live ? "true" : "false", accepted ? "true" : "false");
    // Per real servo (see Telemetry::servo_count's own comment): the raw
    // pulse last read back, and the joint target (radians) that produced
    // it, same order as /info's own "servoIds". Only fresh while
    // RUNNING/HOLDING -- see sendTelemetry()'s own comment -- but sent
    // every tick regardless, the same as gravity already is.
    len += snprintf(body + len, sizeof(body) - len, "\"pulse\":[");
    for (uint8_t i = 0; i < snapshot.t.servo_count && len + 32 < sizeof(body); i++) {
        len += snprintf(body + len, sizeof(body) - len, "%s%u", i > 0 ? "," : "",
                        static_cast<unsigned>(snapshot.t.servo_pulse[i]));
    }
    len += snprintf(body + len, sizeof(body) - len, "],\"target\":[");
    for (uint8_t i = 0; i < snapshot.t.servo_count && len + 32 < sizeof(body); i++) {
        len += snprintf(body + len, sizeof(body) - len, "%s%.4f", i > 0 ? "," : "",
                        snapshot.t.joint_target_rad[i]);
    }
    snprintf(body + len, sizeof(body) - len, "]}");
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

/// Remembers a network's password so a later provisioning session does not
/// have to ask for one it was already given once -- see handleSaveRequest's
/// blank-password path and kProvisionPage's own script. Most-recently-used
/// first, capped at KNOWN_NET_MAX; NVS, so it survives a reboot the same way
/// the active connection's own credentials do (see begin()'s ap_mode path).
/// Called only from poll() (core 1) -- see g_save_pending's own comment on
/// why NVS/WiFi calls stay off the server task.
void rememberNetwork(const String& ssid, const String& password) {
    if (ssid.length() == 0 || password.length() == 0) return;
    prefs.begin("kxrnet", false);
    const uint8_t count = prefs.getUChar("knCount", 0);
    String ssids[KNOWN_NET_MAX];
    String passwords[KNOWN_NET_MAX];
    uint8_t out = 0;
    // The just-used network goes to the front; whatever was already
    // remembered follows, skipping this ssid (it is moving, not doubling)
    // and dropping the oldest once the cap is hit.
    ssids[out] = ssid;
    passwords[out] = password;
    out++;
    for (uint8_t i = 0; i < count && out < KNOWN_NET_MAX; i++) {
        const String s = prefs.getString(("kn" + String(i) + "s").c_str(), "");
        if (s.length() == 0 || s == ssid) continue;
        ssids[out] = s;
        passwords[out] = prefs.getString(("kn" + String(i) + "p").c_str(), "");
        out++;
    }
    for (uint8_t i = 0; i < out; i++) {
        prefs.putString(("kn" + String(i) + "s").c_str(), ssids[i]);
        prefs.putString(("kn" + String(i) + "p").c_str(), passwords[i]);
    }
    prefs.putUChar("knCount", out);
    prefs.end();
}

/// Empty if this ssid was never given to rememberNetwork(). Called only from
/// poll() (core 1), same reasoning as rememberNetwork().
String knownPasswordFor(const String& ssid) {
    prefs.begin("kxrnet", /*readOnly=*/true);
    const uint8_t count = prefs.getUChar("knCount", 0);
    String found;
    for (uint8_t i = 0; i < count; i++) {
        if (prefs.getString(("kn" + String(i) + "s").c_str(), "") == ssid) {
            found = prefs.getString(("kn" + String(i) + "p").c_str(), "");
            break;
        }
    }
    prefs.end();
    return found;
}

/// The actual scan behind handleScanRequest(), run from poll() (core 1) --
/// see g_scan_pending's own comment for why WiFi.scanNetworks() does not run
/// on the server task that asked for it.
void runWifiScan() {
    // A bare WIFI_AP (provisioning's and STANDALONE_AP's mode) cannot see
    // other networks; AP_STA adds scanning without taking the setup AP down
    // out from under whoever is mid-form because of it.
    if (WiFi.getMode() == WIFI_AP) WiFi.mode(WIFI_AP_STA);
    const int n = WiFi.scanNetworks();

    // De-duplicated by SSID -- scanNetworks() reports one entry per radio
    // (BSSID), and most sites have more than one answering to the same name
    // -- keeping whichever copy is loudest, then sorted loudest first: the
    // one worth trying is the one at the top of the list.
    //
    // `open` travels with it because the page needs it too: a blank password
    // means "use what this robot already has saved" (see knownPasswordFor())
    // for a KNOWN network, but for one that is neither known nor open, a
    // blank password is simply wrong, and submitting it anyway just spends a
    // CONNECT_TIMEOUT_MS/RETRY_INTERVAL_MS cycle failing against a network
    // that was never going to let it in. Nothing here enforces that (a typed
    // SSID has no scan entry to ask), but kProvisionPage's script requires a
    // password for exactly this case.
    struct Seen { String ssid; int32_t rssi; bool open; };
    Seen seen[SCAN_MAX_NETWORKS];
    int seen_count = 0;
    for (int i = 0; i < n && i < 64; i++) {
        const String ssid = WiFi.SSID(i);
        if (ssid.length() == 0) continue;  // hidden network: nothing to pick
        const int32_t rssi = WiFi.RSSI(i);
        const bool open = WiFi.encryptionType(i) == WIFI_AUTH_OPEN;
        int j = 0;
        for (; j < seen_count; j++) {
            if (seen[j].ssid == ssid) {
                if (rssi > seen[j].rssi) seen[j].rssi = rssi;
                break;
            }
        }
        if (j == seen_count && seen_count < SCAN_MAX_NETWORKS) {
            seen[seen_count].ssid = ssid;
            seen[seen_count].rssi = rssi;
            seen[seen_count].open = open;
            seen_count++;
        }
    }
    for (int i = 1; i < seen_count; i++) {
        Seen key = seen[i];
        int j = i - 1;
        while (j >= 0 && seen[j].rssi < key.rssi) { seen[j + 1] = seen[j]; j--; }
        seen[j + 1] = key;
    }

    char buf[SCAN_BUF_SIZE];
    size_t len = snprintf(buf, sizeof(buf), "{\"networks\":[");
    for (int i = 0; i < seen_count && len + 96 < sizeof(buf); i++) {
        if (i > 0) buf[len++] = ',';
        len += snprintf(buf + len, sizeof(buf) - len, "{\"ssid\":\"");
        for (size_t k = 0; k < seen[i].ssid.length() && len + 2 < sizeof(buf); k++) {
            const char c = seen[i].ssid[k];
            if (c == '"' || c == '\\') buf[len++] = '\\';
            buf[len++] = c;
        }
        len += snprintf(buf + len, sizeof(buf) - len,
                        "\",\"rssi\":%ld,\"known\":%s,\"open\":%s}",
                        static_cast<long>(seen[i].rssi),
                        knownPasswordFor(seen[i].ssid).length() > 0 ? "true" : "false",
                        seen[i].open ? "true" : "false");
    }
    len += snprintf(buf + len, sizeof(buf) - len, "]}");
    WiFi.scanDelete();

    portENTER_CRITICAL(&g_shared);
    memcpy(g_scan_buf, buf, len + 1);
    g_scan_ready = true;
    portEXIT_CRITICAL(&g_shared);
}

/// kProvisionPage's SSID picker asks for this instead of a name to remember
/// and retype. Spins in place waiting for poll() (core 1) to actually run
/// the scan (see g_scan_pending) rather than answering "started" and making
/// the page poll a second endpoint for the result -- not worth the
/// complexity for something that finishes in a few seconds either way.
void handleScanRequest() {
    portENTER_CRITICAL(&g_shared);
    g_scan_ready = false;
    g_scan_pending = true;
    portEXIT_CRITICAL(&g_shared);
    const uint32_t start = millis();
    while (millis() - start < 8000) {
        portENTER_CRITICAL(&g_shared);
        const bool ready = g_scan_ready;
        portEXIT_CRITICAL(&g_shared);
        if (ready) break;
        vTaskDelay(pdMS_TO_TICKS(50));
    }
    // Heap, not a stack array: SCAN_BUF_SIZE (2560 bytes) is a third of
    // SERVER_STACK on its own, and server.send() below -- which this task
    // also needs its stack for -- must run outside the critical section
    // (it can block for milliseconds; a spinlock must not be held that
    // long), so the copy cannot just be sent from within one either way.
    char* local = new char[SCAN_BUF_SIZE];
    portENTER_CRITICAL(&g_shared);
    memcpy(local, g_scan_buf, SCAN_BUF_SIZE);
    portEXIT_CRITICAL(&g_shared);
    server.send(200, "application/json", local);
    delete[] local;
}

/// The provisioning form's one POST, handled the same way handleCommandRequest
/// is: read it, act, answer. Reached both from the robot's own setup AP (see
/// beginProvisioning() and provisionSsid()) and, harmlessly, from a normal
/// STA session -- this is how a robot already on one network gets moved to
/// another without a cable.
void handleSaveRequest() {
    const String ssid_in = server.hasArg("ssid") ? server.arg("ssid") : String();
    if (ssid_in.length() == 0) {
        server.send(400, "text/plain", "ssid required");
        return;
    }
    // Blank means the operator picked a network from the list and typed no
    // password -- either it is open, or (far more often) this robot already
    // has one remembered for it (see knownPasswordFor(), applied in poll()
    // once this is handed off: looking it up here would mean touching NVS
    // from the server task, which is exactly what g_save_pending exists to
    // avoid).
    const String pass_in = server.hasArg("pass") ? server.arg("pass") : String();
    // Handed to poll(), on the other core, rather than calling configure()
    // (and so WiFi.mode()) from here: this task is pinned next to the radio
    // for latency, not because it is safe to drive the radio's mode from two
    // cores at once. See g_save_pending.
    portENTER_CRITICAL(&g_shared);
    strncpy(g_save_ssid, ssid_in.c_str(), sizeof(g_save_ssid) - 1);
    g_save_ssid[sizeof(g_save_ssid) - 1] = '\0';
    strncpy(g_save_pass, pass_in.c_str(), sizeof(g_save_pass) - 1);
    g_save_pass[sizeof(g_save_pass) - 1] = '\0';
    g_save_pending = true;
    portEXIT_CRITICAL(&g_shared);
    server.send(200, "text/html",
               "<html><body style='font:16px -apple-system,system-ui,"
               "sans-serif;background:#111;color:#eee;padding:20px'>"
               "saved. This robot is about to leave its own Wi-Fi network for "
               "the one just given, so this page is about to stop answering. "
               "Rejoin that same network on this phone, then open the address "
               "shown on the robot's own screen (its POLICY screen shows it "
               "directly; long-press the button twice for STATUS, then click "
               "once for a QR code to scan instead).</body></html>");
}

/// The provisioning form's other button: no Wi-Fi here at all, so stop
/// trying to join anyone else's network and let the robot's own AP be the
/// network from now on. No fields to read -- just a request to act on, on
/// poll()'s core, the same way handleSaveRequest hands its off.
void handleUseOwnApRequest() {
    portENTER_CRITICAL(&g_shared);
    g_ap_pending = true;
    portEXIT_CRITICAL(&g_shared);
    server.send(200, "text/html",
               "<html><body style='font:16px -apple-system,system-ui,"
               "sans-serif;background:#111;color:#eee;padding:20px'>"
               "OK. Stay joined to this access point -- that is the robot's "
               "network now. Reload this page in a few seconds to reach the "
               "controls.</body></html>");
}

/// kWebPage's "Wi-Fi setup" link, reached without leaving the phone's own
/// screen: this device is very likely already sitting on the same AP that
/// beginProvisioning() would (re)start (STANDALONE_AP shares its SSID -- see
/// startAccessPoint()), so restarting it just to flip which page "/" answers
/// with is enough; the phone rejoins the same network automatically and a
/// reload lands on kProvisionPage. On a normal STA connection this still
/// starts the setup AP -- the phone then has to switch to it by hand, same as
/// scanning the LCD's own QR code ever did, but the button is at least where
/// the operator already is instead of back at the robot.
void handleProvisionRequest() {
    portENTER_CRITICAL(&g_shared);
    g_provision_pending = true;
    portEXIT_CRITICAL(&g_shared);
    server.send(200, "text/html",
               "<html><body style='font:16px -apple-system,system-ui,"
               "sans-serif;background:#111;color:#eee;padding:20px'>"
               "starting Wi-Fi setup. If this phone drops its connection, "
               "rejoin \"" + provisionSsid() + "\" and reload.</body></html>");
}

/// Routes are the same whichever mode is up; only what "/" answers changes
/// (see g_provisioning). Registered once, the first time either mode needs
/// the server, so provisioning before ever joining a network and a normal
/// STA connection share one WebServer instance.
void ensureServer() {
    if (g_http_open) return;
    server.on("/", []() {
        server.send_P(200, "text/html",
                      g_provisioning ? kProvisionPage : kWebPage);
    });
    server.on("/c", handleCommandRequest);
    server.on("/info", handleInfoRequest);
    server.on("/save", HTTP_POST, handleSaveRequest);
    server.on("/ap", HTTP_POST, handleUseOwnApRequest);
    server.on("/provision", HTTP_POST, handleProvisionRequest);
    server.on("/scan", handleScanRequest);
    // A phone probes some fixed URL of its own choosing to decide whether a
    // network needs signing into (Android: connectivitycheck.gstatic.com,
    // iOS: captive.apple.com, ...). Answering all of them with a redirect to
    // "/" is what makes the OS pop the sign-in page on its own instead of the
    // operator having to know to open a browser at all.
    server.onNotFound([]() {
        if (g_provisioning) {
            server.sendHeader("Location", "/", true);
            server.send(302, "text/plain", "");
        } else {
            server.send(404, "text/plain", "no");
        }
    });
    server.begin();
    g_http_open = true;
    startServerTask();
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
    ensureServer();
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
    const bool ap_mode = prefs.getBool("apmode", false);
    prefs.end();
    g_stored = g_ssid.length() > 0;
    if (ap_mode) {
        // Skip straight to the robot's own network -- no attempt at anyone
        // else's, and so no CONNECTING/FAILED flicker on a boot that was
        // never going to reach an AP that is not there.
        g_ap_mode = true;
        startAccessPoint();
        g_status = Status::STANDALONE_AP;
        g_url = "http://" + WiFi.softAPIP().toString();
        ensureServer();
        return;
    }
    if (!g_stored) {
        g_status = Status::UNCONFIGURED;
        return;
    }
    startConnecting();
}

void poll() {
    bool save_pending, ap_pending;
    char ssid_in[sizeof(g_save_ssid)];
    char pass_in[sizeof(g_save_pass)];
    portENTER_CRITICAL(&g_shared);
    save_pending = g_save_pending;
    if (save_pending) {
        memcpy(ssid_in, g_save_ssid, sizeof(ssid_in));
        memcpy(pass_in, g_save_pass, sizeof(pass_in));
        g_save_pending = false;
    }
    ap_pending = g_ap_pending;
    g_ap_pending = false;
    bool provision_pending = g_provision_pending;
    g_provision_pending = false;
    bool scan_pending = g_scan_pending;
    g_scan_pending = false;
    portEXIT_CRITICAL(&g_shared);
    if (save_pending) {
        // An empty password means the operator picked a network the form's
        // list already marked "known" and left the field blank rather than
        // retyping it -- see knownPasswordFor() and handleSaveRequest()'s own
        // comment. A non-empty one is remembered here, on the only core that
        // touches this NVS namespace, for the next time.
        String pass(pass_in);
        if (pass.length() == 0) {
            pass = knownPasswordFor(String(ssid_in));
        } else {
            rememberNetwork(String(ssid_in), pass);
        }
        // configure() calls WiFi.mode(WIFI_STA), which tears the AP down on
        // its own; stopProvisioning() only needs to stop the DNS server and
        // clear the flag, not touch the radio mode itself (see its own
        // WIFI_AP check).
        configure(ssid_in, pass.c_str());
        stopProvisioning();
        return;
    }
    if (ap_pending) {
        // Same reasoning as save_pending: useOwnAccessPoint() touches the
        // radio, so it runs here on core 1 rather than on the server task
        // that took the request.
        useOwnAccessPoint();
        return;
    }
    if (provision_pending) {
        // Same reasoning again: beginProvisioning() touches the radio too.
        beginProvisioning();
        return;
    }
    if (scan_pending) {
        // Same reasoning again: WiFi.scanNetworks() touches the radio too.
        runWifiScan();
        return;
    }
    if (g_provisioning || g_status == Status::STANDALONE_AP) {
        // Answers every DNS query with this device's own address, which is
        // the half of the captive-portal trick that is not the HTTP redirect
        // in ensureServer()'s onNotFound. Harmless to keep running in
        // STANDALONE_AP too -- there is no other network for a query to mean
        // anything on.
        dnsServer.processNextRequest();
        return;
    }
    switch (g_status) {
        case Status::UNCONFIGURED:
            return;
        case Status::PROVISIONING:
        case Status::STANDALONE_AP:
            return;  // handled above; listed so the switch stays exhaustive
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
IPAddress ip() {
    return g_status == Status::STANDALONE_AP ? WiFi.softAPIP() : WiFi.localIP();
}
const char* ssid() { return g_ssid.c_str(); }
const char* url() { return g_url.c_str(); }

void configure(const char* ssid_in, const char* password_in) {
    prefs.begin("kxrnet", /*readOnly=*/false);
    prefs.putString("ssid", ssid_in);
    prefs.putString("pass", password_in);
    // A real network was just named, so STANDALONE_AP -- if that is what
    // brought this device up -- is not what should happen at the next
    // reboot any more.
    prefs.putBool("apmode", false);
    prefs.end();
    g_ap_mode = false;
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
    prefs.remove("apmode");
    prefs.end();
    g_ap_mode = false;
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

void beginProvisioning() {
    if (g_provisioning) return;
    // STANDALONE_AP is already broadcasting this exact SSID (see
    // startAccessPoint(), shared by both) -- restarting it here would just
    // be asking every phone already joined to it, including whichever one
    // asked for this via kWebPage's "Wi-Fi setup" button, to rejoin a
    // network it never actually left. That rejoin is not guaranteed fast
    // (or even automatic) on every phone, which used to make the button
    // flaky for exactly the one case it exists for. Skipping the restart
    // when the AP is already up means the very next request -- the one
    // this handler is finishing -- lands on the form with nothing at the
    // radio having moved at all.
    if (g_status != Status::STANDALONE_AP) {
        startAccessPoint();
    }
    g_provisioning = true;
    g_status = Status::PROVISIONING;
    g_url = "";
    ensureServer();
}

void useOwnAccessPoint() {
    prefs.begin("kxrnet", /*readOnly=*/false);
    prefs.putBool("apmode", true);
    prefs.end();
    g_ap_mode = true;
    g_provisioning = false;  // "/" must serve the control page, not the form
    startAccessPoint();
    g_status = Status::STANDALONE_AP;
    g_url = "http://" + WiFi.softAPIP().toString();
    ensureServer();
}

void stopProvisioning() {
    if (!g_provisioning && g_status != Status::STANDALONE_AP) return;
    if (g_ap_mode) {
        // Forget it survives a reboot; begin() checks this before ever
        // trying to join anyone else's network.
        prefs.begin("kxrnet", /*readOnly=*/false);
        prefs.putBool("apmode", false);
        prefs.end();
        g_ap_mode = false;
    }
    dnsServer.stop();
    g_provisioning = false;
    // Left in WIFI_AP with nothing listening is not "not provisioning" from
    // the phone's side -- the AP would still be there. configure()/connect()
    // already call WiFi.mode(WIFI_STA), which tears it down; if neither ran
    // (provisioning, or STANDALONE_AP, was simply cancelled), do it here
    // instead.
    if (WiFi.getMode() == WIFI_AP) {
        WiFi.mode(WIFI_STA);
        g_status = g_stored ? Status::FAILED : Status::UNCONFIGURED;
        g_retry_at_ms = millis();
    }
}

bool provisioning() { return g_provisioning; }

void setTelemetry(uint8_t state, float vx, float wz, uint32_t loop_us,
                  uint32_t errors, uint32_t overruns, uint32_t draw_us,
                  const Debug& debug, const float* gravity,
                  const uint16_t* servo_pulse, const float* joint_target_rad,
                  uint8_t servo_count) {
    portENTER_CRITICAL(&g_shared);
    g_telemetry.t.state = state;
    g_telemetry.t.vx = vx;
    g_telemetry.t.wz = wz;
    g_telemetry.t.loop_us = loop_us;
    g_telemetry.t.errors = errors;
    g_telemetry.t.overruns = overruns;
    g_telemetry.t.draw_us = draw_us;
    g_telemetry.debug = debug;
    memcpy(g_telemetry.t.gravity, gravity, sizeof(g_telemetry.t.gravity));
    g_telemetry.t.servo_count = servo_count;
    memcpy(g_telemetry.t.servo_pulse, servo_pulse,
          servo_count * sizeof(*servo_pulse));
    memcpy(g_telemetry.t.joint_target_rad, joint_target_rad,
          servo_count * sizeof(*joint_target_rad));
    g_telemetry.t.updated_ms = millis();
    portEXIT_CRITICAL(&g_shared);
}

void setServoIds(const uint8_t* ids, uint8_t count) {
    g_servo_id_count = count;
    memcpy(g_servo_ids, ids, count * sizeof(*ids));
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

Debug debugInfo() {
    Debug out;
    portENTER_CRITICAL(&g_shared);
    out = g_telemetry.debug;
    portEXIT_CRITICAL(&g_shared);
    return out;
}

const char* statusLabel(Status status) {
    switch (status) {
        case Status::UNCONFIGURED: return "no wifi set";
        case Status::CONNECTING: return "connecting";
        case Status::CONNECTED: return "connected";
        case Status::FAILED: return "wifi failed";
        case Status::PROVISIONING: return "setup AP up";
        case Status::STANDALONE_AP: return "own hotspot";
    }
    return "?";
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
