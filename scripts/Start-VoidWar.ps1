[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GameFile,
    [string]$GameDirectory,
    [string]$SteamDirectory,
    [switch]$LogOutput
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'VoidWarPaths.ps1')

$projectRoot = Split-Path -Parent $PSScriptRoot
$build = Join-Path $projectRoot 'build'
if (!$GameFile) {
    $GameFile = Join-Path $build 'data.win'
}
if (!(Test-Path -LiteralPath $GameFile -PathType Leaf)) {
    throw "Game data not found at $GameFile. Run scripts/New-Build.ps1 or specify -GameFile."
}
$source = Get-Item -LiteralPath $GameFile
if ($source.Extension -ne '.win') { throw 'Point -GameFile at a .win file.' }

$steam = Get-SteamDirectory $SteamDirectory
$game = Get-VoidWarDirectory -GameDirectory $GameDirectory -SteamDirectory $steam
$sidecar = Join-Path $game 'void-war-playtest.win'
if (!$PSCmdlet.ShouldProcess($sidecar, "Launch $($source.FullName) through Steam")) {
    return
}
if (Get-Process -Name 'Void War' -ErrorAction SilentlyContinue) {
    throw 'Close Void War before launching a playtest.'
}

# GameMaker needs the sidecar beside the game's bundled fonts.
if ($source.FullName -ne $sidecar) {
    $sourceHash = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
    $exists = [IO.File]::Exists($sidecar)
    if (!$exists -or (Get-FileHash -LiteralPath $sidecar -Algorithm SHA256).Hash -ne $sourceHash) {
        $stagingFile = Join-Path $game ('.void-war-playtest-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        try {
            [IO.File]::Copy($source.FullName, $stagingFile, $false)
            if ($exists) {
                [IO.File]::Replace($stagingFile, $sidecar, [System.Management.Automation.Language.NullString]::Value)
            } else {
                [IO.File]::Move($stagingFile, $sidecar)
            }
        } finally {
            if ([IO.File]::Exists($stagingFile)) {
                [IO.File]::Delete($stagingFile)
            }
        }
    }
}

$arguments = '-applaunch 2853590 -game "' + $sidecar + '"'
if ($LogOutput) {
    [IO.Directory]::CreateDirectory($build) | Out-Null
    $log = Join-Path $build 'void-war-playtest.log'
    $arguments += ' -output "' + $log + '"'
    Write-Output "Runner log: $log"
}
Start-Process -FilePath (Join-Path $steam 'steam.exe') -ArgumentList $arguments -WindowStyle Hidden
Write-Output "Requested Steam launch with $sidecar."
