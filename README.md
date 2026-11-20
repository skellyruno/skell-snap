# Skell-Snap

Low-latency pitch correction plugin from the supplied source archive.

The original project snapshot is preserved byte-for-byte in `source-archive/skell-snap.zip`. The Windows workflow extracts that snapshot, runs its portable DSP tests, builds the JUCE 8.0.12 VST3 for Windows x64, and verifies the resulting bundle before considering it an artifact candidate.

## Windows VST3 verification

The **Windows VST3** workflow runs on:

- Pushes to `main`
- Pull requests targeting `main`
- Manual dispatch from the Actions tab

The release verifier checks:

- Exactly one top-level `Skell-Snap.vst3` bundle
- A parseable `Contents/Resources/moduleinfo.json` with a name, version, and at least one class
- Unique VST3 class IDs
- Exactly one VST3 module under `Contents/x86_64-win`
- A valid Windows PE header with AMD64 machine type
- SHA-256 provenance for the module, plus `release-manifest.json` and `SHA256SUMS`

The verifier also has a Windows PowerShell self-test covering valid bundles, duplicate class IDs, duplicate bundles, and wrong-architecture PE files.

## Preview artifact policy

This repository is currently public. GitHub Actions artifacts from a public repository are not a private delivery channel, so the workflow **withholds the installable VST3 artifact while the repository is public**. The DSP tests, Windows build, and bundle verification still run.

The `Skell-Snap-windows-latest` artifact is uploaded only when the repository is private. No public release or installable download is created by this workflow.

## Acceptance boundary

A successful Windows workflow verifies the CI build and packaging checks only. It does not replace:

- Installing the VST3 on the owner's Windows machine
- Loading and scanning it in FL Studio
- Testing state recall and automation
- Real vocal A/B listening
- Measuring callback CPU, glitches, and actual host/device latency

Do not treat a workflow start, CMake configure, or compile alone as release acceptance.
