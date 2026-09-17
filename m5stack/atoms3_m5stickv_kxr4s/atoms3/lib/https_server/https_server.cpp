#include "https_server.h"

#include <PsychicHttp.h>
#include <PsychicHttpsServer.h>
#include <WiFi.h>

#include <cert_store.h>
#include <policy.h>
#include <rcb4_link.h>  // net.h's own COMMAND_JSON_MAX needs Rcb4Link::
                        // M5STICKV_MAX_READ -- included directly (not just
                        // transitively via net.h) so PlatformIO's LDF
                        // actually adds this library's include path; chain
                        // mode did not follow that one deep enough on its
                        // own (confirmed: this file failed to build
                        // without it, even though net.h #includes it).
#include <net.h>

#include "web_page.h"

namespace https_server {
namespace {

/// How long a fresh certificate is trusted before checking again --
/// local-ip.sh renews about a month before its own expiry, so once a day
/// keeps an always-on device valid. A failed attempt (network hiccup, or
/// this robot briefly off any real network) retries much sooner rather
/// than waiting a whole day to find out the next one also failed.
constexpr uint32_t kRefreshIntervalMs = 24UL * 60 * 60 * 1000;
constexpr uint32_t kRetryIntervalMs = 10UL * 60 * 1000;

enum class State : uint8_t {
    IDLE,           // waiting for a real (non-standalone-AP) network
    SYNCING_TIME,   // NTP, needed before any certificate's expiry means
                    // anything
    FETCHING_CERT,  // cache, then a real download if the cache misses
    SERVING,        // certificate valid and installed; refreshed daily
};

State g_state = State::IDLE;
uint32_t g_next_attempt_ms = 0;
cert_store::Credentials g_creds;
String g_url;  // valid only once g_state == SERVING

PsychicHttpsServer g_https;
// A second, unrelated PsychicHttpServer purely to redirect port 80 to
// port 443 -- see setup()'s own reasoning below for why this exists
// alongside net.cpp's plain WebServer, which ALSO already owns port 80.
// It cannot: only one listener per port. Since this whole feature is
// worthless without a real certificate, and net.cpp's own WebServer
// already covers port 80 perfectly well until then (including serving
// kWebPage over plain HTTP, exactly as it always has), the redirect is
// wired into net.cpp's OWN "/" handler instead (see net.cpp's own
// ensureServer()) rather than a second port-80 listener fighting it for
// the socket.

/// "192.168.1.50" -> "192-168-1-50" -- local-ip.sh's own hostname
/// convention.
String dashedIp(const IPAddress& ip) {
    String s = ip.toString();
    s.replace('.', '-');
    return s;
}

void installCertificate(const cert_store::Credentials& creds) {
    g_https.setCertificate(creds.cert_pem.c_str(), creds.key_pem.c_str());
    g_url = "https://" + dashedIp(net::ip()) + ".local-ip.sh/";
}

// ---------------------------------------------------------------------
// Routes. Deliberately the same small set net.cpp's own kWebPage/kM5vPage
// actually call from their JS -- see https_server.h's own top comment for
// why this is not a wholesale port of every WebServer route (Wi-Fi
// provisioning, /save, /ap, /provision, /scan -- stays plain-HTTP only,
// on net.cpp's own server, since none of it needs a secure origin).
// ---------------------------------------------------------------------

esp_err_t handleRoot(PsychicRequest* request, PsychicResponse* response) {
    response->setContentType("text/html");
    return response->send(kWebPage);
}

esp_err_t handleM5v(PsychicRequest* request, PsychicResponse* response) {
    response->setContentType("text/html");
    return response->send(kM5vPage);
}

esp_err_t handleCommand(PsychicRequest* request, PsychicResponse* response) {
    char body[net::COMMAND_JSON_MAX];
    if (request->hasParam("f")) {
        const String hex = request->getParam("f")->value();
        net::buildCommandJson(hex.c_str(), body, sizeof(body));
    } else {
        net::buildCommandJson(nullptr, body, sizeof(body));
    }
    response->setContentType("application/json");
    return response->send(body);
}

esp_err_t handleInfo(PsychicRequest* request, PsychicResponse* response) {
    response->setContentType("application/json");
    return response->send(net::buildInfoJson().c_str());
}

esp_err_t handleActor(PsychicRequest* request, PsychicResponse* response) {
    if (!request->hasParam("index")) {
        return response->send(400, "text/plain", "index required");
    }
    const long index = request->getParam("index")->value().toInt();
    if (index < 0 || index > 255) {
        return response->send(400, "text/plain", "index must be 0-255");
    }
    net::requestActorSelect(static_cast<uint8_t>(index));
    return response->send("ok");
}

esp_err_t handleM5vSet(PsychicRequest* request, PsychicResponse* response) {
    if (!request->hasParam("reg") || !request->hasParam("value")) {
        return response->send(400, "text/plain", "reg and value required");
    }
    const long reg = request->getParam("reg")->value().toInt();
    const long value = request->getParam("value")->value().toInt();
    if (reg < 0 || reg > 255 || value < 0 || value > 255) {
        return response->send(400, "text/plain", "reg and value must be 0-255");
    }
    net::requestM5StickVWrite(static_cast<uint8_t>(reg), static_cast<uint8_t>(value));
    return response->send("ok");
}

/// Same three-callback shape as net.cpp's own handlePolicyUploadChunk() /
/// handlePolicyUploadComplete() (see that pair's own comment on the
/// stream-rather-than-buffer reasoning) -- PsychicHttp's own onUpload()
/// gives (index, data, len, last) instead of WebServer's UPLOAD_FILE_*
/// enum, but the mapping is direct: index==0 is START, last is END.
bool g_policy_upload_ok = false;

}  // namespace

void begin() {
    PsychicUploadHandler* upload_handler = new PsychicUploadHandler();
    upload_handler->onUpload([](PsychicRequest*, const String&, uint64_t index,
                                uint8_t* data, size_t len, bool last) -> esp_err_t {
        if (index == 0) g_policy_upload_ok = policy::beginUpload();
        if (g_policy_upload_ok) {
            g_policy_upload_ok = policy::appendUpload(data, len);
        }
        if (last && g_policy_upload_ok) g_policy_upload_ok = policy::finishUpload();
        return ESP_OK;
    });
    upload_handler->onRequest([](PsychicRequest*, PsychicResponse* response) {
        return response->send(g_policy_upload_ok ? 200 : 400, "text/plain",
                              g_policy_upload_ok
                                      ? "ok"
                                      : "upload failed: wrong size, out of RAM, "
                                        "or actor busy running");
    });

    g_https.on("/", HTTP_GET, handleRoot);
    g_https.on("/c", HTTP_GET, handleCommand);
    g_https.on("/info", HTTP_GET, handleInfo);
    g_https.on("/actor", HTTP_POST, handleActor);
    g_https.on("/policy", HTTP_POST, upload_handler);
    g_https.on("/m5v", HTTP_GET, handleM5v);
    g_https.on("/m5vset", HTTP_POST, handleM5vSet);
}

void poll() {
    const uint32_t now_ms = millis();
    switch (g_state) {
        case State::IDLE:
            // See cert_store.h's own comment: nothing beyond this
            // robot's own standalone AP to reach local-ip.sh or NTP
            // through in that mode.
            if (net::status() == net::Status::CONNECTED) {
                g_state = State::SYNCING_TIME;
            }
            break;

        case State::SYNCING_TIME:
            if (net::status() != net::Status::CONNECTED) {
                g_state = State::IDLE;  // lost the network mid-sync
                break;
            }
            if (cert_store::syncTime()) {
                g_state = State::FETCHING_CERT;
            }
            // else: try again next poll() -- syncTime() itself already
            // blocks up to 15 s per attempt, so this is not a tight loop.
            break;

        case State::FETCHING_CERT: {
            if (net::status() != net::Status::CONNECTED) {
                g_state = State::IDLE;
                break;
            }
            // A retry backoff lives here, in-state, rather than a bounce
            // through IDLE and back: IDLE's own check has no notion of
            // "not yet" -- it would just re-enter this same case on the
            // very next poll(), busy-retrying every call instead of
            // waiting kRetryIntervalMs.
            if (g_next_attempt_ms != 0 &&
                static_cast<int32_t>(now_ms - g_next_attempt_ms) < 0) {
                break;
            }
            const time_t now = time(nullptr);
            String error;
            if (cert_store::loadFromCache(now, g_creds, error) ||
                cert_store::download(now, g_creds, error)) {
                if (!g_creds.from_cache) cert_store::saveToCache(g_creds);
                installCertificate(g_creds);
                g_https.begin();  // port is 443 by default (constructor)
                g_state = State::SERVING;
                g_next_attempt_ms = now_ms + kRefreshIntervalMs;
            } else {
                // error is not surfaced anywhere yet -- see this module's
                // own known gaps. Stays in FETCHING_CERT; the guard above
                // waits out kRetryIntervalMs before trying again.
                g_next_attempt_ms = now_ms + kRetryIntervalMs;
            }
            break;
        }

        case State::SERVING:
            if (static_cast<int32_t>(now_ms - g_next_attempt_ms) >= 0) {
                const time_t now = time(nullptr);
                String error;
                cert_store::Credentials fresh;
                if (cert_store::download(now, fresh, error)) {
                    cert_store::saveToCache(fresh);
                    g_creds = fresh;
                    installCertificate(g_creds);
                    g_next_attempt_ms = now_ms + kRefreshIntervalMs;
                } else {
                    g_next_attempt_ms = now_ms + kRetryIntervalMs;
                }
            }
            break;
    }
}

bool isReady() { return g_state == State::SERVING; }

String url() { return g_url; }

}  // namespace https_server
