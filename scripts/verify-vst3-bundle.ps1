[CmdletBinding()]
param(
    [string]$Vst3Root,
    [string]$ExpectedBundleName = 'Skell-Snap.vst3',
    [string]$CommitSha = $env:GITHUB_SHA,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Assert-WindowsX64Pe {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        if ($stream.Length -lt 70) {
            throw "VST3 module is too small to be a valid PE image: $Path"
        }

        $dosHeader = [byte[]]::new(64)
        if ($stream.Read($dosHeader, 0, $dosHeader.Length) -ne $dosHeader.Length) {
            throw "Could not read the PE DOS header: $Path"
        }
        if ($dosHeader[0] -ne 0x4D -or $dosHeader[1] -ne 0x5A) {
            throw "VST3 module does not have an MZ header: $Path"
        }

        $peOffset = [System.BitConverter]::ToInt32($dosHeader, 0x3C)
        if ($peOffset -lt 64 -or $peOffset -gt ($stream.Length - 6)) {
            throw "VST3 module has an invalid PE header offset: $Path"
        }

        $stream.Position = $peOffset
        $signature = [byte[]]::new(4)
        if ($stream.Read($signature, 0, 4) -ne 4) {
            throw "Could not read the PE signature: $Path"
        }
        $expectedSignature = [string][char]0x50 + [char]0x45 + [char]0 + [char]0
        if ([System.Text.Encoding]::ASCII.GetString($signature) -ne $expectedSignature) {
            throw "VST3 module has an invalid PE signature: $Path"
        }

        $machineBytes = [byte[]]::new(2)
        if ($stream.Read($machineBytes, 0, 2) -ne 2) {
            throw "Could not read the PE machine type: $Path"
        }
        $machine = [System.BitConverter]::ToUInt16($machineBytes, 0)
        if ($machine -ne 0x8664) {
            throw ("Expected AMD64 PE machine 0x8664, got 0x{0:X4}: {1}" -f $machine, $Path)
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-VerifyVst3Bundle {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ExpectedName,
        [string]$SourceCommit
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "VST3 output directory is missing: $Root"
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $bundles = @(Get-ChildItem -LiteralPath $resolvedRoot -Directory -Filter '*.vst3')
    if ($bundles.Count -ne 1) {
        throw "Expected exactly one top-level VST3 bundle; found $($bundles.Count)"
    }

    $bundle = $bundles[0]
    if ($bundle.Name -ne $ExpectedName) {
        throw "Expected bundle '$ExpectedName'; found '$($bundle.Name)'"
    }

    $moduleInfoPath = Join-Path $bundle.FullName 'Contents/Resources/moduleinfo.json'
    if (-not (Test-Path -LiteralPath $moduleInfoPath -PathType Leaf)) {
        throw "VST3 moduleinfo.json is missing: $moduleInfoPath"
    }

    try {
        $moduleInfo = Get-Content -LiteralPath $moduleInfoPath -Raw |
            ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        throw "VST3 moduleinfo.json is invalid JSON: $($_.Exception.Message)"
    }

    $moduleName = [string]$moduleInfo['Name']
    $version = [string]$moduleInfo['Version']
    if ([string]::IsNullOrWhiteSpace($moduleName)) {
        throw 'VST3 moduleinfo.json has no Name.'
    }
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw 'VST3 moduleinfo.json has no Version.'
    }

    $rawClasses = $moduleInfo['Classes']
    if ($null -eq $rawClasses) {
        throw 'VST3 moduleinfo.json has no Classes array.'
    }
    $classes = @($rawClasses)
    if ($classes.Count -lt 1) {
        throw 'VST3 moduleinfo.json contains no plug-in classes.'
    }

    $classIds = @()
    foreach ($class in $classes) {
        if ($null -eq $class -or $null -eq $class['CID']) {
            throw 'A VST3 class is missing its CID.'
        }
        $cid = [string]$class['CID']
        if ([string]::IsNullOrWhiteSpace($cid)) {
            throw 'A VST3 class has an empty CID.'
        }
        $classIds += $cid
    }

    $duplicateIds = @(
        $classIds |
            Group-Object -Property { $_.ToUpperInvariant() } |
            Where-Object { $_.Count -gt 1 }
    )
    if ($duplicateIds.Count -gt 0) {
        $duplicates = ($duplicateIds | ForEach-Object { $_.Name }) -join ', '
        throw "VST3 moduleinfo.json contains duplicate class IDs: $duplicates"
    }

    $moduleFiles = @(Get-ChildItem -LiteralPath $bundle.FullName -Recurse -File -Filter '*.vst3')
    if ($moduleFiles.Count -ne 1) {
        throw "Expected exactly one VST3 module binary inside the bundle; found $($moduleFiles.Count)"
    }

    $binary = $moduleFiles[0]
    if ($binary.FullName -notmatch '[\\/]+x86_64-win[\\/]') {
        throw "VST3 module is not under Contents/x86_64-win: $($binary.FullName)"
    }
    if ($binary.Length -le 0) {
        throw "VST3 module binary is empty: $($binary.FullName)"
    }
    Assert-WindowsX64Pe -Path $binary.FullName

    $relativeBinaryPath = [System.IO.Path]::GetRelativePath($resolvedRoot, $binary.FullName).Replace('\', '/')
    $binaryHash = (Get-FileHash -LiteralPath $binary.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $resolvedCommit = if ([string]::IsNullOrWhiteSpace($SourceCommit)) { 'unknown' } else { $SourceCommit }

    $manifest = [ordered]@{
        schemaVersion = 1
        product = 'Skell-Snap'
        moduleName = $moduleName
        version = $version
        bundleName = $bundle.Name
        platform = 'windows'
        architecture = 'x86_64'
        sourceCommit = $resolvedCommit
        modulePath = $relativeBinaryPath
        moduleSizeBytes = [long]$binary.Length
        moduleSha256 = $binaryHash
        classCount = $classIds.Count
        classIds = @($classIds)
        createdUtc = [System.DateTime]::UtcNow.ToString('o')
    }

    $manifestPath = Join-Path $resolvedRoot 'release-manifest.json'
    $checksumsPath = Join-Path $resolvedRoot 'SHA256SUMS'
    $manifestJson = $manifest | ConvertTo-Json -Depth 8
    Write-Utf8NoBom -Path $manifestPath -Content ($manifestJson + [Environment]::NewLine)
    Write-Utf8NoBom -Path $checksumsPath -Content ($binaryHash + '  ' + $relativeBinaryPath + [Environment]::NewLine)

    Write-Host "Verified bundle: $($bundle.FullName)"
    Write-Host "Module: $moduleName $version"
    Write-Host "Classes: $($classIds.Count); AMD64 PE; SHA-256: $binaryHash"
    Write-Host "Manifest: $manifestPath"
    return $manifest
}

function New-TestBundle {
    param(
        [Parameter(Mandatory)][string]$Root,
        [UInt16]$Machine = 0x8664,
        [switch]$DuplicateClassId
    )

    $bundle = Join-Path $Root 'Skell-Snap.vst3'
    $resourceDir = Join-Path $bundle 'Contents/Resources'
    $binaryDir = Join-Path $bundle 'Contents/x86_64-win'
    New-Item -ItemType Directory -Path $resourceDir -Force | Out-Null
    New-Item -ItemType Directory -Path $binaryDir -Force | Out-Null

    $classes = @(
        [ordered]@{
            CID = '00112233445566778899AABBCCDDEEFF'
            Name = 'Skell-Snap'
            Category = 'Audio Module Class'
        }
    )
    if ($DuplicateClassId) {
        $classes += [ordered]@{
            CID = '00112233445566778899AABBCCDDEEFF'
            Name = 'Duplicate'
            Category = 'Audio Module Class'
        }
    }

    $moduleInfo = [ordered]@{
        Name = 'Skell-Snap'
        Version = '0.1.0'
        Classes = $classes
    }
    Write-Utf8NoBom -Path (Join-Path $resourceDir 'moduleinfo.json') -Content (($moduleInfo | ConvertTo-Json -Depth 8) + [Environment]::NewLine)

    $pe = [byte[]]::new(128)
    $pe[0] = 0x4D
    $pe[1] = 0x5A
    [System.BitConverter]::GetBytes([int]64).CopyTo($pe, 0x3C)
    $pe[64] = 0x50
    $pe[65] = 0x45
    $pe[66] = 0
    $pe[67] = 0
    [System.BitConverter]::GetBytes($Machine).CopyTo($pe, 68)
    [System.IO.File]::WriteAllBytes((Join-Path $binaryDir 'Skell-Snap.vst3'), $pe)
}

function Assert-Rejected {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Scenario
    )
    $rejected = $false
    try {
        & $Action | Out-Null
    }
    catch {
        $rejected = $true
    }
    if (-not $rejected) {
        throw "Verifier self-test failed: $Scenario was not rejected."
    }
}

function Invoke-SelfTest {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skell-snap-vst3-verifier-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    try {
        $validRoot = Join-Path $tempRoot 'valid'
        New-Item -ItemType Directory -Path $validRoot -Force | Out-Null
        New-TestBundle -Root $validRoot
        $manifest = Invoke-VerifyVst3Bundle -Root $validRoot -ExpectedName 'Skell-Snap.vst3' -SourceCommit 'self-test'
        if ($manifest.moduleSizeBytes -ne 128) {
            throw 'Verifier self-test failed: valid AMD64 fixture size was not recorded.'
        }
        if (-not (Test-Path -LiteralPath (Join-Path $validRoot 'release-manifest.json'))) {
            throw 'Verifier self-test failed: release manifest was not written.'
        }
        if (-not (Test-Path -LiteralPath (Join-Path $validRoot 'SHA256SUMS'))) {
            throw 'Verifier self-test failed: SHA256SUMS was not written.'
        }

        $duplicateRoot = Join-Path $tempRoot 'duplicate-class'
        New-Item -ItemType Directory -Path $duplicateRoot -Force | Out-Null
        New-TestBundle -Root $duplicateRoot -DuplicateClassId
        Assert-Rejected -Scenario 'duplicate class IDs' -Action {
            Invoke-VerifyVst3Bundle -Root $duplicateRoot -ExpectedName 'Skell-Snap.vst3' -SourceCommit 'self-test'
        }

        $wrongArchRoot = Join-Path $tempRoot 'wrong-architecture'
        New-Item -ItemType Directory -Path $wrongArchRoot -Force | Out-Null
        New-TestBundle -Root $wrongArchRoot -Machine 0x014c
        Assert-Rejected -Scenario 'non-AMD64 PE binary' -Action {
            Invoke-VerifyVst3Bundle -Root $wrongArchRoot -ExpectedName 'Skell-Snap.vst3' -SourceCommit 'self-test'
        }

        $duplicateBundleRoot = Join-Path $tempRoot 'duplicate-bundle'
        New-Item -ItemType Directory -Path $duplicateBundleRoot -Force | Out-Null
        New-TestBundle -Root $duplicateBundleRoot
        New-Item -ItemType Directory -Path (Join-Path $duplicateBundleRoot 'Extra.vst3') -Force | Out-Null
        Assert-Rejected -Scenario 'duplicate top-level bundles' -Action {
            Invoke-VerifyVst3Bundle -Root $duplicateBundleRoot -ExpectedName 'Skell-Snap.vst3' -SourceCommit 'self-test'
        }

        Write-Host 'PASS: VST3 verifier accepts a valid AMD64 bundle and rejects duplicate CIDs, wrong PE architecture, and duplicate bundles.'
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($SelfTest) {
    Invoke-SelfTest
    return
}

if ([string]::IsNullOrWhiteSpace($Vst3Root)) {
    throw 'Vst3Root is required unless -SelfTest is specified.'
}

Invoke-VerifyVst3Bundle -Root $Vst3Root -ExpectedName $ExpectedBundleName -SourceCommit $CommitSha | Out-Null
