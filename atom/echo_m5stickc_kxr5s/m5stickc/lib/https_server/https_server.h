#pragma once

#include <Arduino.h>

/// The phone control page's HTTPS twin, reachable with nothing to
/// configure on an iPhone: scan the same QR code kWebPage's own `http://`
/// URL already produces, and (once a certificate is ready) it redirects
/// to `https://<ip-with-dashes>.local-ip.sh/` -- a secure origin, which is
/// the one thing BridgeMode's own voiceBtn (see web_page.h) needs to
/// unlock SpeechRecognition. Modelled on
/// https://github.com/iory/atoms3-voice-control's own local-ip.sh
/// certificate approach; see cert_store.h for what makes that possible
/// with no domain of this device's own.
///
/// Deliberately NOT a replacement for net.cpp's own plain WebServer:
/// that one keeps every route as it already is (Wi-Fi provisioning does
/// not need a secure origin, and touching its own already-working code
/// for this would be all risk and no benefit). This is a second,
/// parallel server on port 443, serving only the routes the control
/// page's own JS actually calls -- see https_server.cpp's own comment for
/// the exact list -- built from the very same net::buildInfoJson() /
/// net::buildCommandJson() / policy:: upload calls the plain server uses,
/// so the two never drift.
namespace https_server {

/// Starts the state machine (does not block): once Wi-Fi is on a real
/// network (not net::Status::STANDALONE_AP -- there is nothing beyond
/// that AP to reach local-ip.sh or NTP through) and the clock is synced,
/// tries to load a cached certificate, or download a fresh one, and once
/// one validates, starts actually listening. Call once from setup().
void begin();

/// Advances the state machine and, once serving, checks for the daily
/// refresh. Cheap; call every loop().
void poll();

/// Whether the HTTPS server is up and answering right now -- what the
/// plain WebServer's own "/" handler checks before redirecting there
/// instead of serving kWebPage directly (see net.cpp).
bool isReady();

/// The address to redirect a phone to, valid only once isReady() -- e.g.
/// "https://192-168-1-50.local-ip.sh/". Empty otherwise.
String url();

}  // namespace https_server
