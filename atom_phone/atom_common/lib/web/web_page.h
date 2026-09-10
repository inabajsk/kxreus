#pragma once

#include <pgmspace.h>

/// Served instead of kWebPage while net::provisioning() is up: a phone that
/// just joined the robot's own setup AP (see net::provisionSsid(), named
/// from ROBOT_NAME so several robots' AP names are never the same one) has
/// no other network to reach yet, so this is a plain form POSTing straight
/// to this same device rather than the joystick page.
///
/// Used to need no script at all -- a captive portal's browser is sometimes
/// a stripped one -- but a name to pick beats a name to remember and retype,
/// so this now calls net's own /scan on load and lets the operator tap a
/// nearby network instead. Typing one by hand still works exactly as before
/// (the SSID field is never read-only), for whatever a scan does not find --
/// a hidden network, or one just out of range for a phone in range of this
/// robot's own AP but not necessarily of the network it should join.
///
/// Picking a network this robot has a password remembered for (see
/// net::rememberNetwork(), applied automatically the first time a password
/// is typed for it) hides the password field rather than asking again --
/// leaving it blank on submit is what tells /save to use the saved one (see
/// handleSaveRequest's own comment). Typing a name that was not on the list
/// always asks for a password: this page has no way to know a hand-typed
/// name is one the robot already remembers without asking it, and asking
/// while typing on every keystroke would be worse than just showing the
/// field -- required by default there, with a checkbox for the one case
/// that is not a mistake (a genuinely open network typed by hand).
///
/// The password field is REQUIRED except for a known or an open network
/// (scan results say which -- see net.cpp's own WiFi.encryptionType() use):
/// a blank password submitted for anything else once already tried joining
/// a real network with no password at all and failed silently, over and
/// over, with nothing on this page saying why. Leaving it required for
/// everything but those two cases is what stops that happening quietly a
/// second time.
const char kProvisionPage[] PROGMEM = R"HTML(<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>robot wifi setup</title>
<style>
  body { margin:0; font:16px/1.4 -apple-system,system-ui,sans-serif;
         background:#111; color:#eee; padding:20px; box-sizing:border-box; }
  h1 { font-size:18px; }
  label { display:block; margin-top:14px; font-size:14px; color:#9aa; }
  input { width:100%; box-sizing:border-box; font-size:16px; padding:10px;
          border-radius:8px; border:1px solid #444; background:#1b1b1b;
          color:#eee; margin-top:4px; }
  button { margin-top:20px; width:100%; font:600 16px/1 inherit; padding:14px 0;
           border:0; border-radius:12px; background:#1e5b32; color:#eee; }
  .alt { background:#2b2f36; margin-top:32px; }
  hr { border:0; border-top:1px solid #333; margin:28px 0 0; }
  .or { text-align:center; color:#666; font-size:13px; margin:10px 0 0; }
  #scanStatus { font-size:13px; color:#9aa; margin-top:14px; }
  #netList { margin-top:8px; max-height:220px; overflow-y:auto;
             display:flex; flex-direction:column; gap:6px; }
  .netrow { margin:0; width:100%; text-align:left; font:14px/1.3 inherit;
            padding:10px 12px; border-radius:8px; border:1px solid #333;
            background:#1b1b1b; color:#eee; }
  .netrow[aria-pressed="true"] { outline:2px solid #48b57e; }
  .netrow .sub { display:block; font-size:12px; color:#789; margin-top:2px; }
  #rescan { margin-top:10px; width:100%; font:14px/1 inherit; padding:10px 0;
            border:0; border-radius:10px; background:#2b2f36; color:#eee; }
  #passNote { font-size:13px; color:#9aa; margin-top:14px; }
  /* Deliberately no `display` here, unlike most of this page's rules: an ID
     or class rule that set one would outrank [hidden]'s own display:none at
     the same element (higher specificity), silently undoing openLabel.hidden
     in the script below. Left to the plain `label` rule above instead. */
  .checkrow { font-size:13px; color:#9aa; }
  .checkrow input { width:auto; margin:0 6px 0 0; vertical-align:middle; }
</style></head><body>
<h1>Wi-Fi for this robot</h1>
<p>Join the network you want the robot to use here. It will drop its own
setup access point (the one this phone is joined to right now) as soon as
you submit.</p>
<form method="POST" action="/save" id="wifiForm">
  <label>Network name (SSID)<input name="ssid" id="ssid" autocapitalize="off"
    autocorrect="off" required placeholder="pick one below, or type it here"></label>
  <div id="scanStatus">scanning for nearby networks…</div>
  <div id="netList"></div>
  <button type="button" id="rescan">Rescan</button>
  <label id="passLabel">Password<input name="pass" id="pass" type="password"></label>
  <label id="openLabel" class="checkrow" hidden>
    <input type="checkbox" id="openCheck"> This network has no password
  </label>
  <p id="passNote" hidden>This robot already has a password saved for this
    network -- leave this blank to use it, or type a new one to replace it.</p>
  <button type="submit">Save and connect</button>
</form>
<hr><p class="or">-- or --</p>
<p>No Wi-Fi where this robot is going? Stay joined to this same access point
and control the robot straight over it -- no network needed.</p>
<form method="POST" action="/ap">
  <button class="alt" type="submit">No Wi-Fi here, use this AP</button>
</form>
<script>
const ssidInput = document.getElementById('ssid');
const passInput = document.getElementById('pass');
const passLabel = document.getElementById('passLabel');
const passNote = document.getElementById('passNote');
const openLabel = document.getElementById('openLabel');
const openCheck = document.getElementById('openCheck');
const netList = document.getElementById('netList');
const scanStatus = document.getElementById('scanStatus');

function selectNetwork(ssid, known, open, row) {
  ssidInput.value = ssid;
  passInput.value = '';
  for (const r of netList.querySelectorAll('.netrow')) {
    r.setAttribute('aria-pressed', r === row ? 'true' : 'false');
  }
  // known networks still show the password field's LABEL text via passNote,
  // but the field itself is only hidden, not removed -- typing in it still
  // overrides the saved password (see this file's own top comment).
  passNote.hidden = !known;
  passLabel.hidden = known;
  // The scan already knows whether this one is open, so the manual
  // "no password" checkbox (see below) would only be redundant here --
  // hidden rather than shown unchecked, which would look like this
  // network needed a password when open already says it does not.
  openLabel.hidden = true;
  openCheck.checked = false;
  // A blank password is only ever right for a KNOWN network (the device
  // fills in what it already has) or an OPEN one (there is nothing to
  // fill in). Anything else -- a network this device has never joined
  // before, picked from this very list -- submitting blank just tried an
  // empty password against a real one once already: the browser now
  // refuses to send the form at all until something is typed.
  passInput.required = !known && !open;
}

// Typing a name the list did not offer -- or editing one that was picked --
// always means "ask for a password": this page has no scan entry for a
// hand-typed name, so it cannot know it is open or already remembered.
// Required by default (most networks need one); the checkbox below is the
// escape hatch for the genuinely open one, since there is no scan data here
// to tell that apart from someone who just forgot to type it.
ssidInput.addEventListener('input', () => {
  for (const r of netList.querySelectorAll('.netrow')) {
    r.setAttribute('aria-pressed', 'false');
  }
  passNote.hidden = true;
  passLabel.hidden = false;
  openLabel.hidden = false;
  passInput.required = !openCheck.checked;
});
openCheck.addEventListener('change', () => {
  passInput.required = !openCheck.checked;
  if (openCheck.checked) passInput.value = '';
});

async function scan() {
  scanStatus.textContent = 'scanning for nearby networks…';
  netList.innerHTML = '';
  try {
    const r = await fetch('/scan', {cache: 'no-store'});
    const data = await r.json();
    const nets = Array.isArray(data.networks) ? data.networks : [];
    if (nets.length === 0) {
      scanStatus.textContent = 'no networks found nearby -- type the name below';
      return;
    }
    scanStatus.textContent = 'tap a network, or type its name below:';
    for (const n of nets) {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'netrow';
      row.setAttribute('aria-pressed', 'false');
      const sub = document.createElement('span');
      sub.className = 'sub';
      sub.textContent = `${n.rssi} dBm`
        + (n.known ? ' · password saved' : n.open ? ' · open' : '');
      row.textContent = n.ssid + ' ';
      row.appendChild(sub);
      row.addEventListener('click', () => selectNetwork(n.ssid, n.known, n.open, row));
      netList.appendChild(row);
    }
  } catch (e) {
    scanStatus.textContent = 'scan failed -- type the network name below';
  }
}
document.getElementById('rescan').addEventListener('click', scan);
scan();
</script>
</body></html>)HTML";

/// The page a phone gets when it scans the QR code on the LCD.
///
/// In PROGMEM, so it costs flash and not the ~30 KiB of heap that is all the
/// Wi-Fi stack leaves. Self-contained for the same reason a QR code is used
/// at all: the phone has just joined a robot's own network (or its setup AP)
/// and may have no route to the internet, so nothing here may be fetched
/// from one -- no framework, no font, no icon, and net::handleInfoRequest()
/// (the one fetch this page does make) is answered by the same device.
///
/// This is the SAME bytes on every robot this firmware runs on -- kxrl4d,
/// kxrl4t, kxrl2g, kxrl6, whichever else joins the family later. Nothing
/// robot-specific is baked in; the one GET to /info on load is what makes
/// that true, carrying the trained command band (a robot that cannot turn
/// simply reports wzMax 0 and the stick's left-right axis goes along for
/// the ride unused), the actor names, and the onboard motions worth
/// offering (see policy::motion()). Get that one fetch wrong and the
/// symptom is a page that looks fine and sends nonsense -- see loadInfo().
///
/// The control is an analogue stick rather than a row of buttons, because the
/// command is two continuous numbers and buttons can only send their corners.
/// Pointer events carry a finger and a mouse identically, so the same page is
/// the phone client and the PC client.
///
/// It speaks the same 9 byte command frame as everything else, hex-encoded in
/// a GET so the device needs no JSON parser and no request body: the whole
/// server is a string comparison and a hex decode.
const char kWebPage[] PROGMEM = R"HTML(<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>robot</title>
<style>
  :root { color-scheme: dark; }
  html,body { height:100%; }
  body { margin:0; font:15px/1.4 -apple-system,system-ui,sans-serif;
         background:#111; color:#eee; -webkit-user-select:none; user-select:none;
         touch-action:none; overscroll-behavior:none;
         display:flex; flex-direction:column; }
  header { padding:10px 14px; background:#1b1b1b; flex:0 0 auto; }
  h1 { font-size:15px; margin:0; font-weight:600; }
  #state { font-size:13px; color:#9aa; margin-top:2px; }
  /* stickwrap is the ONLY thing allowed to shrink: min-height:0 overrides a
     flex item's default (content size), which is what let a fixed-size
     canvas push .modes off the bottom of a short viewport (a phone in
     landscape, or one whose on-screen chrome eats more height than usual)
     instead of getting smaller itself. See sizeStick(), which then sizes
     the canvas to whatever room this box actually has left. */
  /* The stick and the attitude indicator side by side, per request -- the
     stick can be small, so #viz splits the room evenly and sizeStick()
     (JS) fits the canvas to whatever half it lands in. */
  #viz { flex:1 1 auto; min-height:0; display:flex; flex-direction:row; }
  #stickwrap { flex:1 1 50%; min-height:0; overflow:hidden;
               display:flex; align-items:center; justify-content:center; }
  #stick { touch-action:none; }
  #attwrap { flex:1 1 50%; min-height:0; overflow:hidden;
             display:flex; flex-direction:column; align-items:center;
             justify-content:center; gap:8px; }
  /* A flat rectangle plus a thin top face folded back with rotateX(90deg)
     is enough perspective to read as a tilting box, not a photoreal robot --
     that reads fine at a glance and costs nothing to load. */
  #tiltwrap { perspective: 340px; }
  #tiltbox { position:relative; width:72px; height:96px;
             transform-style:preserve-3d; transition:transform 120ms linear; }
  .tb-front { position:absolute; inset:0; border-radius:10px;
              background:#2b6f4a; border:2px solid #48b57e; }
  .tb-top { position:absolute; left:2px; right:2px; top:-13px; height:13px;
            background:#1f5238; border-radius:7px 7px 0 0;
            transform-origin:bottom; transform:rotateX(90deg); }
  #atttext { font-size:12px; color:#9aa; }
  #attraw { font-size:11px; color:#678; font-variant-numeric:tabular-nums; }
  .modes { display:grid; grid-template-columns:repeat(3,1fr); gap:8px;
           padding:14px 14px 8px; max-width:460px; margin:0 auto; width:100%;
           box-sizing:border-box; flex:0 0 auto; }
  button { font:600 16px/1 inherit; padding:20px 0; border:0; border-radius:12px;
           background:#2b2f36; color:#eee; }
  button:active { filter:brightness(1.4); }
  button[aria-pressed="true"] { outline:2px solid #eee; }
  .run { background:#1e5b32; } .hold { background:#6b5a10; }
  .free { background:#6b2020; }
  .rise { background:#1e4a6b; } .sit { background:#4a2b6b; }
  #imu { font-size:14px; }
  .motions { display:flex; gap:8px; padding:0 14px 14px; max-width:460px;
             margin:0 auto; width:100%; box-sizing:border-box; flex:0 0 auto; }
  #motionSel { flex:1 1 auto; font-size:14px; padding:0 10px; border-radius:8px;
               border:1px solid #444; background:#1b1b1b; color:#eee; }
  #motionGo { flex:0 0 auto; padding:10px 18px; background:#5a3d0e; }
  .logsec { padding:0 14px 14px; max-width:460px; margin:0 auto; width:100%;
            box-sizing:border-box; flex:0 0 auto; }
  #logStatus { font-size:11px; color:#678; margin-bottom:6px;
               font-variant-numeric:tabular-nums; }
  .logrow { display:flex; gap:8px; }
  #logServer { flex:1 1 auto; font-size:13px; padding:8px 10px; border-radius:8px;
               border:1px solid #444; background:#1b1b1b; color:#eee; }
  #logServerSave, #wifiSetup { flex:0 0 auto; padding:8px 14px; font-size:13px;
                   background:#2b2f36; }
  /* Pinned to the VIEWPORT, not to the flex column above -- so it stays
     reachable even if that layout is ever wrong again, which is exactly the
     failure this page had once already: the stick rendered oversized, the
     mode buttons scrolled out of reach, and the only way back to "hold" was
     to power the robot off. */
  #estop { position:fixed; top:10px; right:10px; z-index:1000;
           width:76px; height:76px; border-radius:50%; padding:0;
           background:#8a1f1f; color:#fff; font:700 15px/1 inherit;
           box-shadow:0 2px 10px rgba(0,0,0,.6); }
</style></head><body>
<header>
  <h1 id="title">robot</h1>
  <div id="state">connecting…</div>
</header>
<button id="estop">HOLD</button>
<div id="viz">
  <div id="stickwrap"><canvas id="stick" width="280" height="280"></canvas></div>
  <div id="attwrap">
    <div id="tiltwrap"><div id="tiltbox">
      <div class="tb-top"></div>
      <div class="tb-front"></div>
    </div></div>
    <div id="atttext">roll -- pitch --</div>
    <div id="attraw">g --</div>
  </div>
</div>
<div class="modes">
  <button class="run"  data-mode="1">run</button>
  <button class="hold" data-mode="2">hold</button>
  <button class="free" data-mode="0">free</button>
  <button class="rise" data-mode="3">rise</button>
  <button class="sit"  data-mode="4">sit</button>
  <button id="imu">attitude</button>
</div>
<div class="motions">
  <select id="motionSel"></select>
  <button id="motionGo">call motion</button>
</div>
<div class="logsec">
  <div id="logStatus">log: --</div>
  <div class="logrow">
    <input id="logServer" placeholder="log server host:port, e.g. 192.168.1.23:8787"
      autocapitalize="off" autocorrect="off">
    <button id="logServerSave">save</button>
    <button id="wifiSetup">Wi-Fi setup</button>
  </div>
</div>
<script>
// This page is the same PROGMEM bytes on every robot this firmware runs on
// (see the file's own top comment) -- everything that differs between them
// (the trained command band, which turns into a hard clamp on the device
// regardless of what this sends; the named onboard motions; the name in the
// header) is fetched once from /info rather than baked in here. Filled in
// by loadInfo(), called once at the bottom of this script; VX_MAX starts
// at 0 so nothing reaches for the stick before real numbers have arrived.
let VX_MAX = 0, VX_MIN = 0, WZ_MAX = 0;
// Below this the stick counts as centred and sends 0 -- which the device
// still turns into VX_MIN, not a stop (that policy is never trained to
// stand still while running; see /info's own vxMin).
const DEAD = 0.12;

// 2 (HOLD), not 0 (FREE): tick() below starts firing at 10 Hz as soon as
// this script runs, and every one of those ticks is a real command frame --
// there is no "just checking in, no request" value in this protocol (see
// frame()). A page load or reload (this happens on EVERY one -- switching
// Wi-Fi networks and reopening the page, a phone waking from sleep, the
// Wi-Fi-setup button's own reload) used to open with FREE, which drops the
// servos on whatever pose the robot was already in the instant that first
// frame lands, with nobody having asked for that. HOLD ramps to and holds
// the home stance instead -- unrequested too, but recoverable, where FREE
// is not.
let mode = 2, vx = 0, wz = 0, useImu = false;
// Which RCB-4 onboard motion-table slot "call motion" asks for -- carried in
// the host frame's vx field when mode is 5 (Request::MOTION), a velocity
// having no meaning there. Populated from /info's own motions list, which
// is this robot's real Heart to Heart project (see
// tools/motions_from_h4p.py), not a generic 0-119 list -- most of the 120
// slots are factory-empty and calling one is pointless at best.
let motionNumber = 0;
// Filled in by loadInfo(); the field-log module below needs it before that
// first fetch resolves, so records logged in the meantime say "unknown"
// (see FieldLog.record()) rather than silently mislabelling themselves.
let ROBOT = 'unknown';
// The real servo ids, in the same fixed order every tick's own "pulse" and
// "target" arrays line up with (see net::setServoIds()) -- filled in by
// loadInfo() alongside ROBOT, and logged once per FieldLog record (see its
// own comment on why: a record is meant to stand on its own later, without
// also having to ask this robot what its own servo layout was).
let SERVO_IDS = [];

const cv = document.getElementById('stick');
const ctx = cv.getContext('2d');
// Mutable, not const: sizeStick() below recomputes these to whatever
// #stickwrap actually has room for, which is what stops the stick from
// forcing the mode buttons off the bottom of a short or landscape screen --
// the failure this page had once already (see #estop's own comment).
let R = cv.width / 2, KNOB = 34, REACH = R - KNOB - 6;
let kx = 0, ky = 0, dragging = null;

function sizeStick() {
  const wrap = document.getElementById('stickwrap');
  // Floor at 120: a stick smaller than that is not worth having, and a wrap
  // that briefly reports 0 (mid-layout) must not zero the canvas out.
  const size = Math.max(120, Math.min(320, wrap.clientWidth, wrap.clientHeight));
  cv.width = size; cv.height = size;
  R = size / 2;
  KNOB = Math.max(18, Math.round(size * 0.12));
  REACH = R - KNOB - 6;
  draw();
}

function draw() {
  ctx.clearRect(0, 0, cv.width, cv.height);
  // The ring the knob travels in, and a crosshair for the two axes. No
  // dead-zone circle: at DEAD it would have a radius of twelve pixels and sit
  // entirely underneath a knob of thirty-four, so it drew nothing anyone
  // could see.
  ctx.strokeStyle = '#2b2f36'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(R, R, REACH, 0, 7); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(R - REACH, R); ctx.lineTo(R + REACH, R);
  ctx.moveTo(R, R - REACH); ctx.lineTo(R, R + REACH); ctx.stroke();
  ctx.fillStyle = dragging !== null ? '#4a7fd0' : '#39404a';
  ctx.beginPath(); ctx.arc(R + kx, R + ky, KNOB, 0, 7); ctx.fill();
}

function setFromKnob() {
  const nx = kx / REACH, ny = ky / REACH;   // -1..1, y down
  const mag = Math.hypot(nx, ny);
  if (mag < DEAD) {
    vx = 0; wz = 0;
  } else {
    // Up is forward; pulling the stick down still only asks for forward
    // speed (there is no reverse on any of these robots' walk policies),
    // scaled from the dead zone's edge up to VX_MAX so the stick's range is
    // not mostly dead air.
    const fwd = Math.max(0, -ny);
    vx = VX_MIN + fwd * (VX_MAX - VX_MIN);
    // Left-right only means anything on a robot whose walk policy was
    // trained to turn at all (WZ_MAX > 0, from /info) -- kxrl4d's was not,
    // and sending it a nonzero wz would do nothing anyway (the device
    // clamps to +-WZ_MAX itself), but a stick axis that visibly does
    // nothing is worse than one that was never drawn as live.
    wz = WZ_MAX > 0 ? -nx * WZ_MAX : 0;
  }
  draw();
}

function moveKnob(ev) {
  const r = cv.getBoundingClientRect();
  let dx = ev.clientX - r.left - R, dy = ev.clientY - r.top - R;
  const mag = Math.hypot(dx, dy);
  if (mag > REACH) { dx *= REACH / mag; dy *= REACH / mag; }
  kx = dx; ky = dy;
  setFromKnob();
}

cv.addEventListener('pointerdown', ev => {
  ev.preventDefault();
  dragging = ev.pointerId;
  cv.setPointerCapture(ev.pointerId);
  // Touching the stick is asking to move, so it also starts the policy.
  mode = 1;
  moveKnob(ev);
});
cv.addEventListener('pointermove', ev => {
  if (dragging === ev.pointerId) moveKnob(ev);
});
for (const ev of ['pointerup', 'pointercancel']) {
  cv.addEventListener(ev, e => {
    if (dragging !== e.pointerId) return;
    dragging = null;
    // Spring to centre. A stick that stays where it was left is a robot that
    // keeps walking after the finger is gone.
    kx = 0; ky = 0;
    setFromKnob();
  });
}

for (const b of document.querySelectorAll('button[data-mode]')) {
  b.addEventListener('click', () => {
    mode = +b.dataset.mode;
    if (mode !== 1) { kx = 0; ky = 0; setFromKnob(); }
    // rise and sit fire once per ask on the device, so the stick returning
    // to run is what lets them be asked again.
    if (mode === 3 || mode === 4) setTimeout(() => { mode = 1; }, 400);
  });
}
document.getElementById('imu').addEventListener('click', () => {
  useImu = !useImu;
  document.getElementById('imu').textContent =
    useImu ? 'attitude: IMU' : 'attitude: fixed';
});
document.getElementById('imu').textContent = 'attitude: fixed';

const motionSel = document.getElementById('motionSel');

// The one thing this page needs from the device beyond the 10 Hz telemetry
// tick: static per-robot facts that would otherwise have to be a different
// copy of this whole file per robot (see the file's own top comment). Only
// fetched once, on load -- none of this changes while the page is open.
async function loadInfo() {
  try {
    const r = await fetch('/info', {cache: 'no-store'});
    const info = await r.json();
    document.title = info.robot;
    document.getElementById('title').textContent = info.robot;
    ROBOT = info.robot;
    SERVO_IDS = info.servoIds;
    VX_MIN = info.vxMin; VX_MAX = info.vxMax; WZ_MAX = info.wzMax;
    ACTORS = info.actors;
    for (const [num, name] of info.motions) {
      const opt = document.createElement('option');
      opt.value = num;
      opt.textContent = `${num}: ${name}`;
      motionSel.appendChild(opt);
    }
    if (info.motions.length > 0) motionNumber = info.motions[0][0];
  } catch (e) {
    // tick() already reports "no answer from the robot" on the same
    // failure, ten times a second -- nothing more to say here, and the
    // stick simply stays inert (VX_MAX at its startup 0) until a retry
    // works instead of sending a command built from half-loaded numbers.
    setTimeout(loadInfo, 2000);
  }
}
loadInfo();

// Records this robot's own telemetry (attitude chief among it -- see
// tick()'s own call into record()) into the phone's IndexedDB for as long
// as this page is open, regardless of whether any server is configured or
// reachable: the phone is the only durable copy that exists the moment a
// sample is taken, since the AtomS3 itself has no room to keep one (see
// this file's own top comment) and a server -- if there is one at all --
// may be an offline robot AP away. Syncing out to a server, when one is
// configured and answers, is purely opportunistic on top of that; nothing
// here depends on it ever succeeding.
const FieldLog = (() => {
  const DB_NAME = 'kxr-field-log';
  const STORE = 'records';
  // A day boundary on the PHONE's own clock, not the server's: this only
  // groups records into a session name for a human skimming filenames
  // later, and a phone with no network at all still has a clock. The
  // server folders by the date IT received the batch (see log_server.py's
  // own comment on why), which is the authoritative one.
  let session = null;
  let dbPromise = null;

  function openDb() {
    if (dbPromise) return dbPromise;
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, 1);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains(STORE)) {
          db.createObjectStore(STORE, {keyPath: 'id', autoIncrement: true});
        }
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
    return dbPromise;
  }

  function sessionName() {
    if (session) return session;
    const d = new Date();
    const day = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
              + `-${String(d.getDate()).padStart(2, '0')}`;
    session = `${ROBOT}_${day}`;
    return session;
  }

  // Not every 100 ms tick: a control-loop-rate log is more data than a
  // later training run wants to page through for what is fundamentally a
  // slowly-changing attitude signal, and it is this phone's own battery
  // and storage paying for the density. Once every this many ticks.
  const LOG_EVERY_N_TICKS = 5;  // 100 ms * 5 = 2 Hz
  let tickCount = 0;

  async function record(t) {
    tickCount++;
    if (tickCount % LOG_EVERY_N_TICKS !== 0) return;
    const db = await openDb();
    const row = {
      session: sessionName(),
      robot: ROBOT,
      ts: Date.now(),           // ms since epoch, phone clock
      state: t.state, actor: t.actor,
      vx: t.vx, wz: t.wz,
      gravity: t.gravity,
      home_err: t.home_err, err: t.err,
      // Per real servo, same order as servoIds (see SERVO_IDS's own
      // comment): the id array travels with every record rather than once
      // per file, so a single line is enough to know what pulse[i]/
      // target[i] are the i-th of, even read back out of context later.
      servoIds: SERVO_IDS, pulse: t.pulse, target: t.target,
      synced: 0,
    };
    db.transaction(STORE, 'readwrite').objectStore(STORE).add(row);
  }

  async function unsyncedBatch(limit) {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const out = [];
      const req = db.transaction(STORE, 'readonly').objectStore(STORE).openCursor();
      req.onsuccess = () => {
        const cur = req.result;
        if (!cur || out.length >= limit) { resolve(out); return; }
        if (cur.value.synced === 0) out.push(cur.value);
        cur.continue();
      };
      req.onerror = () => reject(req.error);
    });
  }

  async function markSynced(ids) {
    const db = await openDb();
    const tx = db.transaction(STORE, 'readwrite');
    const store = tx.objectStore(STORE);
    // Deleted, not flagged: once the server linked from #logServer has a
    // copy, keeping a second one on the phone forever just spends the
    // phone's own storage on data this page has no other use for.
    for (const id of ids) store.delete(id);
    return new Promise((resolve, reject) => {
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  }

  async function unsyncedCount() {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const req = db.transaction(STORE, 'readonly').objectStore(STORE).count();
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  return {record, unsyncedBatch, markSynced, unsyncedCount};
})();

// The server is a plain "host:port" the operator types in once (see
// #logServer/#logServerSave below); persisted per-phone in localStorage,
// which -- like IndexedDB above -- is private to this page's own origin
// and so survives a reload but not a different phone.
function logServerUrl() {
  const hostport = localStorage.getItem('kxrLogServer');
  return hostport ? `http://${hostport}` : null;
}

document.getElementById('logServer').value =
  localStorage.getItem('kxrLogServer') || '';
document.getElementById('logServerSave').addEventListener('click', () => {
  const v = document.getElementById('logServer').value.trim();
  if (v) localStorage.setItem('kxrLogServer', v);
  else localStorage.removeItem('kxrLogServer');
  syncNow();
});

// The log server is very often on a different network than whatever this
// robot is joined to right now (e.g. the robot is still on its own
// STANDALONE_AP -- see net::useOwnAccessPoint() -- because that is the only
// network it had when it was carried out here). Reaching net's own Wi-Fi
// setup form used to mean walking back to the robot and double-clicking its
// button (see status_mode.cpp's onDoubleClick); this does the same thing
// (net::beginProvisioning(), via POST /provision) from wherever this phone
// already is.
document.getElementById('wifiSetup').addEventListener('click', async () => {
  const statusEl = document.getElementById('logStatus');
  try {
    await fetch('/provision', {method: 'POST'});
  } catch (e) {
    // Expected as often as not: beginProvisioning() restarts this robot's
    // own AP (see its own comment in net.cpp) even when this phone is
    // already joined to it, which can drop the very request that asked for
    // it. That is not a failure -- the poll below is what actually finds
    // out whether it worked.
  }
  // A single reload after a fixed pause guessed wrong about how long the AP
  // takes to come back up and this phone to rejoin it (that first version of
  // this button did exactly that, and it under-shot in practice). Polling
  // for "/" to answer again and reloading the moment it does is right
  // whether that takes one second or fifteen.
  let tries = 0;
  const MAX_TRIES = 20;  // ~20 s
  const poll = async () => {
    tries++;
    statusEl.textContent = `log: opening Wi-Fi setup… (${tries}/${MAX_TRIES})`;
    try {
      const ctrl = new AbortController();
      const t = setTimeout(() => ctrl.abort(), 1000);
      const r = await fetch('/', {cache: 'no-store', signal: ctrl.signal});
      clearTimeout(t);
      if (r.ok) { location.reload(); return; }
    } catch (e) {
      // Not reachable yet -- keep polling below.
    }
    if (tries >= MAX_TRIES) {
      // Most likely this phone was on a REAL Wi-Fi network, not this
      // robot's own AP: beginProvisioning() only restarts the robot's
      // radio, it cannot move this phone onto a different network by
      // itself, so no amount of polling from here would ever succeed.
      statusEl.textContent = `log: could not reach Wi-Fi setup automatically`
        + ` -- join "${ROBOT}-wifi" on this phone's own Wi-Fi settings, then`
        + ` reload this page`;
      return;
    }
    setTimeout(poll, 1000);
  };
  setTimeout(poll, 1000);
});

let syncing = false;
async function syncNow() {
  if (syncing) return;
  const base = logServerUrl();
  const unsynced = await FieldLog.unsyncedCount().catch(() => 0);
  const statusEl = document.getElementById('logStatus');
  if (!base) {
    statusEl.textContent = `log: ${unsynced} saved on phone · no server set`;
    return;
  }
  syncing = true;
  try {
    // A short-timeout health check first: this runs every 15 s (see
    // setInterval below) for as long as the page is open, and a server
    // that is merely unreachable right now (wrong network, robot on its
    // own AP, laptop asleep) must fail that fast and quiet rather than
    // hang a fetch every cycle.
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 2000);
    await fetch(`${base}/health`, {signal: ctrl.signal, cache: 'no-store'});
    clearTimeout(timer);

    const batch = await FieldLog.unsyncedBatch(500);
    if (batch.length === 0) {
      statusEl.textContent = `log: 0 saved on phone · synced to ${base}`;
      return;
    }
    const records = batch.map(r => ({
      ts: r.ts, state: r.state, actor: r.actor, vx: r.vx, wz: r.wz,
      gravity: r.gravity, home_err: r.home_err, err: r.err,
      servoIds: r.servoIds, pulse: r.pulse, target: r.target,
    }));
    const resp = await fetch(`${base}/upload`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({robot: ROBOT, session: batch[0].session, records}),
    });
    if (resp.ok) {
      await FieldLog.markSynced(batch.map(r => r.id));
      const left = await FieldLog.unsyncedCount().catch(() => 0);
      statusEl.textContent = `log: ${left} saved on phone · `
        + `+${records.length} sent to ${base}`;
    } else {
      statusEl.textContent = `log: ${unsynced} saved on phone · `
        + `${base} rejected upload (${resp.status})`;
    }
  } catch (e) {
    statusEl.textContent = `log: ${unsynced} saved on phone · `
      + `${base} unreachable`;
  } finally {
    syncing = false;
  }
}
setInterval(syncNow, 15000);
syncNow();

// Deliberately NOT like rise/sit (mode 3/4), which fire once and spring back
// to run after 400 ms: there is nothing here to know a motion has finished
// (see Rcb4Link::callMotion's own comment), so this stays in mode 5 -- and
// off writing any servo target at all -- until run or hold is pressed on
// purpose. That is the manual recovery the device's own State::MOTION
// expects, not a bug in this button.
document.getElementById('motionGo').addEventListener('click', () => {
  motionNumber = +motionSel.value;
  mode = 5;
  dragging = null; kx = 0; ky = 0; draw();
});

// Pinned to the viewport (see #estop's CSS) and needs no coordinates from
// the stick's own layout, so it works even when that layout has gone wrong.
document.getElementById('estop').addEventListener('click', () => {
  dragging = null;
  mode = 2;  // hold
  kx = 0; ky = 0;
  setFromKnob();
});

// The same 9 byte frame the USB client sends, hex in a query string. A GET
// keeps the device's parser to a string compare and a hex decode.
function frame() {
  const b = new Uint8Array(9), d = new DataView(b.buffer);
  // Bit 7 selects the attitude source: clear = the IMU, set = the loaded
  // policy's stance constant. Default is the constant, which is what every
  // successful run of this robot has used.
  b[0] = 0xA5; b[1] = useImu ? mode : (mode | 0x80);
  if (mode === 5) {
    // Request::MOTION: vx is a motion-table slot number here, not a
    // velocity, so it is sent raw rather than scaled by 1000 like an m/s.
    d.setInt16(2, motionNumber, true);
    d.setInt16(4, 0, true);
    d.setInt16(6, 0, true);
  } else {
    d.setInt16(2, Math.round(vx * 1000), true);
    d.setInt16(4, 0, true);
    d.setInt16(6, Math.round(wz * 1000), true);
  }
  let sum = 0; for (let i = 0; i < 8; i++) sum += b[i];
  b[8] = sum & 0xFF;
  return Array.from(b, x => x.toString(16).padStart(2, '0')).join('');
}

const STATES = {0:'idle', 1:'running', 2:'holding', 3:'FAULT', 4:'homing',
                5:'transition', 6:'motion'};
// Filled in by loadInfo() -- this robot's own lib/policy/policy.cpp
// kActors[] names, in order, so a build with only "walk" (most of these
// robots have no getup policy at all) is not shown a nonexistent "getup".
let ACTORS = [];
let inflight = false;
async function tick() {
  if (inflight) return;   // one request at a time; the device serves one
  inflight = true;
  try {
    const r = await fetch('/c?f=' + frame(), {cache:'no-store'});
    const t = await r.json();
    if (!t.live) {
      // The page is served by a task that runs whatever the AtomS3 is doing,
      // so it loads even when nothing is listening to it. Saying so beats
      // looking broken.
      document.getElementById('state').textContent =
        'not in POLICY mode — hold the AtomS3 button until it says POLICY';
      return;
    }
    for (const b of document.querySelectorAll('button[data-mode]')) {
      b.setAttribute('aria-pressed', +b.dataset.mode === t.state ? 'true' : 'false');
    }
    document.getElementById('state').textContent =
      `${STATES[t.state] ?? '?'} · ${ACTORS[t.actor & 0x7f] ?? '?'}`
      + `${t.actor & 0x80 ? '*' : ''}`
      + ` · vx ${t.vx.toFixed(2)} wz ${t.wz.toFixed(2)}`
      + ` · ${t.loop_ms.toFixed(0)} ms · err ${t.err}`;
    document.getElementById('motionGo').setAttribute(
      'aria-pressed', t.state === 6 ? 'true' : 'false');
    // Published unconditionally by the device (see net::Telemetry::gravity),
    // so this updates in every state, not only while running -- level is
    // [0,0,-1]. Approximate on purpose: this is a glance-at indicator, not
    // an instrument, so the box tilting the right way matters more than the
    // exact angle.
    if (Array.isArray(t.gravity)) {
      const [gx, gy, gz] = t.gravity;
      const pitchDeg = Math.atan2(gx, -gz) * 180 / Math.PI;
      const rollDeg = Math.atan2(gy, -gz) * 180 / Math.PI;
      document.getElementById('tiltbox').style.transform =
        `rotateX(${(-pitchDeg).toFixed(1)}deg) rotateZ(${rollDeg.toFixed(1)}deg)`;
      document.getElementById('atttext').textContent =
        `roll ${rollDeg.toFixed(1)}° pitch ${pitchDeg.toFixed(1)}°`;
      // The raw vector, to one more decimal than roll/pitch need: while
      // "attitude: fixed" (the default -- see the button below) this is a
      // constant, [0,0,-1]-ish, and does NOT move when the robot is tilted.
      // That is not a bug in this display; it is what "fixed" means. Toggle
      // to "attitude: IMU" to see it track the real sensor instead.
      document.getElementById('attraw').textContent =
        `g ${gx.toFixed(3)} ${gy.toFixed(3)} ${gz.toFixed(3)}`;
    }
    // After the display update, not before: a throw above (a field this
    // build's /c happens not to send) must not silently stop logging, but
    // logging stale/partial t must not happen either -- see FieldLog's own
    // throttling for why this is safe to call at the full 10 Hz tick rate.
    FieldLog.record(t);
  } catch (e) {
    document.getElementById('state').textContent = 'no answer from the robot';
  } finally {
    inflight = false;
  }
}
// 10 Hz, which is what the device's failsafe expects: it stands after 0.5 s
// of silence and frees the servos after 3.
setInterval(tick, 100);

// A page that loses focus cannot see a pointer come back up, and a robot left
// walking because someone switched apps is the failure worth guarding.
// Zeroing the stick alone is not enough on a robot whose walk policy was
// never trained to stand still (VX_MIN > 0, from /info): the device clamps
// UP to VX_MIN rather than stopping, so a blur used to leave it walking at
// the slowest trained speed instead of standing. Only actually leaving
// "run" (mode 2, hold) stops it.
addEventListener('blur', () => {
  dragging = null; mode = 2; kx = 0; ky = 0; setFromKnob();
});

// Keeps the stick sized to whatever #stickwrap actually has room for --
// see its own comment in <style> -- rather than trusting the 280x280 it
// happened to load at. ResizeObserver catches what a bare 'resize' listener
// would not: the on-screen keyboard, a browser chrome bar hiding/showing, or
// this very box changing size for a reason that was never a window resize.
new ResizeObserver(sizeStick).observe(document.getElementById('stickwrap'));
sizeStick();

// Two more ways a browser can zoom in over this page's own objection
// (user-scalable=no is not honoured everywhere): Safari's pinch gesture, and
// a double-tap. Either one is exactly how the stick previously ended up
// oversized with the mode buttons scrolled out of reach.
addEventListener('gesturestart', e => e.preventDefault());
let lastTouchEndMs = 0;
addEventListener('touchend', e => {
  const now = Date.now();
  if (now - lastTouchEndMs < 350) e.preventDefault();
  lastTouchEndMs = now;
}, {passive: false});
</script></body></html>)HTML";
