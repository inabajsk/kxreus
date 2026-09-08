#pragma once

#include <pgmspace.h>

/// The page a phone gets when it scans the QR code on the LCD.
///
/// In PROGMEM, so it costs flash and not the ~30 KiB of heap that is all the
/// Wi-Fi stack leaves. Self-contained for the same reason a QR code is used
/// at all: the phone has just joined a lab network and may have no route to
/// the internet, so nothing here may be fetched from one -- no framework, no
/// font, no icon.
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
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>KXR hand</title>
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
  #stickwrap { flex:1 1 auto; display:flex; align-items:center;
               justify-content:center; }
  #stick { touch-action:none; }
  .modes { display:grid; grid-template-columns:repeat(3,1fr); gap:8px;
           padding:14px; max-width:460px; margin:0 auto; width:100%;
           box-sizing:border-box; flex:0 0 auto; }
  button { font:600 16px/1 inherit; padding:20px 0; border:0; border-radius:12px;
           background:#2b2f36; color:#eee; }
  button:active { filter:brightness(1.4); }
  button[aria-pressed="true"] { outline:2px solid #eee; }
  .run { background:#1e5b32; } .hold { background:#6b5a10; }
  .free { background:#6b2020; }
  .rise { background:#1e4a6b; } .sit { background:#4a2b6b; }
  #imu { font-size:14px; }
</style></head><body>
<header>
  <h1>KXR hand</h1>
  <div id="state">connecting…</div>
</header>
<div id="stickwrap"><canvas id="stick" width="280" height="280"></canvas></div>
<div class="modes">
  <button class="run"  data-mode="1">run</button>
  <button class="hold" data-mode="2">hold</button>
  <button class="free" data-mode="0">free</button>
  <button class="rise" data-mode="3">rise</button>
  <button class="sit"  data-mode="4">sit</button>
  <button id="imu">attitude</button>
</div>
<script>
// Matches tools/policy_teleop.py, which matches what the actor was trained
// with. Forward and back are not symmetric.
const VX_MAX = 0.5, VX_MIN = -0.3, WZ_MAX = 1.0;
// Below this the command counts as standing, and the device stops the gait
// clock. Leaving a dead zone around the centre means a resting thumb does not
// creep.
const DEAD = 0.12;

let mode = 0, vx = 0, wz = 0, useImu = false;

const cv = document.getElementById('stick');
const ctx = cv.getContext('2d');
const R = cv.width / 2, KNOB = 34, REACH = R - KNOB - 6;
let kx = 0, ky = 0, dragging = null;

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
  if (mag < DEAD) { vx = 0; wz = 0; }
  else {
    // Up is forward. Forward and back have different limits, so each half of
    // the axis is scaled to its own.
    const fwd = -ny;
    vx = fwd >= 0 ? fwd * VX_MAX : fwd * -VX_MIN;
    // Left is a positive yaw rate, matching the a/d of the terminal client.
    wz = -nx * WZ_MAX;
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
    // Spring to centre. A stick that stays where it was left is a hand that
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

// The same 9 byte frame the USB client sends, hex in a query string. A GET
// keeps the device's parser to a string compare and a hex decode.
function frame() {
  const b = new Uint8Array(9), d = new DataView(b.buffer);
  // Bit 7 selects the attitude source: clear = the IMU, set = the loaded
  // policy's stance constant. Default is the constant, which is what every
  // successful run of this robot has used.
  b[0] = 0xA5; b[1] = useImu ? mode : (mode | 0x80);
  d.setInt16(2, Math.round(vx * 1000), true);
  d.setInt16(4, 0, true);
  d.setInt16(6, Math.round(wz * 1000), true);
  let sum = 0; for (let i = 0; i < 8; i++) sum += b[i];
  b[8] = sum & 0xFF;
  return Array.from(b, x => x.toString(16).padStart(2, '0')).join('');
}

const STATES = {0:'idle', 1:'running', 2:'holding', 3:'FAULT', 4:'homing',
                5:'transition'};
const ACTORS = ['crawl','omni','walk','legs','rise','sit'];
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
  } catch (e) {
    document.getElementById('state').textContent = 'no answer from the hand';
  } finally {
    inflight = false;
  }
}
// 10 Hz, which is what the device's failsafe expects: it stands after 0.5 s
// of silence and frees the servos after 3.
setInterval(tick, 100);

// A page that loses focus cannot see a pointer come back up, and a hand left
// walking because someone switched apps is the failure worth guarding.
addEventListener('blur', () => { dragging = null; kx = 0; ky = 0; setFromKnob(); });
draw();
</script></body></html>)HTML";
