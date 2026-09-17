#pragma once

#include <Arduino.h>

#include <ctime>

/// Fetches and caches the wildcard TLS certificate local-ip.sh publishes,
/// the same one https://github.com/iory/atoms3-voice-control uses to get
/// an iPhone onto a secure origin with nothing to configure: local-ip.sh
/// resolves "<ip-with-dashes>.local-ip.sh" to that literal IP and hands
/// out a Let's Encrypt wildcard cert (with its private key, publicly, for
/// every device to share) for "*.local-ip.sh" -- so this device's own
/// generated hostname is already covered by a certificate a real browser
/// trusts, without this device ever proving domain ownership itself.
///
/// Cached in NVS (Preferences) rather than a filesystem: this build has
/// none (huge_app.csv trades the SPIFFS partition for one large app
/// partition -- see platformio.ini), and the cert+key together are a few
/// KiB, comfortably inside one NVS entry.
namespace cert_store {

struct Credentials {
    String cert_pem;
    String key_pem;
    time_t not_after = 0;  // UTC epoch seconds
    bool from_cache = false;
};

/// Fetches https://local-ip.sh/server.pem and .../server.key over HTTPS
/// (verified against the embedded Let's Encrypt roots -- see
/// letsencrypt_roots.h; this device has no cert of its own yet, which is
/// the whole reason this fetch has to happen at all), and checks the pair
/// parses, matches, and is not already expired.
///
/// Requires a real network path out (DNS to a public resolver, and an
/// actual route to local-ip.sh) -- this cannot succeed while this robot
/// is only its own standalone access point (see net::Status::
/// STANDALONE_AP), since there is nothing beyond that AP to reach the
/// internet through.
///
/// @param now     current UTC time (see syncTime()) -- validated against,
///                not assumed; a clock that has never been set (before
///                NTP) would otherwise accept an already-expired cert.
/// @param error    left with a human-readable reason on failure.
bool download(time_t now, Credentials& out, String& error);

/// Reads back what saveToCache() last stored, validated the same way
/// download()'s own result is (parses, key matches cert, not expired at
/// `now`) -- an expired or corrupt cache is exactly as much a failure as
/// no cache at all, not something to hand to the TLS server anyway.
bool loadFromCache(time_t now, Credentials& out, String& error);

bool saveToCache(const Credentials& credentials);

/// Sets the system clock from NTP (blocking, up to a few seconds) --
/// needed before download()/loadFromCache() can judge a certificate's
/// expiry at all. Returns false if no server answered in time.
bool syncTime();

/// Whether `now` looks like a real, NTP-set clock rather than an unset
/// RTC still reading close to the Unix epoch (1970) -- true once past a
/// fixed recent cutoff (2025-01-01T00:00 UTC). Without this check, an
/// unset clock reads as long before any real certificate's own notBefore,
/// which download()/loadFromCache() would then wrongly accept as "not
/// expired" (this device only ever checks notAfter, not notBefore).
bool timeIsValid(time_t now);

}  // namespace cert_store
