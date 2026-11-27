[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GameData,

    [Parameter(Mandatory)]
    [string]$UndertaleModCli,

    [string]$Output,

    [ValidateSet('All', 'Coop', 'NativeGuestScene', 'NativeInput')]
    [string]$Target = 'All',

    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'build\playtest')
)

$ErrorActionPreference = 'Stop'
$hasOutput = $PSBoundParameters.ContainsKey('Output')
$hasOutputDirectory = $PSBoundParameters.ContainsKey('OutputDirectory')
if ($hasOutput -and !$PSBoundParameters.ContainsKey('Target')) {
    # Preserve the single-file invocation used before the batch build.
    $Target = 'Coop'
}
if ($hasOutput -and ($Target -eq 'All' -or $hasOutputDirectory)) {
    throw 'Use -Output for a single target, or -OutputDirectory for the playtest files.'
}

$expectedHash = 'ABCE01818900906D6DCC6D45777B0EBFB08FC29DDED9E84B541FB4AD4348D92B'
$inputFile = Get-Item -LiteralPath $GameData
$compiler = Get-Item -LiteralPath $UndertaleModCli
if ($inputFile.PSIsContainer -or $compiler.PSIsContainer) {
    throw 'Point -GameData and -UndertaleModCli to files.'
}

$actualHash = (Get-FileHash -LiteralPath $inputFile.FullName -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    throw "Use an unmodified data.win from Windows Steam build 26906873 for -GameData. Expected SHA-256 $expectedHash. Found $actualHash."
}

$outputNames = @{
    Coop = 'data.win'
    NativeGuestScene = 'void-war-native-guest-scene.win'
    NativeInput = 'void-war-native-input.win'
}
if ($Target -eq 'Coop' -and !$hasOutputDirectory) {
    $OutputDirectory = Join-Path $PSScriptRoot 'build'
}

$targets = if ($Target -eq 'All') { 'NativeGuestScene', 'NativeInput' } else { $Target }
$builds = foreach ($name in $targets) {
    $path = if ($hasOutput) { $Output } else { Join-Path $OutputDirectory $outputNames[$name] }
    $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
    $parent = [IO.Path]::GetDirectoryName($destination)
    $script = if ($name -eq 'NativeInput') { 'experiments\NativeCrewInput.csx' } else { 'probe\ApplyProbe.csx' }
    [pscustomobject]@{
        Name = $name
        Destination = $destination
        Parent = $parent
        PatchScript = Join-Path $PSScriptRoot $script
        StagingFile = Join-Path $parent ('.void-war-probe-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        Hash = $null
        Reuse = $false
    }
}

try {
    foreach ($build in $builds) {
        [IO.Directory]::CreateDirectory($build.Parent) | Out-Null
        & $compiler.FullName load $inputFile.FullName --scripts $build.PatchScript --output $build.StagingFile
        if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $build.StagingFile -PathType Leaf)) {
            throw "UndertaleModCli failed to build $($build.Name) (exit code $LASTEXITCODE)."
        }
        $build.Hash = (Get-FileHash -LiteralPath $build.StagingFile -Algorithm SHA256).Hash

        if (Test-Path -LiteralPath $build.Destination) {
            if (!(Test-Path -LiteralPath $build.Destination -PathType Leaf) -or
                (Get-FileHash -LiteralPath $build.Destination -Algorithm SHA256).Hash -ne $build.Hash) {
                throw "A different file or directory exists at $($build.Destination). Choose a fresh output path."
            }
            $build.Reuse = $true
        }
    }

    # Stage every requested build before publishing. Move refuses to replace a concurrent output.
    foreach ($build in $builds) {
        if (!$build.Reuse) {
            [IO.File]::Move($build.StagingFile, $build.Destination)
        }
        Write-Output "Patched data.win: $($build.Destination)"
        Write-Output "SHA-256: $($build.Hash)"
    }
} finally {
    foreach ($build in $builds) {
        if ([IO.File]::Exists($build.StagingFile)) {
            [IO.File]::Delete($build.StagingFile)
        }
    }
}
