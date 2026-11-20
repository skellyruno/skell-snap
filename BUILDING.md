# Windows VST3 build

The repository's `Windows VST3` GitHub Actions workflow runs on pushes to `main` and via manual dispatch.

It reconstructs the source snapshot from `source-archive/skell-snap.zip`, runs the portable DSP test executable, configures the JUCE 8.0.12 plugin project, and builds the Release VST3 for Windows x64.

The workflow checks that the VST3 bundle contains a Windows x64 binary before uploading the `Skell-Snap-windows-latest` artifact.

A green workflow run confirms the compile and packaging checks. It does not replace loading the plugin in FL Studio or performing real-time audio tests on Windows.
