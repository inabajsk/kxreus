#ifndef BLE_LINK_H
#define BLE_LINK_H

#include <Arduino.h>

/// This AtomS3 as a BLE CENTRAL, querying a phone's own Flutter app --
/// which runs as the BLE PERIPHERAL (GATT server), resident in the
/// background -- for compute this chip does not have (voice, vision, an
/// LLM call; whatever a future BRAIN mode ends up asking for). The roles
/// are the reverse of the usual "phone scans for the gadget" pattern
/// on purpose: the operator's own request was a phone app that stays
/// resident and ANSWERS the robot's own queries on demand, not one the
/// robot has to already be advertising to before the phone can reach it.
///
/// First milestone only: connect, and carry one request/reply round
/// trip. Nothing here yet feeds a real command into PolicyMode -- see
/// this file's own top-level comment in whichever mode ends up calling
/// query() first.
namespace BleLink {

/// 128-bit UUIDs, arbitrary but fixed -- must match the phone app's own
/// GATT server exactly (see app/kxr_brain's own ble_server.dart).
constexpr const char* SERVICE_UUID = "6e9d4001-6c5d-4f5f-9b1e-3a5c8f2d7a01";
/// Central writes a request into this one.
constexpr const char* QUERY_CHAR_UUID = "6e9d4002-6c5d-4f5f-9b1e-3a5c8f2d7a01";
/// Phone notifies its answer on this one, once ready -- separate from
/// QUERY rather than round-tripping a single read/write characteristic,
/// so a slow (LLM-backed) answer never has to race a write meant to
/// start the NEXT request.
constexpr const char* RESPONSE_CHAR_UUID = "6e9d4003-6c5d-4f5f-9b1e-3a5c8f2d7a01";

/// Longest request/response this link carries in one shot. Generous for
/// now (a short text command out, a short text answer back); revisit if
/// a later BRAIN mode needs to carry audio or an image.
constexpr size_t MAX_PAYLOAD = 200;

/// Starts BLE (NimBLE) and begins scanning for a phone advertising
/// SERVICE_UUID. Call once, from setup().
void begin();

/// Drives scanning/connecting/reconnecting. Call every loop() -- cheap
/// when already connected (NimBLE's own callbacks do the real work;
/// this just retries a scan if the link dropped).
void poll();

/// Whether a phone is currently connected AND its characteristics have
/// been discovered -- query() fails outright before this is true.
bool connected();

/// Write `req` to QUERY, then wait up to `timeout_ms` for a RESPONSE
/// notify. Blocks the calling task for as long as the phone takes to
/// answer (or until timeout) -- fine for an occasional BRAIN-mode
/// request, not something to call from a tight control loop.
///
/// @param resp      buffer to fill.
/// @param resp_cap  its capacity.
/// @param resp_len  set to the reply's actual length on success.
/// @return true if a reply arrived in time.
bool query(const uint8_t* req, size_t req_len, uint8_t* resp, size_t resp_cap,
           size_t* resp_len, uint32_t timeout_ms = 5000);

}  // namespace BleLink

#endif  // BLE_LINK_H
