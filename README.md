# SKELL SNAP

Low-latency pitch correction, shipped as a **Windows x64 JUCE 8 VST3**. The release builds VST3 only; no Standalone target is included. The DSP remains JUCE-free in `Source/dsp/SnapCore.h`. The interface uses Skell brushed-metal artwork, neon accents and the animated rune field.

## Algorithms

`Classic` remains the default and retains the original NSDF/MPM detector, raw input path and correction-smoothing behaviour. Its archived pre-Crystal implementation remains in the source archive as a sample-by-sample regression reference.

`Crystal` is the newer YIN/CMNDF detector path, with a 60 Hz high-pass plus raw-signal fallback, higher analysis rate, onset confirmation and output-pitch tracking. Compare it with Classic on the same vocal; it is not claimed to be universally better for every singer.

## Latency selector

The Latency menu is restored to the original five-choice selector: **0 ms (Zero - hard tune), 1 ms (Ultra), 2.5 ms (Low), 5 ms (Bass / Baritone), 10 ms (Stable)**. The default remains **2.5 ms**. Zero requests 0 host PDC samples; the pitch engine still has its internal pass-through delay, so end-to-end audio delay is not mathematically zero.

## Retune dial and rune feedback

The physical dial runs **100 on the left down to 0 on the right**. Turning clockwise lowers the displayed Retune value; **0 is the hardest / instant correction**, and 100 is the slowest / smoothest glide. The original 0–500 ms Retune parameter, tuning algorithm and pitch-shift path remain unchanged; only the knob's physical mapping is inverted. The original 25 ms default still displays as 5.

The rune field is subdued at 100 and brightens as Retune approaches 0. Incoming audio drives a separate smoothed, softly pulsing brightness lift; stronger input produces a stronger pulse. Audio activity is measured before processing and passed to the UI via an atomic envelope without UI work or allocation on the audio thread.

## Windows installer ZIP

The CI release artifact named **Skell-Snap-Windows-Installer** is the easy-install ZIP. Extract the whole ZIP, then double-click `Install-Skell-Snap.bat`. It copies the complete `Skell-Snap.vst3` folder to the current user's VST3 folder:

`%LOCALAPPDATA%\Programs\Common Files\VST3`

Close and reopen the DAW, then rescan VST3 plug-ins. The ZIP contains the actual bundle, the installer batch file and `README-INSTALL.txt`. The separate `Skell-Snap-Windows-x64-VST3` artifact is the raw plug-in bundle, not the guided installer ZIP.

## Verification

The portable suite includes DSP correctness, 80-combination Classic compatibility, rune motion/audio-activity, glyph catalogue and UI frame-pacer tests. The Windows workflow reconstructs and SHA-256 verifies the base source archive and a separate eight-fragment UI overlay (16,741 bytes; SHA-256 `ab0e2aa6a575334e491ccf86e5623b416f0e804645d148598a9de890ddcc5a7f`). It restores the shared artwork/font assets, checks the latency compatibility patch, builds JUCE 8.0.12 Windows x64 VST3 only, validates the bundle/AMD64 module, runs pluginval strictness 5, and creates + inspects the installer ZIP contents.

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
