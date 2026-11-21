param(
    [string]$SourceRoot,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

# The submitted Crystal snapshot had inserted Zero at index 0 of the legacy
# latency choice. Repair that before building: keep the original four choices
# and their order/default; append a separate zeroLatency boolean after mode.
$oldLayout = @'
    l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "latency", 1 }, "Latency",
          StringArray{ "0 ms (Zero - hard tune)", "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 2));
    l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "mode", 1 }, "Algorithm",
          StringArray{ "Classic", "Crystal" }, 0));
    return l;
'@

$newLayout = @'
    // Keep the original four-choice APVTS parameter byte-for-byte compatible:
    // old state and normalized automation values must retain their meanings.
    // Zero is a new bool appended after mode; the UI combines it into a fifth
    // menu item without inserting or reordering the old choices.
    l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "latency", 1 }, "Latency",
          StringArray{ "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 1));
    l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "mode", 1 }, "Algorithm",
          StringArray{ "Classic", "Crystal" }, 0));
    l.add(std::make_unique<AudioParameterBool>(ParameterID{ "zeroLatency", 1 }, "Zero Latency (Hard Tune)", false));
    return l;
'@

function Set-CompatibleLatencyLayout {
    param([Parameter(Mandatory)][string]$ProcessorPath)

    if (-not (Test-Path -LiteralPath $ProcessorPath -PathType Leaf)) {
        throw "Skell-Snap processor source is missing: $ProcessorPath"
    }

    $content = [System.IO.File]::ReadAllText($ProcessorPath).Replace("`r`n", "`n")
    if ($content.Contains($oldLayout)) {
        $content = $content.Replace($oldLayout, $newLayout)
        [System.IO.File]::WriteAllText($ProcessorPath, $content, [System.Text.UTF8Encoding]::new($false))
        $result = 'patched'
    }
    elseif ($content.Contains($newLayout)) {
        $result = 'already-patched'
    }
    else {
        throw 'Could not prove the legacy four-choice latency order and appended zeroLatency layout. Refusing an ambiguous rewrite.'
    }

    $latencyId = $content.IndexOf('ParameterID{ "latency", 1 }', [StringComparison]::Ordinal)
    $modeId = $content.IndexOf('ParameterID{ "mode", 1 }', [StringComparison]::Ordinal)
    $zeroId = $content.IndexOf('ParameterID{ "zeroLatency", 1 }', [StringComparison]::Ordinal)
    if ($latencyId -lt 0 -or $modeId -le $latencyId -or $zeroId -le $modeId) {
        throw 'Parameter compatibility check failed: latency, mode and zeroLatency are not in the required order.'
    }

    if (-not $content.Contains('StringArray{ "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }')) {
        throw 'Parameter compatibility check failed: original latency choices/order were not retained.'
    }
    if (-not $content.Contains('pZeroLatency = apvts.getRawParameterValue("zeroLatency")')) {
        throw 'Parameter compatibility check failed: zeroLatency is not bound from APVTS.'
    }

    return $result
}

function Invoke-SelfTest {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skell-snap-latency-layout-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $processor = Join-Path $tempRoot 'PluginProcessor.cpp'
    try {
        $fixture = @'
void createLayout() {
    l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "latency", 1 }, "Latency",
          StringArray{ "0 ms (Zero - hard tune)", "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 2));
    l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "mode", 1 }, "Algorithm",
          StringArray{ "Classic", "Crystal" }, 0));
    return l;
}
pZeroLatency = apvts.getRawParameterValue("zeroLatency");
'@
        [System.IO.File]::WriteAllText($processor, $fixture.Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))

        $first = Set-CompatibleLatencyLayout -ProcessorPath $processor
        if ($first -ne 'patched') { throw "Expected first pass to patch; got '$first'." }
        $second = Set-CompatibleLatencyLayout -ProcessorPath $processor
        if ($second -ne 'already-patched') { throw "Expected second pass to be idempotent; got '$second'." }

        $final = [System.IO.File]::ReadAllText($processor)
        if ($final.Contains('"0 ms (Zero - hard tune)", "1 ms')) {
            throw 'Self-test failed: Zero was still inserted into the legacy latency choice.'
        }
        if (-not $final.Contains('AudioParameterBool>(ParameterID{ "zeroLatency", 1 }')) {
            throw 'Self-test failed: appended zeroLatency boolean was not created.'
        }
        Write-Host 'PASS: original latency choices/order are preserved and Zero is appended after mode as a bool.'
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($SelfTest) {
    Invoke-SelfTest
    return
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    throw 'SourceRoot is required unless -SelfTest is specified.'
}

$processorPath = Join-Path $SourceRoot 'Source/PluginProcessor.cpp'
$result = Set-CompatibleLatencyLayout -ProcessorPath $processorPath
Write-Host "Skell-Snap latency parameter compatibility: $result"
