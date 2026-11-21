param(
    [string]$SourceRoot,
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function Assert-OriginalLatencySelector {
    param([string]$ProcessorContent, [string]$HeaderContent)
    $processor = [regex]::Replace($ProcessorContent, '\s+', ' ')
    $header = [regex]::Replace($HeaderContent, '\s+', ' ')
    $choices = 'StringArray{ "0 ms (Zero - hard tune)", "1 ms (Ultra)", "2.5 ms (Low)", "5 ms (Bass / Baritone)", "10 ms (Stable)" }, 2));'
    if (-not $processor.Contains($choices)) { throw 'Expected original five choices, Zero first and default index 2.' }
    if ($processor.Contains('zeroLatency') -or $processor.Contains('pZeroLatency')) { throw 'Zero must not be stored in a separate Boolean.' }
    if (-not $processor.Contains('ParameterID{ "latency", 1 }')) { throw 'Original latency parameter ID missing.' }
    if (-not $header.Contains('static constexpr double kLat[5] = { 0.0, 1.0, 2.5, 5.0, 10.0 };')) { throw 'Five-value DSP latency table missing or reordered.' }
    if (-not $processor.Contains('kLat[juce::jlimit(0, 4, int(std::lround(pLat->load(std::memory_order_relaxed) * 4.0f)))]')) { throw 'AudioParameterChoice normalized index mapping is incorrect.' }
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
    Assert-OriginalLatencySelector -ProcessorContent $processor -HeaderContent $header
    $bad = $processor.Replace('0 ms (Zero - hard tune)", ', '') + ' zeroLatency pZeroLatency'
    $rejected = $false
    try { Assert-OriginalLatencySelector -ProcessorContent $bad -HeaderContent $header }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'Self-test failed: split latency state was not rejected.' }
    Write-Host 'PASS: Zero-first five-choice selector and 2.5 ms default validated.'
}

if ($SelfTest) { Invoke-SelfTest; return }
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { throw 'SourceRoot is required unless -SelfTest is specified.' }
$processorPath = Join-Path $SourceRoot 'Source/PluginProcessor.cpp'
$headerPath = Join-Path $SourceRoot 'Source/PluginProcessor.h'
if (-not (Test-Path $processorPath) -or -not (Test-Path $headerPath)) { throw 'Processor source/header missing.' }
Assert-OriginalLatencySelector -ProcessorContent ([IO.File]::ReadAllText($processorPath)) -HeaderContent ([IO.File]::ReadAllText($headerPath))
Write-Host 'PASS: original latency selector restored; no separate Zero Boolean remains.'
