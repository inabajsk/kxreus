// Timing rig for the on-device control loop. Not firmware.
//
// The question this answers is whether the policy can run HERE rather than on
// the PC, and that comes down to three numbers against a 25 ms budget (40 Hz):
// how long a forward pass takes, how long reading 35 servo records takes, and
// how long a servo command takes. The first is pure compute; the other two are
// round trips to the board that the PC currently pays USB latency on top of.
//
// Nothing is energised: the only servo command sent is 0x8000, which frees
// every servo. Build and run with `pio run -e bench -t upload -t monitor`.

#include <Arduino.h>
#include <M5Unified.h>
#include <policy.h>
#include <rcb4_link.h>

namespace {

Rcb4Link rcb4_link;

struct Stats {
    uint32_t n = 0;
    uint32_t fails = 0;
    uint32_t min_us = UINT32_MAX;
    uint32_t max_us = 0;
    uint64_t total_us = 0;

    void add(uint32_t us) {
        n++;
        total_us += us;
        if (us < min_us) min_us = us;
        if (us > max_us) max_us = us;
    }
    float meanMs() const { return n ? total_us / 1000.0f / n : 0.0f; }
};

void report(const char* label, const Stats& s) {
    Serial.printf("%-22s mean %7.3f ms  min %7.3f  max %7.3f  n=%lu  fail=%lu\n",
                  label, s.meanMs(), s.min_us / 1000.0f, s.max_us / 1000.0f,
                  static_cast<unsigned long>(s.n),
                  static_cast<unsigned long>(s.fails));
}

/// The 19 servos of the hand, ascending. Kept here rather than taken from the
/// policy header so the bench can run before the control loop exists.
const uint8_t kIds[19] = {1,  2,  4,  6,  9,  11, 13, 15, 17, 19,
                          20, 23, 25, 26, 27, 28, 30, 33, 34};

}  // namespace

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(0);
    M5.Display.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Display.setTextSize(2);
    M5.Display.println("BENCH");

    Serial.begin(115200);
    rcb4_link.begin();
    // The host has to attach before anything is worth printing, and there is
    // no way to ask. Ten seconds is the wait, once.
    const uint32_t deadline = millis() + 10000;
    while (!Serial && millis() < deadline) delay(10);
    delay(500);

    Serial.println();
    Serial.println("=== AtomS3 on-device control loop bench ===");
    Serial.printf("obs %u -> act %u\n", static_cast<unsigned>(policy::obsDim()),
                  static_cast<unsigned>(policy::actDim()));
    Serial.printf("board answered version query: %s\n",
                  rcb4_link.probeBoard(1000) ? "yes" : "NO");
    Serial.printf("weights in RAM: %s\n\n", policy::begin() ? "yes" : "no");

    // 1. Inference. Fed with changing observations so the branch in the ELU
    // is exercised both ways and nothing can be hoisted out of the loop.
    float obs[POLICY_OBS_DIM];
    float action[POLICY_ACT_DIM];
    Stats infer;
    for (int trial = 0; trial < 200; trial++) {
        for (size_t i = 0; i < POLICY_OBS_DIM; i++) {
            obs[i] = sinf(0.1f * (trial + 1) * (i + 1));
        }
        const uint32_t t0 = micros();
        policy::run(obs, action);
        infer.add(micros() - t0);
    }
    report("policy forward", infer);
    Serial.printf("  (last action[0] = %+.4f, |max| = %.4f)\n", action[0], [&] {
        float m = 0;
        for (size_t i = 0; i < POLICY_ACT_DIM; i++) m = max(m, fabsf(action[i]));
        return m;
    }());

    // 2. Reading the servo table: five 126 byte round trips.
    uint16_t pulses[Rcb4Link::SERVO_SLOTS];
    Stats read;
    for (int trial = 0; trial < 50; trial++) {
        const uint32_t t0 = micros();
        const bool ok = rcb4_link.readServoPulses(pulses);
        read.add(micros() - t0);
        if (!ok) read.fails++;
    }
    report("read 35 servo records", read);
    Serial.print("  pulses of the 19:");
    for (uint8_t i = 0; i < 19; i++) Serial.printf(" %u", pulses[kIds[i]]);
    Serial.println();

    // 2b. The same 19 positions, asked for one at a time. 38 bytes against
    // the 630 the whole table costs, at the price of 19 round trips instead
    // of 5 -- which the numbers below say is a trade worth making.
    uint16_t just19[19];
    Stats read19;
    for (int trial = 0; trial < 50; trial++) {
        const uint32_t t0 = micros();
        const bool ok = rcb4_link.readServoPulsesFor(kIds, just19, 19);
        read19.add(micros() - t0);
        if (!ok) read19.fails++;
    }
    report("read 19 positions", read19);
    Serial.print("  agrees with the table read:");
    bool same = true;
    for (uint8_t i = 0; i < 19; i++) {
        // Not expected to be identical -- the hand settles between reads --
        // but a mapping error would show up as hundreds of pulses.
        const int diff = static_cast<int>(just19[i]) - pulses[kIds[i]];
        if (diff > 60 || diff < -60) same = false;
    }
    Serial.println(same ? " yes (within 60 pulses = 2 deg)" : " NO");

    // 3. One servo command. 0x8000 frees, so this measures the write path
    // without energising anything.
    uint16_t free_all[19];
    for (uint8_t i = 0; i < 19; i++) free_all[i] = 0x8000;
    Stats write;
    for (int trial = 0; trial < 50; trial++) {
        const uint32_t t0 = micros();
        const bool ok = rcb4_link.writeServoPulses(kIds, free_all, 19, 6);
        write.add(micros() - t0);
        if (!ok) write.fails++;
    }
    report("servo command (free)", write);

    // 4. What a read actually costs, against its size. This separates the
    // board's fixed per-transaction cost from its per-byte cost, which is
    // what decides whether the servo table is better read in few large
    // chunks or many small ones. There is no USB in this path at all, so
    // whatever shows up here is the RCB-4's own.
    Serial.println("\nread cost vs size (board only, no USB):");
    static const uint8_t kSizes[] = {2, 8, 16, 32, 64, 96, 126};
    uint8_t scratch[126];
    for (uint8_t si = 0; si < sizeof(kSizes); si++) {
        Stats s;
        for (int trial = 0; trial < 40; trial++) {
            const uint32_t t0 = micros();
            const bool ok = rcb4_link.readRam(Rcb4Link::SERVO_RAM_ADDRESS,
                                              kSizes[si], scratch);
            s.add(micros() - t0);
            if (!ok) s.fails++;
        }
        Serial.printf("  %3u B: mean %6.3f ms  min %6.3f  fail=%lu"
                      "   -> %5.1f us/byte marginal\n",
                      kSizes[si], s.meanMs(), s.min_us / 1000.0f,
                      static_cast<unsigned long>(s.fails),
                      s.meanMs() * 1000.0f / kSizes[si]);
    }

    const float step = read19.meanMs() + infer.meanMs() + write.meanMs();
    Serial.printf("\nwhole-table read would instead give %.2f ms\n",
                  read.meanMs() + infer.meanMs() + write.meanMs());
    const float budget = 1000.0f / POLICY_CONTROL_HZ;
    Serial.printf("\ncontrol step = %.2f ms against a %.1f ms budget (%.0f Hz)"
                  " -> %s\n",
                  step, budget, POLICY_CONTROL_HZ,
                  step < budget ? "FITS" : "DOES NOT FIT");

    M5.Display.clear();
    M5.Display.setCursor(0, 0);
    M5.Display.printf("BENCH\n\ninf %.1fms\nrd  %.1fms\nwr  %.1fms\n\n%.1f/%.0fms",
                      infer.meanMs(), read.meanMs(), write.meanMs(), step,
                      budget);
}

void loop() { delay(1000); }
