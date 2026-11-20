# Windows VST3 build

The repository's **Windows VST3** GitHub Actions workflow runs on pushes to `main`, pull requests targeting `main`, and manual dispatch.

It reconstructs the source tree from `source-archive/skell-snap.zip`, runs the portable DSP test executable, configures the JUCE 8.0.12 project, and builds the Release VST3 for Windows x64.

## Release verification

After the build, `scripts/verify-vst3-bundle.ps1` checks the VST3 bundle structure, strict JSON metadata, non-empty and unique class IDs, the single Windows x64 module, and the PE AMD64 machine signature. It writes a release manifest and SHA-256 checksum file beside the bundle.

The verifier's `-SelfTest` mode exercises valid output and rejects duplicate class IDs, duplicate bundles, and non-AMD64 PE files. The workflow also self-tests and applies a minimal patch to the extracted `Source/PluginProcessor.h` so the one default program reports the non-empty name `Default`; the archived source ZIP is not overwritten.

## Artifact visibility

The repository is public, so the workflow intentionally withholds the installable VST3 artifact. GitHub Actions artifacts are not a private preview channel for a public repository. The build and verification jobs still run; `Skell-Snap-windows-latest` is uploaded only when the repository is private.

## Owner acceptance

A green workflow confirms CI compilation and package structure, not FL Studio acceptance. Install, host scan/load, state recall, automation, real-vocal A/B, callback CPU, glitches, and host/device latency remain separate owner-side gates.
