param(
    [string]$SourceRoot,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

function Assert-CompatibleLatencyLayout {
    param([Parameter(Mandatory)][string]$Content)

    $content = $Content.Replace("`r`n", "`n")
    $legacyChoiceOrder = 'StringArray{ "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 1));'
    if (-not $content.Contains($legacyChoiceOrder)) {
        throw 'Compatibility check failed: the original four latency choices/default/order must remain exactly unchanged.'
    }

    $latencyId = $content.IndexOf('ParameterID{ "latency", 1 }', [StringComparison]::Ordinal)
    $modeId = $content.IndexOf('ParameterID{ "mode", 1 }', [StringComparison]::Ordinal)
    $zeroBool = $content.IndexOf('AudioParameterBool>(ParameterID{ "zeroLatency", 1 }', [StringComparison]::Ordinal)
    if ($latencyId -lt 0 -or $modeId -le $latencyId -or $zeroBool -le $modeId) {
        throw 'Compatibility check failed: zeroLatency must be a new bool appended after the existing mode choice.'
    }

    if (-not $content.Contains('pZeroLatency = apvts.getRawParameterValue("zeroLatency")')) {
        throw 'Compatibility check failed: the appended zeroLatency parameter is not bound from APVTS.'
    }
    if (-not $content.Contains('pZeroLatency->load(std::memory_order_relaxed) > 0.5f')) {
        throw 'Compatibility check failed: DSP does not read the zeroLatency state parameter.'
    }

    # Normalize source whitespace before comparing so CRLF/LF and indentation
    # cannot create false negatives in the compatibility guard.
    $normalized = [regex]::Replace($content, '\s+', ' ')
    $retuneContract = 'ParameterID{ "retune", 1 }, "Retune Speed", NormalisableRange<float>(0.0f, 500.0f, 0.1f, 0.4f), 25.0f'
    if (-not $normalized.Contains($retuneContract)) {
        throw 'Compatibility check failed: Retune APVTS ID/range/step/skew/default changed.'
    }

    return $true
}

function Invoke-SelfTest {
    $good = @'
l.add(std::make_unique<AudioParameterFloat>(ParameterID{ "retune", 1 }, "Retune Speed",
          NormalisableRange<float>(0.0f, 500.0f, 0.1f, 0.4f), 25.0f));
l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "latency", 1 }, "Latency",
          StringArray{ "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 1));
l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "mode", 1 }, "Algorithm",
          StringArray{ "Classic", "Crystal" }, 0));
l.add(std::make_unique<AudioParameterBool>(ParameterID{ "zeroLatency", 1 }, "Zero Latency (Hard Tune)", false));
pZeroLatency = apvts.getRawParameterValue("zeroLatency");
p.latencyMs = pZeroLatency->load(std::memory_order_relaxed) > 0.5f ? 0.0 : kLat[1];
'@
    Assert-CompatibleLatencyLayout -Content $good | Out-Null

    $bad = $good.Replace(
        'StringArray{ "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 1));',
        'StringArray{ "0 ms (Zero - hard tune)", "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 2));'
    ).Replace('l.add(std::make_unique<AudioParameterBool>(ParameterID{ "zeroLatency", 1 }, "Zero Latency (Hard Tune)", false));', '')
    $rejected = $false
    try { Assert-CompatibleLatencyLayout -Content $bad | Out-Null }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'Self-test failed: an inserted Zero choice was not rejected.' }

    Write-Host 'PASS: original latency mapping + Retune contract preserved; Zero is appended as a separate bool.'
}

if ($SelfTest) {
    Invoke-SelfTest
    return
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    throw 'SourceRoot is required unless -SelfTest is specified.'
}
$processorPath = Join-Path $SourceRoot 'Source/PluginProcessor.cpp'
if (-not (Test-Path -LiteralPath $processorPath -PathType Leaf)) {
    throw "Skell-Snap processor source is missing: $processorPath"
}
$content = [System.IO.File]::ReadAllText($processorPath)
Assert-CompatibleLatencyLayout -Content $content | Out-Null
Write-Host 'PASS: legacy latency values and Retune APVTS contract are preserved.'
