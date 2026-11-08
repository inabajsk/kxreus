#ifndef HOST_RELAY_H
#define HOST_RELAY_H

#include <rcb4_link.h>

/// Feeds every byte a host sends -- over direct USB Serial, or over
/// ESP-NOW from a PC-side ATOM Echo (see EspNowLink) -- into `link`'s own
/// frame parser, and sends any reply back the way it came.
///
/// Runs unconditionally, from every Mode, not just BridgeMode: the IMU
/// (0x90) and M5StickV (0x91) opcodes never touch the real RCB-4's own
/// UART at all (Rcb4Link::feedFromHost() answers them itself), so there is
/// nothing unsafe about answering them no matter what the front button has
/// cycled to -- a robot walking under PolicyMode can still be asked its
/// attitude or what its camera sees. An ORDINARY RCB-4 command is a
/// different matter: it does reach the real board, over the one UART
/// PolicyMode may itself be mid-transaction on, so that stays gated by
/// Rcb4Link::setPassthroughEnabled -- BridgeMode's own enter()/exit() is
/// what turns that on and off; this module just carries whatever the
/// current setting allows.
///
/// Also carries the plain-text Wi-Fi setup protocol ("net ...", see
/// net::handleSetupLine) -- Serial-only, and available from every mode for
/// the same reason main.cpp's own onMultiClick (Wi-Fi recovery gesture) is:
/// a robot stuck on bad credentials needs a way back in regardless of
/// which mode it booted into.
namespace HostRelay {

/// Call once every main loop(), unconditionally, regardless of
/// current_mode. Order relative to kModes[current_mode]->loop() does not
/// matter -- this never touches a Mode's own state.
void loop(Rcb4Link& link);

}  // namespace HostRelay

#endif  // HOST_RELAY_H
