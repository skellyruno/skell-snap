# Skell-Snap

Low-latency pitch correction plugin, built as a Windows x64 JUCE VST3.

## DSP compatibility

Classic mode is regression-tested against the archived pre-Crystal engine. The test builds the archived legacy
`SnapCore.h` and current Classic implementation side by side, then compares every output sample, telemetry field,
shifter delay/ratio state and reported latency.

**Result: Classic is bit-identical across 80 exercised combinations** covering 44.1, 48, 96 and 192 kHz sample
rates, five block sizes, four parameter profiles and live parameter changes. This is exact parity for these test
cases, not a mathematical proof for every compiler, architecture or possible input.

All existing parameter IDs, version hints, choice order, ranges, steps, skew values and defaults are preserved.
The new Algorithm choice is appended after the existing parameters and defaults to Classic.

See [Classic compatibility report](docs/classic-compatibility.md) for the tested matrix and the detailed parameter
comparison. The report and regression fixture ship with the source archive.

## Windows build and verification

The **Windows VST3** workflow reconstructs and SHA-256 verifies the checked-in source archive fragments, restores the
shared artwork/font bundle, applies the narrow tested default-program-name overlay, and runs the complete portable
DSP/UI regression suite. It then builds the Release Windows x64 VST3 target only (no Standalone), validates the
bundle structure, metadata, class IDs and AMD64 PE module, runs pluginval at strictness level 5 and publishes the
`Skell-Snap-Windows-x64-VST3` workflow artifact for 30 days.

The source archive is stored as eight binary fragments under `source-archive/parts/`; the exact reconstructed
archive SHA-256 is checked in CI. Artwork and the Montserrat font/licence are stored under `Assets/` and retained
byte-for-byte from the existing Skell-Necromancer asset set.

## Acceptance boundary

Portable tests and Windows CI verify the algorithm, UI regression suite, compilation, packaging and pluginval.
Final host acceptance still requires installing/scanning/loading the VST3 in FL Studio, checking state recall and
automation, and listening to real-vocal A/B examples while measuring callback CPU, glitches and host/device latency.
