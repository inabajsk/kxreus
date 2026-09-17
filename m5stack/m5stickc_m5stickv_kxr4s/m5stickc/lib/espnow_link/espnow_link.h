#ifndef ESPNOW_LINK_H
#define ESPNOW_LINK_H

#include <Arduino.h>

/// ESP-NOW link to a PC-side ATOM Echo, carrying the exact same RCB-4 byte
/// stream BridgeMode already relays over USB Serial.
///
/// This reuses, byte-for-byte, the protocol already proven working in
/// ~/kxreus/atom/s3_echo_bridge (atom_echo_voice_cmd_pc.ino's RCB-4-relay
/// half, and atoms3_simple_robot.ino's own receiving side): PKT_DATA
/// carries a sequence number and is stop-and-wait ACKed, because ESP-NOW's
/// own physical-layer retry alone was measured losing bytes under a heavy,
/// continuous burst (RCB-4 ROM motion-table reads/writes) -- and the RCB-4
/// UART byte stream cannot tolerate even one dropped byte before its own
/// framing desyncs. PKT_PING/PKT_PONG is a heartbeat, used only to know
/// whether the peer is currently reachable (isLinkUp()), not for data.
///
/// What this is FOR: reaching this robot from kxreus/atominterface.l
/// without a USB cable to it -- a PC-side ATOM Echo, plugged into the PC
/// over its own USB-serial port, relays atominterface.l's RCB-4 byte
/// stream over ESP-NOW instead. BridgeMode treats bytes arriving here
/// exactly like bytes from Serial (see its own HostSource), so
/// atominterface.l's `:com-open` needs no change beyond pointing at the
/// ATOM Echo's tty instead of this board's.
///
/// Channel: pinned to a fixed constant (see the .cpp), matching net.cpp's
/// own WiFi.softAP() default channel -- this robot's only WiFi mode so far
/// (STANDALONE_AP/provisioning). If this robot ever joins a real WiFi
/// router instead, that connection's own channel would need to be
/// threaded through here, and to the PC-side ATOM Echo (which has no other
/// way to learn it) -- not yet done; this first version assumes AP mode.
namespace EspNowLink {

/// Bring up ESP-NOW and register the PC-side ATOM Echo as a peer.
///
/// Its MAC comes from pc_mac.h, generated the same way
/// ~/kxreus/atom/s3_echo_bridge's own pairing does -- see this project's
/// own atom_echo_pc/README.md for the exact command. Call after
/// net::begin() (WiFi must already be in some mode; ESP-NOW rides on top
/// of whichever one that is).
void begin();

/// Heartbeat bookkeeping -- call once every loop(), same as net::poll().
void poll();

/// Whether a ping or a data packet has been heard from the peer recently
/// enough to call the link up. Not a permission check -- write() attempts
/// the send regardless -- just what a status display would want to show.
bool isLinkUp();

/// Whether a real PKT_DATA frame -- not the PKT_PING/PONG heartbeat -- has
/// gone by in either direction recently enough to call this "actively
/// relaying" rather than merely "linked but idle". A status display's own
/// third state; isLinkUp() alone cannot tell these two apart, since the
/// heartbeat keeps it true either way.
bool isDataActive();

/// Bytes already unwrapped from PKT_DATA framing and waiting to be read --
/// same shape as Serial.available()/Serial.read(), so BridgeMode::loop()
/// can drain this exactly like the Serial one.
int available();
int read();

/// Send bytes to the peer, chunked to this link's own MTU and confirmed
/// with the same seq+ACK stop-and-wait retry described above.
///
/// Blocking: worst case (peer never acks at all) is bounded but not
/// short -- the same bound ~/kxreus/atom/s3_echo_bridge's own proven
/// firmware already accepts in its own loop(), carried over unchanged.
void write(const uint8_t* data, size_t len);

}  // namespace EspNowLink

#endif  // ESPNOW_LINK_H
