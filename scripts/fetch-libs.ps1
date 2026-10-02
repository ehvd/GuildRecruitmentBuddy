<#
.SYNOPSIS
  Fetches the embedded libraries into Libs/ for local development.
.DESCRIPTION
  CI/CurseForge packaging uses the externals in .pkgmeta. This script mirrors them locally
  from GitHub (needs git, no svn). Libs/ is gitignored.
#>
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$libs = Join-Path $root 'Libs'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("grb-libs-" + [guid]::NewGuid().ToString('N'))

if ((Test-Path $libs) -and -not $Force) {
    Write-Host "Libs/ already exists. Use -Force to re-fetch."
    return
}
if (Test-Path $libs) { Remove-Item -Recurse -Force $libs }
New-Item -ItemType Directory -Path $libs, $tmp | Out-Null

function Clone($url, $name) {
    $dest = Join-Path $tmp $name
    git clone --quiet --depth 1 $url $dest
    if ($LASTEXITCODE -ne 0) { throw "git clone failed: $url" }
    return $dest
}

try {
    # Ace3 mirror: LibStub, CallbackHandler-1.0 and the Ace* libraries (AceComm bundles ChatThrottleLib)
    $ace = Clone 'https://github.com/WoWUIDev/Ace3.git' 'ace3'
    $aceLibs = 'LibStub', 'CallbackHandler-1.0', 'AceAddon-3.0', 'AceDB-3.0', 'AceDBOptions-3.0', 'AceConsole-3.0',
        'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0', 'AceConfig-3.0', 'AceGUI-3.0', 'AceLocale-3.0'
    foreach ($name in $aceLibs) {
        Copy-Item -Recurse (Join-Path $ace $name) (Join-Path $libs $name)
    }

    $ldb = Clone 'https://github.com/tekkub/libdatabroker-1-1.git' 'ldb'
    $ldbDest = Join-Path $libs 'LibDataBroker-1.1'
    New-Item -ItemType Directory -Path $ldbDest | Out-Null
    Copy-Item (Join-Path $ldb 'LibDataBroker-1.1.lua') $ldbDest

    $icon = Clone 'https://github.com/wowace-clone/LibDBIcon-1.0.git' 'dbicon'
    Copy-Item -Recurse (Join-Path $icon 'LibDBIcon-1.0') (Join-Path $libs 'LibDBIcon-1.0')

    Write-Host "Libraries written to $libs"
}
finally {
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
