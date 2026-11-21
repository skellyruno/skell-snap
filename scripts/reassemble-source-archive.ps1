param(
  [Parameter(Mandatory = $true)]
  [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$partDirectory = Join-Path $PSScriptRoot '..\source-archive\parts'
$parts = @(Get-ChildItem -LiteralPath $partDirectory -Filter 'part-*.bin' -File | Sort-Object Name)
if ($parts.Count -ne 16) {
  throw "Expected 16 source archive parts, found $($parts.Count) in $partDirectory"
}

$expectedNames = 1..16 | ForEach-Object { 'part-{0:D2}.bin' -f $_ }
for ($i = 0; $i -lt $expectedNames.Count; $i++) {
  if ($parts[$i].Name -ne $expectedNames[$i]) {
    throw "Unexpected archive part order: expected $($expectedNames[$i]), found $($parts[$i].Name)"
  }
}

$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$stream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
try {
  foreach ($part in $parts) {
    $bytes = [System.IO.File]::ReadAllBytes($part.FullName)
    $stream.Write($bytes, 0, $bytes.Length)
  }
}
finally {
  $stream.Dispose()
}

$expectedLength = 61943
$actualLength = (Get-Item -LiteralPath $OutputPath).Length
if ($actualLength -ne $expectedLength) {
  throw "Reassembled source archive length mismatch: expected $expectedLength, got $actualLength"
}

$expectedSha256 = '42c019c07872dfdcfdf12e1069632a1e8f55bb5a7424edef708d00a0e49b4d15'
$actualSha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
  throw "Reassembled source archive SHA-256 mismatch: expected $expectedSha256, got $actualSha256"
}

Write-Host "Source archive reconstructed and SHA-256 verified: $actualSha256 ($actualLength bytes)"
