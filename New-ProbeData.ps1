[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GameData,

    [Parameter(Mandatory)]
    [string]$UndertaleModCli,

    [string]$Output,

    [ValidateSet('Coop', 'NativeGuestScene', 'NativeInput')]
    [string]$Target = 'Coop'
)

$ErrorActionPreference = 'Stop'
$expectedHash = 'ABCE01818900906D6DCC6D45777B0EBFB08FC29DDED9E84B541FB4AD4348D92B'
$inputFile = Get-Item -LiteralPath $GameData
$compiler = Get-Item -LiteralPath $UndertaleModCli
if ($inputFile.PSIsContainer -or $compiler.PSIsContainer) {
    throw 'Point -GameData and -UndertaleModCli to files.'
}

$actualHash = (Get-FileHash -LiteralPath $inputFile.FullName -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    throw "Expected unmodified Windows Steam build 26906873 (SHA-256 $expectedHash). Found $actualHash."
}

$outputNames = @{
    Coop = 'data.win'
    NativeGuestScene = 'native-guest-scene.win'
    NativeInput = 'native-input.win'
}
if (!$PSBoundParameters.ContainsKey('Output')) {
    $Output = Join-Path (Join-Path $PSScriptRoot 'build') $outputNames[$Target]
}

$patchScript = if ($Target -eq 'NativeInput') {
    Join-Path $PSScriptRoot 'experiments\NativeCrewInput.csx'
} else {
    Join-Path $PSScriptRoot 'probe\ApplyProbe.csx'
}

$destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
if (Test-Path -LiteralPath $destination) {
    throw "Output already exists: $destination. Choose a new output path."
}

$parent = [IO.Path]::GetDirectoryName($destination)
[IO.Directory]::CreateDirectory($parent) | Out-Null
$stagingFile = Join-Path $parent ('.void-war-probe-' + [Guid]::NewGuid().ToString('N') + '.tmp')
try {
    & $compiler.FullName load $inputFile.FullName --scripts $patchScript --output $stagingFile
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $stagingFile -PathType Leaf)) {
        throw "UndertaleModCli failed to generate the patch (exit code $LASTEXITCODE)."
    }

    # Publish only a successful build. Move also refuses to replace a concurrent build's output.
    [IO.File]::Move($stagingFile, $destination)
    $patchedHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    Write-Output "Patched data.win: $destination"
    Write-Output "SHA-256: $patchedHash"
} finally {
    if (Test-Path -LiteralPath $stagingFile) {
        Remove-Item -LiteralPath $stagingFile
    }
}
