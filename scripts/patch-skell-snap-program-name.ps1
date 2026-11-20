[CmdletBinding()]
param(
    [string]$SourceRoot,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

$oldProgramName = 'const juce::String getProgramName(int) override { return {}; }'
$newProgramName = 'const juce::String getProgramName(int) override { return "Default"; }'

function Set-SkellSnapDefaultProgramName {
    param([Parameter(Mandatory)][string]$HeaderPath)

    if (-not (Test-Path -LiteralPath $HeaderPath -PathType Leaf)) {
        throw "Skell-Snap processor header is missing: $HeaderPath"
    }

    $content = [System.IO.File]::ReadAllText($HeaderPath)
    $oldCount = [regex]::Matches($content, [regex]::Escape($oldProgramName)).Count
    $newCount = [regex]::Matches($content, [regex]::Escape($newProgramName)).Count

    if ($oldCount -eq 1 -and $newCount -eq 0) {
        $updated = $content.Replace($oldProgramName, $newProgramName)
        [System.IO.File]::WriteAllText(
            $HeaderPath,
            $updated,
            [System.Text.UTF8Encoding]::new($false)
        )
        return 'patched'
    }

    if ($oldCount -eq 0 -and $newCount -eq 1) {
        return 'already-patched'
    }

    throw "Expected exactly one unnamed Skell-Snap program declaration or one already-patched declaration; found old=$oldCount, named=$newCount."
}

function Invoke-SelfTest {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skell-snap-program-name-' + [guid]::NewGuid().ToString('N'))
    $sourceDir = Join-Path $tempRoot 'Source'
    New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
    $headerPath = Join-Path $sourceDir 'PluginProcessor.h'

    try {
        $fixture = 'class Fixture {' + [Environment]::NewLine + '    ' + $oldProgramName + [Environment]::NewLine + '};' + [Environment]::NewLine
        [System.IO.File]::WriteAllText(
            $headerPath,
            $fixture,
            [System.Text.UTF8Encoding]::new($false)
        )

        $first = Set-SkellSnapDefaultProgramName -HeaderPath $headerPath
        if ($first -ne 'patched') {
            throw "Self-test expected first pass to patch; got '$first'."
        }

        $afterFirst = [System.IO.File]::ReadAllText($headerPath)
        if (-not $afterFirst.Contains($newProgramName) -or $afterFirst.Contains($oldProgramName)) {
            throw 'Self-test did not replace the unnamed program declaration.'
        }

        $second = Set-SkellSnapDefaultProgramName -HeaderPath $headerPath
        if ($second -ne 'already-patched') {
            throw "Self-test expected second pass to be idempotent; got '$second'."
        }

        Write-Host 'PASS: unnamed default program is given a stable name; repeated patching is idempotent.'
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

$processorHeader = Join-Path $SourceRoot 'Source/PluginProcessor.h'
$result = Set-SkellSnapDefaultProgramName -HeaderPath $processorHeader
Write-Host "Skell-Snap default program name patch: $result"
