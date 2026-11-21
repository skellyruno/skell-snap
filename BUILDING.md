# Windows x64 VST3 build

The **Windows VST3** workflow runs on pushes to `main`, pull requests targeting `main`, and manual dispatch.
Superseded PR builds may be cancelled; main-branch and manual builds are protected.

## Source reconstruction

The eight binary fragments under `source-archive/parts/` are concatenated by
`scripts/reassemble-source-archive.ps1`. The script checks the exact 50,306-byte size and SHA-256 before the
archive is extracted. CI restores the shared artwork/font files from `Assets/` into the source tree and runs the
existing default-program-name patch and its self-test.

## Classic parity gate

The portable CMake test target `SnapClassicCompatTests` compiles the archived pre-Crystal `SnapCore.h` alongside
the current Classic implementation. It requires bit-identical output samples, all telemetry fields, shifter delay,
ratio and reported latency over 80 combinations: 4 sample rates, 5 block sizes, 4 parameter profiles and changes
during processing. See `docs/classic-compatibility.md` for the full measurement details.

Run locally:

```sh
cmake -S . -B build-core -DSNAP_BUILD_PLUGIN=OFF -DSNAP_BUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build-core --parallel
ctest --test-dir build-core --output-on-failure
```

## Windows plugin verification

After CTest passes, CI configures JUCE 8.0.12 and builds the `SkellSnap_VST3` target explicitly (no Standalone).
`scripts/verify-vst3-bundle.ps1` checks bundle structure, JSON metadata, non-empty/unique class IDs, the Windows
x64 module, PE AMD64 signature and SHA-256 provenance for source archive, build overlay and compiled module.
The workflow then validates the bundle with pluginval strictness level 5 and uploads the Windows x64 VST3 artifact
for 30 days.

## Acceptance boundary

A green workflow confirms the automated parity/UI/DSP suite, Windows compilation, package verification and pluginval.
It does not replace installation and scan/load in FL Studio, state recall and automation checks, real-vocal A/B
listening, or measured callback CPU, glitches and host/device latency.
