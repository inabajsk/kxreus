#include "cert_store.h"

#include <HTTPClient.h>
#include <Preferences.h>
#include <WiFiClientSecure.h>
#include <mbedtls/pk.h>
#include <mbedtls/version.h>
#include <mbedtls/x509_crt.h>

#include "letsencrypt_roots.h"

#if MBEDTLS_VERSION_MAJOR >= 3
#error "cert_store.cpp uses the mbedTLS 2.x API this build's core ships \
(2.28.7, confirmed against ~/.platformio/packages/framework-arduinoespressif32's \
own mbedtls/version.h) -- port mbedtls_pk_parse_key/check_pair before ever \
moving to a core built against mbedTLS 3.x."
#endif

namespace cert_store {
namespace {

constexpr char kCertUrl[] = "https://local-ip.sh/server.pem";
constexpr char kKeyUrl[] = "https://local-ip.sh/server.key";

// Any clock earlier than this has not been set by NTP yet
// (2025-01-01T00:00:00Z) -- see timeIsValid()'s own header comment.
constexpr time_t kMinValidEpoch = 1735689600;

/// This device's own NVS namespace for the cached cert/key -- separate
/// from net.cpp's own Preferences use (Wi-Fi credentials), so a
/// Preferences::clear() aimed at one never touches the other.
constexpr char kNvsNamespace[] = "certstore";
constexpr char kNvsCertKey[] = "cert";
constexpr char kNvsKeyKey[] = "key";

bool httpsGet(const char* url, String& body, String& error) {
    WiFiClientSecure client;
    client.setCACert(kLetsEncryptRootsPem);
    HTTPClient http;
    if (!http.begin(client, url)) {
        error = String("cannot start request: ") + url;
        return false;
    }
    const int code = http.GET();
    if (code != HTTP_CODE_OK) {
        error = String("GET ") + url + " -> " +
                (code < 0 ? HTTPClient::errorToString(code) : String(code));
        http.end();
        return false;
    }
    body = http.getString();
    http.end();
    return true;
}

/// Howard Hinnant's days_from_civil -- avoids depending on timegm(), which
/// this core's newlib does not provide.
time_t toEpochUtc(const mbedtls_x509_time& t) {
    const int y = t.year - (t.mon <= 2 ? 1 : 0);
    const int era = (y >= 0 ? y : y - 399) / 400;
    const unsigned yoe = static_cast<unsigned>(y - era * 400);
    const unsigned doy =
            (153 * (t.mon + (t.mon > 2 ? -3 : 9)) + 2) / 5 + t.day - 1;
    const unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    const int64_t days =
            static_cast<int64_t>(era) * 146097 + static_cast<int64_t>(doe) - 719468;
    return static_cast<time_t>(days * 86400 + t.hour * 3600 + t.min * 60 + t.sec);
}

String mbedtlsError(const char* what, int ret) {
    return String(what) + " -0x" + String(-ret, HEX);
}

/// Checks that both PEMs parse and belong together; returns the leaf
/// expiry. Does NOT check expiry against `now` itself -- see validate().
bool inspect(const String& cert_pem, const String& key_pem, time_t& not_after,
             String& error) {
    mbedtls_x509_crt crt;
    mbedtls_pk_context key;
    mbedtls_x509_crt_init(&crt);
    mbedtls_pk_init(&key);

    bool ok = false;
    int ret = mbedtls_x509_crt_parse(
            &crt, reinterpret_cast<const unsigned char*>(cert_pem.c_str()),
            cert_pem.length() + 1);
    if (ret != 0) {
        error = mbedtlsError("certificate parse failed", ret);
    } else {
        ret = mbedtls_pk_parse_key(
                &key, reinterpret_cast<const unsigned char*>(key_pem.c_str()),
                key_pem.length() + 1, nullptr, 0);
        if (ret != 0) {
            error = mbedtlsError("private key parse failed", ret);
        } else {
            ret = mbedtls_pk_check_pair(&crt.pk, &key);
            if (ret != 0) {
                error = mbedtlsError("key does not match certificate", ret);
            } else {
                not_after = toEpochUtc(crt.valid_to);
                ok = true;
            }
        }
    }

    mbedtls_pk_free(&key);
    mbedtls_x509_crt_free(&crt);
    return ok;
}

bool validate(const String& cert_pem, const String& key_pem, time_t now,
              time_t& not_after, String& error) {
    if (!inspect(cert_pem, key_pem, not_after, error)) return false;
    if (not_after <= now) {
        error = "certificate expired";
        return false;
    }
    return true;
}

}  // namespace

bool timeIsValid(time_t now) { return now >= kMinValidEpoch; }

void beginTimeSync() {
    // Two servers, same as the reference this is modelled on: NICT (a
    // Japanese national time authority, low latency domestically) first,
    // pool.ntp.org as a fallback anywhere else. Only starts the ESP-IDF
    // SNTP client's own background work -- see this function's own header
    // comment (cert_store.h) for why nothing here waits for it to finish.
    configTime(0, 0, "ntp.nict.jp", "pool.ntp.org");
}

bool download(time_t now, Credentials& out, String& error) {
    String cert, key;
    if (!httpsGet(kCertUrl, cert, error) || !httpsGet(kKeyUrl, key, error)) {
        return false;
    }
    time_t not_after = 0;
    if (!validate(cert, key, now, not_after, error)) {
        error = "downloaded " + error;
        return false;
    }
    out.cert_pem = std::move(cert);
    out.key_pem = std::move(key);
    out.not_after = not_after;
    out.from_cache = false;
    return true;
}

bool loadFromCache(time_t now, Credentials& out, String& error) {
    Preferences prefs;
    if (!prefs.begin(kNvsNamespace, /*readOnly=*/true)) {
        error = "no cached certificate";
        return false;
    }
    String cert = prefs.getString(kNvsCertKey);
    String key = prefs.getString(kNvsKeyKey);
    prefs.end();
    if (cert.isEmpty() || key.isEmpty()) {
        error = "no cached certificate";
        return false;
    }
    time_t not_after = 0;
    if (!validate(cert, key, now, not_after, error)) {
        error = "cached " + error;
        return false;
    }
    out.cert_pem = std::move(cert);
    out.key_pem = std::move(key);
    out.not_after = not_after;
    out.from_cache = true;
    return true;
}

bool saveToCache(const Credentials& credentials) {
    Preferences prefs;
    if (!prefs.begin(kNvsNamespace, /*readOnly=*/false)) return false;
    const bool ok = prefs.putString(kNvsCertKey, credentials.cert_pem) > 0 &&
                     prefs.putString(kNvsKeyKey, credentials.key_pem) > 0;
    prefs.end();
    return ok;
}

}  // namespace cert_store
