param(
    [string]$SourceRoot,
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function Repair-ChoiceIndexMapping {
    param([Parameter(Mandatory)][string]$ProcessorContent)

    $wrongPattern = 'p\.latencyMs\s*=\s*kLat\[juce::jlimit\(0,\s*4,\s*int\(std::lround\(pLat->load\(std::memory_order_relaxed\)\s*\*\s*4\.0f\)\)\)\];'
    $correct = 'p.latencyMs = kLat[juce::jlimit(0, 4, int(pLat->load(std::memory_order_relaxed) + 0.5f))];'
    $patched = [regex]::Replace($ProcessorContent, $wrongPattern, $correct)

    if ($patched -eq $ProcessorContent -and
        -not ([regex]::Replace($ProcessorContent, '\s+', ' ')).Contains($correct)) {
        throw 'Latency mapping must round the raw AudioParameterChoice index; normalized 0..1 conversion is incorrect.'
    }
    return $patched
}

function Assert-OriginalLatencySelector {
    param([string]$ProcessorContent, [string]$HeaderContent)

    $processor = [regex]::Replace($ProcessorContent, '\s+', ' ')
    $header = [regex]::Replace($HeaderContent, '\s+', ' ')
    $choices = 'StringArray{ "0 ms (Zero - hard tune)", "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 2));'
    $rawIndex = 'p.latencyMs = kLat[juce::jlimit(0, 4, int(pLat->load(std::memory_order_relaxed) + 0.5f))];'

    if (-not $processor.Contains($choices)) { throw 'Expected original five choices, Zero first and default index 2.' }
    if ($processor.Contains('zeroLatency') -or $processor.Contains('pZeroLatency')) { throw 'Zero must not be stored in a separate Boolean.' }
    if (-not $processor.Contains('ParameterID{ "latency", 1 }')) { throw 'Original latency parameter ID missing.' }
    if (-not $header.Contains('static constexpr double kLat[5] = { 0.0, 1.0, 2.5, 5.0, 10.0 };')) { throw 'Five-value DSP latency table missing or reordered.' }
    if (-not $processor.Contains($rawIndex)) { throw 'AudioParameterChoice must map its raw 0..4 index directly into kLat.' }
    if ($processor.Contains('* 4.0f')) { throw 'A normalized-value multiplier must not be applied to the raw choice index.' }
    if (-not $processor.Contains('ParameterID{ "retune", 1 }, "Retune Speed", NormalisableRange<float>(0.0f, 500.0f, 0.1f, 0.4f), 25.0f')) { throw 'Retune milliseconds contract changed.' }
}

function Invoke-SelfTest {
    $processor = @'
l.add(std::make_unique<AudioParameterFloat>(ParameterID{ "retune", 1 }, "Retune Speed",
    NormalisableRange<float>(0.0f, 500.0f, 0.1f, 0.4f), 25.0f));
l.add(std::make_unique<AudioParameterChoice>(ParameterID{ "latency", 1 }, "Latency",
    StringArray{ "0 ms (Zero - hard tune)", "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 2));
p.latencyMs = kLat[juce::jlimit(0, 4, int(std::lround(pLat->load(std::memory_order_relaxed) * 4.0f)))];
'@
    $header = 'static constexpr double kLat[5] = { 0.0, 1.0, 2.5, 5.0, 10.0 };'
    $processor = Repair-ChoiceIndexMapping -ProcessorContent $processor
    Assert-OriginalLatencySelector -ProcessorContent $processor -HeaderContent $header

    $lookup = @(0.0, 1.0, 2.5, 5.0, 10.0)
    $expected = @(0.0, 1.0, 2.5, 5.0, 10.0)
    for ($i = 0; $i -lt 5; $i++) {
        $rawChoiceValue = [double]$i
        $rawChoiceIndex = [Math]::Min(4, [Math]::Max(0, [int][Math]::Floor($rawChoiceValue + 0.5)))
        if ([double]$lookup[$rawChoiceIndex] -ne [double]$expected[$i]) {
            throw "Raw choice-index latency lookup failed at index $i."
        }
    }
    $split = $processor + ' zeroLatency pZeroLatency'
    $rejected = $false
    try { Assert-OriginalLatencySelector -ProcessorContent $split -HeaderContent $header }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'Self-test failed: split Zero Boolean state was not rejected.' }

    Write-Host 'PASS: Zero-first selector, 2.5 ms default and raw choice-index map (0, 1, 2.5, 5, 10 ms) validated.'
}

if ($SelfTest) { Invoke-SelfTest; return }
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { throw 'SourceRoot is required unless -SelfTest is specified.' }

$processorPath = Join-Path $SourceRoot 'Source/PluginProcessor.cpp'
$headerPath = Join-Path $SourceRoot 'Source/PluginProcessor.h'
if (-not (Test-Path $processorPath) -or -not (Test-Path $headerPath)) { throw 'Processor source/header missing.' }

$processorContent = [IO.File]::ReadAllText($processorPath)
$repairedContent = Repair-ChoiceIndexMapping -ProcessorContent $processorContent
if ($repairedContent -ne $processorContent) {
    [IO.File]::WriteAllText($processorPath, $repairedContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Corrected the latency mapping to use the raw AudioParameterChoice index.'
}
Assert-OriginalLatencySelector -ProcessorContent $repairedContent -HeaderContent ([IO.File]::ReadAllText($headerPath))
Write-Host 'PASS: original five-choice Zero-first selector and raw DSP index mapping verified.'
