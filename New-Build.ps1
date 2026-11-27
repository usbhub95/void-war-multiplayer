[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GameDirectory,

    [Parameter(Mandatory)]
    [string]$UndertaleModCli,

    [switch]$NativeInput
)

$ErrorActionPreference = 'Stop'
$game = Get-Item -LiteralPath $GameDirectory
if (!$game.PSIsContainer -or !(Test-Path -LiteralPath (Join-Path $game.FullName 'Void War.exe') -PathType Leaf)) {
    throw 'Point -GameDirectory at the installed Void War game folder.'
}

$inputFile = Get-Item -LiteralPath (Join-Path $game.FullName 'data.win')
$compiler = Get-Item -LiteralPath $UndertaleModCli
if ($inputFile.PSIsContainer -or $compiler.PSIsContainer) {
    throw 'The installed data.win and -UndertaleModCli must be files.'
}

$expectedHash = 'ABCE01818900906D6DCC6D45777B0EBFB08FC29DDED9E84B541FB4AD4348D92B'
$actualHash = (Get-FileHash -LiteralPath $inputFile.FullName -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    throw "The installed data.win must match vanilla Windows Steam build 26906873. Expected SHA-256 $expectedHash. Found $actualHash."
}

$source = Join-Path $PSScriptRoot 'src'
$patchScript = if ($NativeInput) {
    Join-Path $source 'NativeCrewInput.csx'
} else {
    Join-Path $source 'VoidWarMultiplayer.csx'
}

$buildDirectory = Join-Path $PSScriptRoot 'build'
$destination = Join-Path $buildDirectory 'data.win'
if ($inputFile.FullName -eq $destination) {
    throw 'The installed data.win and the build output must be separate files.'
}

[IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
$stagingFile = Join-Path $buildDirectory ('.void-war-build-' + [Guid]::NewGuid().ToString('N') + '.tmp')
try {
    & $compiler.FullName load $inputFile.FullName --scripts $patchScript --output $stagingFile
    if ($LASTEXITCODE -ne 0 -or ![IO.File]::Exists($stagingFile)) {
        throw "UndertaleModCli failed to build data.win (exit code $LASTEXITCODE)."
    }

    $hash = (Get-FileHash -LiteralPath $stagingFile -Algorithm SHA256).Hash
    # Publish only a complete build and keep the previous output if compilation fails.
    if ([IO.File]::Exists($destination)) {
        [IO.File]::Replace($stagingFile, $destination, [System.Management.Automation.Language.NullString]::Value)
    } else {
        [IO.File]::Move($stagingFile, $destination)
    }
    Write-Output "Patched data.win: $destination"
    Write-Output "SHA-256: $hash"
} finally {
    if ([IO.File]::Exists($stagingFile)) {
        [IO.File]::Delete($stagingFile)
    }
}
