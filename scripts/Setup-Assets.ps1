[CmdletBinding()]
param(
    [string]$GameDirectory,
    [string]$SteamDirectory
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'VoidWarPaths.ps1')

function Initialize-UndertaleModCli([string]$ProjectRoot) {
    $package = Get-UndertaleModCliPackage $ProjectRoot
    $library = Join-Path $package.Directory 'UndertaleModLib.dll'
    if ((Test-Path -LiteralPath $package.Executable -PathType Leaf) -and
        (Test-Path -LiteralPath $library -PathType Leaf)) {
        Write-Output "Using cached UndertaleModCli: $($package.Executable)"
        return
    }
    if (Test-Path -LiteralPath $package.Directory) {
        throw "The CLI cache is incomplete at $($package.Directory). Move it aside and run setup again."
    }

    $cache = Split-Path -Parent $package.Directory
    $staging = Join-Path $cache ('.download-' + [Guid]::NewGuid().ToString('N'))
    $archive = Join-Path $staging 'undertalemodcli.zip'
    $extracted = Join-Path $staging 'package'
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    try {
        Write-Output 'Downloading the pinned Windows UndertaleModCli package.'
        Invoke-WebRequest -UseBasicParsing -Uri $package.ArchiveUri -OutFile $archive
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        if ($actualHash -ne $package.ArchiveHash) {
            throw "UndertaleModCli archive checksum mismatch. Expected $($package.ArchiveHash). Found $actualHash."
        }

        Expand-Archive -LiteralPath $archive -DestinationPath $extracted
        if (!(Test-Path -LiteralPath (Join-Path $extracted 'UndertaleModCli.exe') -PathType Leaf) -or
            !(Test-Path -LiteralPath (Join-Path $extracted 'UndertaleModLib.dll') -PathType Leaf)) {
            throw 'The verified CLI archive is missing expected files.'
        }
        [IO.Directory]::Move($extracted, $package.Directory)
        Write-Output "Prepared UndertaleModCli: $($package.Executable)"
    } finally {
        $entry = Get-Item -LiteralPath $staging -Force
        if ($entry.FullName -ne $staging -or $entry.Parent.FullName -ne $cache -or
            ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Unexpected CLI staging directory at $staging."
        }
        Remove-Item -LiteralPath $entry.FullName -Recurse -Force
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $projectRoot 'assets'
$destination = Join-Path $assets 'data.win'
if (Test-Path -LiteralPath $destination) {
    $null = Get-VerifiedVanillaData $destination
    Write-Output "Verified existing vanilla data: $destination"
} else {
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
}

Initialize-UndertaleModCli $projectRoot
