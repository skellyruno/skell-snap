# SKELL SNAP

Low-latency pitch correction, shipped as a **Windows x64 JUCE 8 VST3**. The release builds VST3 only; no Standalone target is included. The DSP remains JUCE-free in `Source/dsp/SnapCore.h`. The interface uses Skell brushed-metal artwork, neon accents and the animated rune field.

## Algorithms

`Classic` remains the default and retains the original NSDF/MPM detector, raw input path and correction-smoothing behaviour. Its archived pre-Crystal implementation remains in the source archive as a sample-by-sample regression reference.

`Crystal` is the newer YIN/CMNDF detector path, with a 60 Hz high-pass plus raw-signal fallback, higher analysis rate, onset confirmation and output-pitch tracking. Compare it with Classic on the same vocal; it is not claimed to be universally better for every singer.

## Retune control: reversed 100 to 0

The main RETUNE dial now runs **100 → 0** in the hardening direction: **0 is the hardest / instant correction**, while 100 is the slowest / smoothest glide. The display is a 0–100 presentation scale derived from the original 0–500 ms value (5 ms per display point); the existing 25 ms default therefore displays as 5.

This is a UI-only reversal. The APVTS parameter ID `retune`, version hint, 0–500 ms range, 0.1 ms step, 0.4 skew and 25 ms default are unchanged. Host automation still writes the original parameter and old presets retain their values.

## Faster, audio-reactive runes

The rune bands orbit faster at rest and accelerate further with incoming audio. A smoothed RMS envelope controls the speed and a restrained increase in rune/flare brightness; pitch-lock confidence contributes a little additional energy. The detector/audio path does not allocate for this feedback and the UI only reads an atomic activity value. The effect is intentionally subtle rather than a full-brightness pulse.

## Zero-latency host mode

The Latency menu combines the original 1 / 2.5 / 5 / 10 ms choices with a fifth `0 ms (Zero - hard tune)` item. Zero requests 0 host PDC samples, but does not mean mathematically zero end-to-end audio delay: the engine retains its internal pass-through delay and pitch-shifted content can sit later by part of an input period. The 5 ms choice remains preferable for deep voices.

**Preset compatibility:** the original `latency` APVTS parameter ID, four choice values, order and default are kept exactly intact. Zero is stored in a new `zeroLatency` boolean appended after `mode`; it is not inserted into the legacy choice list. The other parameter IDs, version hints, ranges, steps, skew values and defaults remain unchanged. `Classic` remains the default algorithm.

## Windows installer ZIP

The CI release artifact named **Skell-Snap-Windows-Installer** is the easy-install ZIP. Extract the whole ZIP, then double-click `Install-Skell-Snap.bat`. It copies the complete `Skell-Snap.vst3` folder to the current user's VST3 folder:

`%LOCALAPPDATA%\Programs\Common Files\VST3`

Close and reopen the DAW, then rescan VST3 plug-ins. The ZIP contains the actual bundle, the installer batch file and `README-INSTALL.txt`. The separate `Skell-Snap-Windows-x64-VST3` artifact is the raw plug-in bundle, not the guided installer ZIP.

## Verification

The portable suite includes DSP correctness, 80-combination Classic compatibility, rune motion/audio-activity, glyph catalogue and UI frame-pacer tests. The Windows workflow reconstructs and SHA-256 verifies the base source archive, applies the shared artwork/font assets and source overlay, checks the latency compatibility patch, builds JUCE 8.0.12 Windows x64 VST3 only, validates the bundle/AMD64 module, runs pluginval strictness 5, and creates + inspects the installer ZIP contents.

Synthetic benchmarks characterize detector and timing behaviour; they are not recorded-vocal A/B listening tests. Automated CI also does not replace installing/scanning/loading in FL Studio, state recall and automation checks, listening to real vocals, or measuring callback CPU, glitches and device latency. Those host checks remain outstanding.

## Build locally

Portable tests:

```sh
cmake -S . -B build-core -DSNAP_BUILD_PLUGIN=OFF -DSNAP_BUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build-core --parallel
ctest --test-dir build-core --output-on-failure
```

Windows x64 VST3 (JUCE 8.0.12 is fetched by CMake unless `JUCE_PATH` is supplied):

```sh
cmake -S . -B build -DSNAP_BUILD_PLUGIN=ON -DSNAP_BUILD_TESTS=OFF
cmake --build build --target SkellSnap_VST3 --config Release --parallel
```
