# Windows x64 VST3 build and verification

The Windows VST3 workflow runs for pushes to `main`, pull requests targeting `main`, and manual dispatch. Only superseded pull-request runs may be cancelled; `main` and manual builds are protected.

## Source pipeline

CI reconstructs the 61,943-byte base source archive from sixteen pinned fragments and verifies its SHA-256 before extraction. It restores shared artwork/fonts, overlays the updated editor/processor/dial/rune/test files, and runs idempotent patch checks. The compatibility patch verifies the original four `latency` choices remain in their original order; the new Zero choice is backed by an appended `zeroLatency` boolean after `mode`.

## Regression suite

Portable CMake/CTest includes DSP accuracy and block-size tests, the 80-case byte-for-byte Classic-vs-legacy comparison, rune motion/audio activity and glyph-catalogue tests, and UI frame-pacer tests. The Retune scale helper verifies both endpoints and the original default conversion.

The Windows job then configures JUCE 8.0.12, builds **SkellSnap_VST3 only**, validates moduleinfo/class IDs/AMD64 PE and SHA-256 provenance, then runs pluginval strictness 5.

## Preset/automation compatibility

The existing `retune` parameter is still 0–500 ms, step 0.1 ms, skew 0.4 and default 25 ms, with its original ID and version hint. Its dial presentation now reads 0–100 in reverse: 0 maps to 0 ms (hard) and 100 maps to 500 ms (slow); the original 25 ms default displays as 5. The slider attachment still uses the unchanged APVTS parameter, so existing presets and automation remain valid.

The existing `latency` APVTS parameter also keeps its exact four choices/order/default. Zero is added as a separate boolean after `mode`, so its UI menu can show a fifth choice without shifting saved normalized choice values.

## Rune feedback

The editor receives a smoothed RMS activity envelope through an atomic value. Runes move faster at baseline and accelerate modestly with signal level; glow/flare opacity also increases slightly with audio activity and pitch lock. The audio callback only performs bounded RMS measurement and envelope smoothing—no UI work or dynamic allocation.

## Install ZIP

After pluginval, CI creates `Skell-Snap-Windows-Installer.zip` containing the complete `Skell-Snap.vst3` bundle, `Install-Skell-Snap.bat`, and `README-INSTALL.txt`. A ZIP inspection step verifies the module, moduleinfo, installer and instructions are present before upload. The raw VST3 bundle is also uploaded separately.

A green workflow verifies automated tests, Windows compilation, package structure and pluginval. It does not replace FL Studio scan/load, preset/state recall, automation playback, real-vocal A/B listening, or PC-specific latency/CPU/glitch measurements.
