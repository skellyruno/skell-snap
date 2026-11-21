# SKELL SNAP

Low-latency pitch correction, shipped as a **Windows x64 JUCE 8 VST3**. No Standalone target is built. The DSP is JUCE-free in `Source/dsp/SnapCore.h`; the plug-in uses the Skell brushed-metal / neon-green UI and shared rune artwork.

## Algorithms

`Classic` remains the default. It retains the original NSDF/MPM detector, raw input path, and correction-smoothing behaviour. A side-by-side regression test compares it with the archived pre-Crystal engine, sample-for-sample and state-for-state.

`Crystal` is the newer YIN/CMNDF detector path. It adds a 60 Hz high-pass with raw-signal fallback, twice the analysis rate, tighter tracking with a full-range retry, onset confirmation, YIN-scaled voicing thresholds, and lead compensation that is suppressed around note changes and invalid frames. It is intended as the tighter alternative; compare it against Classic on the same source audio.

## Zero-latency host mode

The Latency menu appends `0 ms (Zero - hard tune)` after the original 1 / 2.5 / 5 / 10 ms choices. It tells the host to compensate **0 samples**; unshifted audio still has an internal 10-sample pass-through delay at 48 kHz (0.21 ms). Pitch-shifted audio can sit later by part of an input period: the local synthetic test measured about 5.2 ms at 110 Hz with a 25-cent correction, about 2.4–2.7 ms at 220 Hz, and around 0.7–0.8 ms at 880 Hz. The host is not compensating for this shifted-content delay. Use it for hard-tune/low-PDC workflows, not as a guarantee of zero end-to-end delay; the 5 ms setting remains preferable for deep voices.

**Preset compatibility:** the existing `latency` parameter ID, old choice order, and default are unchanged. Zero appears as the fifth item in the UI menu but is stored in a new `zeroLatency` boolean appended after the `mode` parameter. The original four-choice `latency` parameter is unchanged, so existing latency presets and automation retain their meanings. All other existing IDs, version hints, ranges, steps, skew values and defaults remain unchanged. The `mode` choice stays appended after the original parameters and defaults to Classic.

## UI

The main RETUNE control, scale/key selectors, twelve note tablets, AMOUNT, HUMANIZE, A4 REF, MIN PITCH, cents/voice meters and live pitch readout remain. The top bar now exposes Classic/Crystal and latency; the latency status distinguishes host PDC from the audio engine's actual pass-through delay when Zero is selected. Shared assets and Montserrat font/licence are stored in `Assets/` and restored into the source archive during CI.

## Verification

The current portable suite passes five CTest targets, including the 80-combination Classic parity check. The expanded vowel benchmark (`SnapBench --zero`) exercises formant-rich synthetic /a/, /i/ and /u/ voices, vibrato, note steps, breath noise and CPU for Classic/Crystal at normal and zero latency. Its measurements are documented in `docs/classic-compatibility.md` and are synthetic characterisation—not recorded vocals.

The Windows workflow reconstructs and SHA-256 verifies the source archive, restores assets, tests the program-name patch and package verifier, builds/runs the portable DSP and UI tests, configures JUCE 8.0.12, builds **Windows x64 VST3 only**, validates the bundle/AMD64 module, and runs pluginval strictness 5. The workflow artifact is retained for 30 days.

The source archive is stored as **sixteen binary fragments** under `source-archive/parts/`. Its exact 61,943-byte length and SHA-256 are verified by the Windows workflow. Artwork/font files remain in root `Assets/` and are restored into the extracted source tree by CI.

## Build locally

Portable tests and benchmark (no JUCE required):

```sh
cmake -S . -B build-core -DSNAP_BUILD_PLUGIN=OFF -DSNAP_BUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build-core --parallel
ctest --test-dir build-core --output-on-failure
./build-core/SnapCoreTests --zero
./build-core/SnapCoreTests --crystal --zero
./build-core/SnapCoreTests --compare
./build-core/SnapBench --zero
```

Windows x64 VST3 (JUCE 8.0.12 is fetched by CMake unless `JUCE_PATH` is supplied):

```sh
cmake -S . -B build -DSNAP_BUILD_PLUGIN=ON -DSNAP_BUILD_TESTS=OFF
cmake --build build --target SkellSnap_VST3 --config Release --parallel
```

## Acceptance boundary

Automated DSP/UI tests, Windows compilation, VST3 packaging and pluginval do not replace installing/scanning/loading the plug-in in FL Studio, checking state recall and automation, listening to real-vocal A/B examples, or measuring callback CPU, glitches and host/device latency. Those host acceptance checks remain outstanding.
