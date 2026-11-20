# Skell-Snap

Low-latency pitch correction plugin from the supplied source archive. The Windows GitHub Actions workflow reconstructs the source tree from `source-archive/skell-snap.zip`, runs the portable DSP tests, builds the JUCE VST3 with JUCE 8.0.12, verifies that the Windows VST3 binary exists, and uploads the bundle as the **Skell-Snap-windows-latest** artifact.

## Build result

The portable DSP suite has been run locally on Linux and passed. The JUCE plugin and Windows VST3 still require the Windows Actions build to confirm; a successful CMake configure or compile is not assumed in advance.

## Windows build

Open the **Actions → Windows VST3** workflow and run it with **Run workflow**, or push a commit to `main`. On success, download the `Skell-Snap-windows-latest` artifact from the workflow run.

The original project source is preserved byte-for-byte in `source-archive/skell-snap.zip`.
