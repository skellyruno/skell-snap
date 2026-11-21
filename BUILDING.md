# Windows x64 VST3 build and verification

The Windows VST3 workflow runs for pushes to `main`, pull requests targeting `main`, and manual dispatch. Only superseded pull-request runs may be cancelled; `main` and manual builds are protected.

## Source pipeline

CI reconstructs the 61,943-byte base source archive from sixteen pinned fragments and verifies its SHA-256 before extraction. The updated UI/DSP overlay is also reconstructed from eight pinned fragments under `source-overlay/parts/`; CI verifies its exact 16,741-byte length and SHA-256 (`ab0e2aa6a575334e491ccf86e5623b416f0e804645d148598a9de890ddcc5a7f`) before unpacking it. It restores shared artwork/fonts, overlays the updated editor/processor/dial/rune/test files, and runs idempotent patch checks. The latency check verifies the original five-choice selector is restored with Zero first and 2.5 ms as default; there is no separate `zeroLatency` Boolean.

## Regression suite

Portable CMake/CTest includes DSP accuracy and block-size tests, the 80-case byte-for-byte Classic-vs-legacy comparison, Crystal YIN correlation equivalence across four difficult signals and four block sizes, rune motion/Retune brightness/audio pulse mapping, glyph-catalogue tests, and UI frame-pacer tests.

The Windows job then configures JUCE 8.0.12, builds **SkellSnap_VST3 only**, validates moduleinfo/class IDs/AMD64 PE and SHA-256 provenance, then runs pluginval strictness 5.

## Latency and Retune controls

The Latency menu is restored to the original five choices: Zero first, then 1 / 2.5 / 5 / 10 ms, with 2.5 ms default. The AudioParameterChoice normalized value maps to the five-entry DSP lookup table; no separate `zeroLatency` Boolean is used.

The Retune dial reads 100 at the left down to 0 at the right. Clockwise movement lowers stored milliseconds, and 0 ms is hardest / instant correction. The unchanged tuning engine receives the same original 0–500 ms Retune value. The JUCE rotary angles are offset to align JUCE's top-origin coordinates with the artwork's 3-o'clock-origin arc.

The rune layer is subdued at 100 and brightens toward 0. A smoothed RMS envelope drives a separate pulse; pitch-lock confidence affects orbit movement only, not the audio-brightness pulse.

## Rune feedback

The editor receives a smoothed RMS activity envelope through an atomic value. Runes move faster at baseline and accelerate modestly with signal level; glow/flare opacity also increases slightly with audio activity and pitch lock. The audio callback only performs bounded RMS measurement and envelope smoothing—no UI work or dynamic allocation.

## Install ZIP

After pluginval, CI creates `Skell-Snap-Windows-Installer.zip` containing the complete `Skell-Snap.vst3` bundle, `Install-Skell-Snap.bat`, and `README-INSTALL.txt`. A ZIP inspection step verifies the module, moduleinfo, installer and instructions are present before upload. The raw VST3 bundle is also uploaded separately.

A green workflow verifies automated tests, Windows compilation, package structure and pluginval. It does not replace FL Studio scan/load, preset/state recall, automation playback, real-vocal A/B listening, or PC-specific latency/CPU/glitch measurements.
