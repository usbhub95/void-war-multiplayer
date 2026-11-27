[CmdletBinding()]
param(
    [string]$GameDirectory,
    [string]$SteamDirectory
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'VoidWarPaths.ps1')

$projectRoot = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $projectRoot 'assets'
$destination = Join-Path $assets 'data.win'
if (Test-Path -LiteralPath $destination) {
    $null = Get-VerifiedVanillaData $destination
    Write-Output "Verified existing vanilla data: $destination"
    return
}

$game = Get-VoidWarDirectory -GameDirectory $GameDirectory -SteamDirectory $SteamDirectory
$source = Get-VerifiedVanillaData (Join-Path $game 'data.win')
[IO.Directory]::CreateDirectory($assets) | Out-Null
$stagingFile = Join-Path $assets ('.void-war-setup-' + [Guid]::NewGuid().ToString('N') + '.tmp')
try {
    [IO.File]::Copy($source.FullName, $stagingFile, $false)
    $null = Get-VerifiedVanillaData $stagingFile
    [IO.File]::Move($stagingFile, $destination)
    Write-Output "Prepared vanilla data: $destination"
} finally {
    if ([IO.File]::Exists($stagingFile)) {
        [IO.File]::Delete($stagingFile)
    }
}
