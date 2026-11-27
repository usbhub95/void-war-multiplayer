function Get-SteamDirectory([string]$SteamDirectory) {
    $candidates = if ($SteamDirectory) {
        $SteamDirectory
    } else {
        (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
        foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
            (Get-ItemProperty -LiteralPath $key -Name InstallPath -ErrorAction SilentlyContinue).InstallPath
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'steam.exe') -PathType Leaf)) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }
    throw 'Steam was not found. Point -SteamDirectory at the folder containing steam.exe.'
}

function Get-VoidWarDirectory([string]$GameDirectory, [string]$SteamDirectory) {
    if ($GameDirectory) {
        if ((Test-Path -LiteralPath (Join-Path $GameDirectory 'Void War.exe') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $GameDirectory 'data.win') -PathType Leaf)) {
            return (Get-Item -LiteralPath $GameDirectory).FullName
        }
        throw 'Point -GameDirectory at the installed Void War folder containing Void War.exe and data.win.'
    }

    $steam = Get-SteamDirectory $SteamDirectory
    $libraries = @($steam)
    $metadata = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $metadata -PathType Leaf) {
        $libraryConfig = [IO.File]::ReadAllText($metadata)
        $libraries += foreach ($entry in [regex]::Matches($libraryConfig, '(?im)^\s*"path"[ \t]+"([^"\r\n]+)"')) {
            $entry.Groups[1].Value.Replace('\\', '\')
        }
    }

    foreach ($library in ($libraries | Select-Object -Unique)) {
        $steamApps = Join-Path $library 'steamapps'
        $manifest = Join-Path $steamApps 'appmanifest_2853590.acf'
        if (!(Test-Path -LiteralPath $manifest -PathType Leaf)) { continue }
        if ([IO.File]::ReadAllText($manifest) -notmatch '(?im)^\s*"installdir"[ \t]+"([^"\\/:]+)"') { continue }

        $installName = $Matches[1]
        if ($installName -in '.', '..') { continue }
        $game = Join-Path (Join-Path $steamApps 'common') $installName
        if ((Test-Path -LiteralPath (Join-Path $game 'Void War.exe') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $game 'data.win') -PathType Leaf)) {
            return (Get-Item -LiteralPath $game).FullName
        }
    }
    throw 'Void War was not found in the Steam libraries. Set -GameDirectory to its installation folder.'
}

function Get-VerifiedVanillaData([string]$Path) {
    $file = Get-Item -LiteralPath $Path
    if ($file.PSIsContainer) { throw "Expected a vanilla data.win file at $Path." }
    $expectedHash = 'ABCE01818900906D6DCC6D45777B0EBFB08FC29DDED9E84B541FB4AD4348D92B'
    $actualHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        throw "Vanilla Windows Steam build 26906873 is required at $Path. Expected SHA-256 $expectedHash. Found $actualHash."
    }
    return $file
}
