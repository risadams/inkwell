# inkwell, PowerShell side.
# Dot-sourced from $PROFILE by the three-line shim that install.ps1 adds.
# Everything here is guarded, so a missing tool never breaks shell startup.

$Inkwell = Split-Path -Parent $PSScriptRoot
if (-not $env:INKWELL) { $env:INKWELL = $Inkwell }

function Read-InkwellConf([string]$Name) {
    $path = Join-Path $Inkwell "shared/$Name"
    if (-not (Test-Path $path)) { return }
    foreach ($line in Get-Content $path) {
        if ($line -match '^\s*(#|$)') { continue }
        $key, $value = $line -split '=', 2
        if ($null -eq $value) { continue }
        [pscustomobject]@{ Key = $key.Trim(); Value = $value.Trim() }
    }
}

# --- shared environment (shared/env.conf) ------------------------------------
foreach ($entry in Read-InkwellConf 'env.conf') {
    Set-Item -Path "env:$($entry.Key)" -Value $entry.Value
}

# --- shared aliases (shared/aliases.conf) ------------------------------------
foreach ($entry in Read-InkwellConf 'aliases.conf') {
    $command = ($entry.Value -split '\s+')[0]
    if (-not (Get-Command $command -ErrorAction Ignore)) { continue }
    # A built-in alias would win over the function, so clear it first.
    if (Get-Alias -Name $entry.Key -ErrorAction Ignore) {
        Remove-Alias -Name $entry.Key -Force -Scope Global -ErrorAction Ignore
    }
    Invoke-Expression "function global:$($entry.Key) { $($entry.Value) @args }"
}
Remove-Item function:Read-InkwellConf

# --- line editing: history predictions, menu completion ----------------------
if (Get-Module PSReadLine) {
    try {
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
        Set-PSReadLineOption -Colors @{
            InlinePrediction       = "`e[90m"
            ListPrediction         = "`e[35m"
            ListPredictionSelected = "`e[7m"
        }
    } catch {
        # Predictions need an interactive VT console; redirected hosts land here.
    }
    Set-PSReadLineOption -HistoryNoDuplicates -HistorySearchCursorMovesToEnd -MaximumHistoryCount 10000 -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# --- fzf: Ctrl+R history, Ctrl+T files (needs the PSFzf module) ---------------
if ((Get-Command fzf -ErrorAction Ignore) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# --- zoxide: z <part-of-a-path> ------------------------------------------------
if (Get-Command zoxide -ErrorAction Ignore) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# --- prompt: the same theme file zsh uses -------------------------------------
if (Get-Command oh-my-posh -ErrorAction Ignore) {
    oh-my-posh init pwsh --config (Join-Path $Inkwell 'prompt/ink.omp.json') | Invoke-Expression
}

# --- keeping machines in sync --------------------------------------------------
function inkcd { Set-Location $env:INKWELL }
function inksync {
    git -C $env:INKWELL pull --ff-only
    Write-Host 'Open a new shell to pick up the changes. Re-run install.ps1 only if terminal/ changed.'
}

# --- this machine only (git-ignored) --------------------------------------------
$localProfile = Join-Path $Inkwell 'local.ps1'
if (Test-Path $localProfile) { . $localProfile }
Remove-Variable localProfile, entry, command -ErrorAction Ignore
