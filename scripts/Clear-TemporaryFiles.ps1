[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildOutput = Join-Path $projectRoot 'build\data.win'

function Get-TemporaryEntries([IO.DirectoryInfo]$Directory) {
    foreach ($entry in Get-ChildItem -LiteralPath $Directory.FullName -Force) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Cleanup encountered a link at $($entry.FullName)."
        }
        if ($entry.PSIsContainer) {
            Get-TemporaryEntries $entry
        } elseif ($entry.FullName -eq $buildOutput) {
            continue
        }
        $entry
    }
}

# Check both trees before deleting anything. Remove directories after their contents.
$entries = @(foreach ($name in 'temp', 'build') {
    $path = Join-Path $projectRoot $name
    if (!(Test-Path -LiteralPath $path)) { continue }

    $directory = Get-Item -LiteralPath $path -Force
    if (!$directory.PSIsContainer -or ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Expected a regular directory at $path."
    }
    Get-TemporaryEntries $directory
})

if ($entries.Count -eq 0 -or !$PSCmdlet.ShouldProcess($projectRoot, 'Clear temporary files and directories in temp and build, preserving build\data.win')) {
    return
}

foreach ($entry in $entries) {
    if ($entry.PSIsContainer) {
        [IO.Directory]::Delete($entry.FullName)
    } else {
        Remove-Item -LiteralPath $entry.FullName -Force -Confirm:$false
    }
}
Write-Output "Cleared $($entries.Count) temporary files and directories."
