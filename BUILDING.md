# Windows x64 VST3 build and verification

The **Windows VST3** workflow runs on pushes to `main`, pull requests targeting `main`, and manual dispatch. It protects `main` and manual builds from cancellation; only superseded PR runs may be cancelled.

## Source reconstruction

The sixteen binary fragments under `source-archive/parts/` are concatenated by `scripts/reassemble-source-archive.ps1`. The script validates the exact archive size and SHA-256 before extraction. CI restores the shared artwork/font files from root `Assets/` and runs the tested default-program-name patch and self-test.

## Portable regression suite

Configure with `SNAP_BUILD_PLUGIN=OFF` and `SNAP_BUILD_TESTS=ON`. CTest includes:

- `SnapCoreTests`: DSP accuracy, block-size independence, transitions, robustness and pass-through delay for the original latency choices plus Zero;
- `SnapClassicCompatTests`: bit-identical Classic comparison against the archived pre-Crystal engine (80 sample-rate/block-size/profile combinations with live changes);
- rune motion, glyph catalogue and UI frame-pacer tests.

`SnapBench` is built as a separate characterization utility. Run `SnapBench --zero` to compare formant-rich synthetic vowel, vibrato, note-step, breath-noise and CPU metrics across Classic/Crystal at normal and zero latency. It is not a pass/fail listening test and its synthetic results are not a substitute for real-vocal A/B work.

Run locally:

```sh
cmake -S . -B build-core -DSNAP_BUILD_PLUGIN=OFF -DSNAP_BUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build-core --parallel
ctest --test-dir build-core --output-on-failure
./build-core/SnapCoreTests --zero
./build-core/SnapCoreTests --crystal --zero
./build-core/SnapCoreTests --compare
./build-core/SnapBench --zero
```

## Preset and parameter compatibility

The existing APVTS parameter IDs, version hints, ranges, numeric steps, skew values, defaults and choice ordering remain intact. The existing four-choice `latency` APVTS parameter is kept exactly intact. The UI's `0 ms (Zero - hard tune)` entry is backed by a new `zeroLatency` boolean appended after the `mode` parameter; expanding the original choice parameter would change normalized state/automation mapping. Classic remains the default algorithm. See `docs/classic-compatibility.md` for the complete parameter contract and DSP results.

## Windows plugin verification

After the portable tests pass, CI configures JUCE 8.0.12 and builds the `SkellSnap_VST3` target explicitly (**VST3 only; no Standalone target**). `scripts/verify-vst3-bundle.ps1` checks bundle structure, JSON metadata, non-empty/unique class IDs, Windows x64 module placement, AMD64 PE signature and SHA-256 provenance for the source archive, build overlay and compiled module. The workflow then runs pluginval strictness level 5 and uploads the Windows x64 VST3 artifact for 30 days.

## Acceptance boundary

A green workflow confirms automated DSP/Classic/UI tests, Windows compilation, package verification and pluginval. It does not replace installation and scan/load in FL Studio, state recall and automation checks, real-vocal A/B listening, or measured callback CPU, glitches and host/device latency.
