[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildPath = Join-Path $projectRoot 'build'
if (!(Test-Path -LiteralPath $buildPath)) {
    return
}

$build = Get-Item -LiteralPath $buildPath -Force
if (!$build.PSIsContainer -or ($build.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Expected a regular build directory at $buildPath."
}

function Get-BuildContents([IO.DirectoryInfo]$Directory) {
    foreach ($entry in Get-ChildItem -LiteralPath $Directory.FullName -Force) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Build cleanup encountered a link at $($entry.FullName)."
        }
        if ($entry.PSIsContainer) {
            Get-BuildContents $entry
        }
        $entry
    }
}

# Check the whole tree before deleting anything. Remove directories after their contents.
$entries = @(Get-BuildContents $build)
if ($entries.Count -eq 0 -or !$PSCmdlet.ShouldProcess($build.FullName, 'Clear build output and logs')) {
    return
}

foreach ($entry in $entries) {
    if ($entry.PSIsContainer) {
        [IO.Directory]::Delete($entry.FullName)
    } else {
        Remove-Item -LiteralPath $entry.FullName -Force -Confirm:$false
    }
}
Write-Output "Cleared $($build.FullName)."
