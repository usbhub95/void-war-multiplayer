[CmdletBinding(DefaultParameterSetName = 'Coop')]
param(
    [string]$GameDirectory,

    [string]$UndertaleModCli,

    [Parameter(ParameterSetName = 'NativeInput')]
    [switch]$NativeInput,

    [Parameter(ParameterSetName = 'NativeGuestSelection')]
    [switch]$NativeGuestSelection
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'VoidWarPaths.ps1')

$projectRoot = Split-Path -Parent $PSScriptRoot
$inputPath = if ($GameDirectory) {
    Join-Path (Get-VoidWarDirectory -GameDirectory $GameDirectory) 'data.win'
} else {
    Join-Path $projectRoot 'assets\data.win'
}
if (!(Test-Path -LiteralPath $inputPath -PathType Leaf)) {
    throw 'Run scripts/Setup-Assets.ps1 to prepare assets/data.win.'
}
$inputFile = Get-VerifiedVanillaData $inputPath
if (!$UndertaleModCli) {
    $package = Get-UndertaleModCliPackage $projectRoot
    $UndertaleModCli = $package.Executable
    if (!(Test-Path -LiteralPath $UndertaleModCli -PathType Leaf) -or
        !(Test-Path -LiteralPath (Join-Path $package.Directory 'UndertaleModLib.dll') -PathType Leaf)) {
        throw 'Run scripts/Setup-Assets.ps1 to prepare the pinned UndertaleModCli.'
    }
}
$compiler = Get-Item -LiteralPath $UndertaleModCli
if ($compiler.PSIsContainer) {
    throw '-UndertaleModCli must point to the executable.'
}

$patchScript = if ($NativeInput) {
    Join-Path $projectRoot 'tests\NativeCrewInput.csx'
} else {
    Join-Path $projectRoot 'src\VoidWarMultiplayer.csx'
}

$scriptArguments = @('--scripts', $patchScript)
if ($NativeGuestSelection) {
    $scriptArguments += @('--scripts', (Join-Path $projectRoot 'tests\NativeGuestSelection.csx'))
}

$buildDirectory = Join-Path $projectRoot 'build'
$destination = Join-Path $buildDirectory 'data.win'
if ($inputFile.FullName -eq $destination) {
    throw 'The installed data.win and the build output must be separate files.'
}

[IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
$stagingFile = Join-Path $buildDirectory ('.void-war-build-' + [Guid]::NewGuid().ToString('N') + '.tmp')
try {
    & $compiler.FullName load $inputFile.FullName @scriptArguments --output $stagingFile
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
