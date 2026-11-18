#requires -Version 7
<#
.SYNOPSIS
  Points this Windows machine at the inkwell repo. Safe to re-run.

.DESCRIPTION
  1. Sets the user environment variable INKWELL to this folder.
  2. Moves aside a user-scope PSReadLine that is older than the one bundled with
     PowerShell (an old copy there shadows the bundled one and breaks predictions).
  3. Adds a three-line shim to $PROFILE that loads pwsh/profile.ps1, and comments
     out the legacy oh-my-posh / posh-git module lines.
  4. Adds the Ink schemes to Windows Terminal and sets the scheme and the corner
     wash as profile defaults.
  Every file it edits is backed up next to the original first.

.PARAMETER Tools
  Also install the missing command-line tools with winget (eza, fzf, zoxide, bat)
  and the PSFzf module.

.PARAMETER Font
  Font face to set as the Windows Terminal default, e.g. 'JetBrainsMono Nerd Font'.
  Left alone when omitted.

.PARAMETER WashOpacity
  Strength of the corner wash, 0 to 1.

.PARAMETER ProfilePath
.PARAMETER SettingsPath
  For trying the installer against copies. When -ProfilePath is given, steps 1 and 2
  and -Tools are skipped, so nothing outside the named files changes.

.EXAMPLE
  ./install.ps1 -WhatIf      # show what would change
  ./install.ps1 -Tools       # install everything
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Tools,
    [switch]$SkipTerminal,
    [string]$Font,
    [ValidateRange(0, 1)][double]$WashOpacity = 0.4,
    [string]$ProfilePath = $PROFILE,
    [string[]]$SettingsPath
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$live = -not $PSBoundParameters.ContainsKey('ProfilePath')
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Backup-File([string]$Path) {
    $backup = "$Path.inkwell-$stamp.bak"
    Copy-Item -LiteralPath $Path -Destination $backup
    Write-Host "  backup  $backup"
}

# --- 1. INKWELL -----------------------------------------------------------
if ($live) {
    Write-Host 'INKWELL'
    if ([Environment]::GetEnvironmentVariable('INKWELL', 'User') -eq $root) {
        Write-Host "  ok      already $root"
    } elseif ($PSCmdlet.ShouldProcess('user environment', "set INKWELL=$root")) {
        [Environment]::SetEnvironmentVariable('INKWELL', $root, 'User')
        $env:INKWELL = $root
        Write-Host "  set     $root"
    }
}

# --- 2. stale PSReadLine --------------------------------------------------------
if ($live) {
    Write-Host 'PSReadLine'
    $all = @(Get-Module -ListAvailable PSReadLine)
    $bundled = $all | Where-Object { $_.ModuleBase.StartsWith($PSHOME, 'OrdinalIgnoreCase') } |
        Sort-Object Version -Descending | Select-Object -First 1
    $userModules = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Modules'
    $stale = @($all | Where-Object {
            $bundled -and $_.Version -lt $bundled.Version -and
            $_.ModuleBase.StartsWith($userModules, 'OrdinalIgnoreCase')
        })
    if (-not $stale) { Write-Host '  ok      nothing shadows the bundled module' }
    foreach ($module in $stale) {
        $target = Join-Path (Split-Path $userModules) "inkwell-backup\PSReadLine-$($module.Version)"
        if ($PSCmdlet.ShouldProcess($module.ModuleBase, "move aside (older than bundled $($bundled.Version)) to $target")) {
            try {
                New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
                Move-Item -LiteralPath $module.ModuleBase -Destination $target
                $parent = Split-Path $module.ModuleBase
                if (-not (Get-ChildItem -LiteralPath $parent -Force)) { Remove-Item -LiteralPath $parent }
                Write-Host "  moved   PSReadLine $($module.Version) to $target"
            } catch {
                Write-Warning "Could not move $($module.ModuleBase): $($_.Exception.Message)"
                Write-Warning 'It is probably loaded by an open PowerShell window. Close them all, then from cmd.exe run:  pwsh -NoProfile -NonInteractive -File install.ps1'
            }
        }
    }
}

# --- 3. profile shim ------------------------------------------------------------
Write-Host "Profile  $ProfilePath"
$begin = '# >>> inkwell >>>'
$end = '# <<< inkwell <<<'
$shim = @(
    $begin
    'if ($env:INKWELL -and (Test-Path "$env:INKWELL/pwsh/profile.ps1")) { . "$env:INKWELL/pwsh/profile.ps1" }'
    $end
)
$existing = if (Test-Path -LiteralPath $ProfilePath) { @(Get-Content -LiteralPath $ProfilePath) } else { @() }
$kept = [System.Collections.Generic.List[string]]::new()
$inBlock = $false
$disabled = 0
foreach ($line in $existing) {
    if ($line.Trim() -eq $begin) { $inBlock = $true; continue }
    if ($line.Trim() -eq $end) { $inBlock = $false; continue }
    if ($inBlock) { continue }
    if ($line -match '^\s*(Import-Module\s+(oh-my-posh|posh-git)\b|Set-(Theme|PoshPrompt)\b)') {
        $kept.Add("# disabled by inkwell: $($line.Trim())")
        $disabled++
    } else {
        $kept.Add($line)
    }
}
while ($kept.Count -and -not $kept[$kept.Count - 1].Trim()) { $kept.RemoveAt($kept.Count - 1) }
$updated = @($kept) + $(if ($kept.Count) { '' }) + $shim
if (($updated -join "`n") -eq ($existing -join "`n")) {
    Write-Host '  ok      shim already in place'
} elseif ($PSCmdlet.ShouldProcess($ProfilePath, "add the inkwell shim, comment out $disabled legacy prompt line(s)")) {
    if ($existing) { Backup-File $ProfilePath } else { New-Item -ItemType Directory -Force (Split-Path $ProfilePath) | Out-Null }
    Set-Content -LiteralPath $ProfilePath -Value $updated
    Write-Host "  wrote   shim added, $disabled legacy line(s) commented out"
}

# --- 4. Windows Terminal --------------------------------------------------------
if (-not $SkipTerminal) {
    if (-not $SettingsPath) {
        $SettingsPath = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        ) | Where-Object { Test-Path -LiteralPath $_ }
    }
    $schemes = @(Get-Content -Raw (Join-Path $root 'terminal\schemes.json') | ConvertFrom-Json -AsHashtable)
    $names = $schemes.name
    foreach ($path in $SettingsPath) {
        Write-Host "Terminal $path"
        $before = Get-Content -Raw -LiteralPath $path
        $json = $before | ConvertFrom-Json -AsHashtable
        if ($json.profiles -isnot [System.Collections.IDictionary]) {
            Write-Warning '  profiles is not in the { defaults, list } form; skipped. Open Settings once in Windows Terminal and re-run.'
            continue
        }
        $json.schemes = @(@($json.schemes) | Where-Object { $_ -and $_.name -notin $names }) + $schemes
        if ($json.profiles.defaults -isnot [System.Collections.IDictionary]) { $json.profiles.defaults = [ordered]@{} }
        $defaults = $json.profiles.defaults
        $defaults.colorScheme = [ordered]@{ dark = 'Ink Parchment'; light = 'Ink Paper' }
        $defaults.backgroundImage = Join-Path $root 'terminal\wash.png'
        $defaults.backgroundImageAlignment = 'bottomRight'
        $defaults.backgroundImageStretchMode = 'none'
        $defaults.backgroundImageOpacity = $WashOpacity
        if ($Font) {
            if ($defaults.font -isnot [System.Collections.IDictionary]) { $defaults.font = [ordered]@{} }
            $defaults.font.face = $Font
        }
        $after = $json | ConvertTo-Json -Depth 32
        if ($after.Trim() -eq $before.Trim()) {
            Write-Host '  ok      already applied'
        } elseif ($PSCmdlet.ShouldProcess($path, 'add Ink Parchment and Ink Paper, set scheme and corner wash as defaults')) {
            Backup-File $path
            Set-Content -LiteralPath $path -Value $after
            Write-Host "  wrote   schemes, defaults (wash opacity $WashOpacity)"
        }
    }
}

# --- 5. tools ---------------------------------------------------------------------
$wanted = [ordered]@{
    'oh-my-posh' = 'JanDeDobbeleer.OhMyPosh'
    'eza'        = 'eza-community.eza'
    'fzf'        = 'junegunn.fzf'
    'zoxide'     = 'ajeetdsouza.zoxide'
    'bat'        = 'sharkdp.bat'
}
$missing = @($wanted.Keys | Where-Object { -not (Get-Command $_ -ErrorAction Ignore) })
$needPsFzf = -not (Get-Module -ListAvailable PSFzf)
Write-Host 'Tools'
if ($Tools -and $live) {
    foreach ($name in $missing) {
        if ($PSCmdlet.ShouldProcess($wanted[$name], 'winget install')) {
            winget install --id $wanted[$name] --exact --source winget --accept-package-agreements --accept-source-agreements
        }
    }
    if ($needPsFzf -and $PSCmdlet.ShouldProcess('PSFzf', 'Install-Module -Scope CurrentUser')) {
        Install-Module PSFzf -Scope CurrentUser -Force
    }
} elseif ($missing -or $needPsFzf) {
    $list = @($missing) + $(if ($needPsFzf) { 'PSFzf (module)' })
    Write-Host "  missing $($list -join ', ')"
    Write-Host '          The profile works without them; run ./install.ps1 -Tools to add them.'
} else {
    Write-Host '  ok      everything is installed'
}

Write-Host ''
Write-Host $(if ($WhatIfPreference) { 'Nothing was changed (-WhatIf).' } else { 'Done. Open a new terminal tab to see it.' })
