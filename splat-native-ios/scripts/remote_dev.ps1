[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Status', 'Sync', 'Check', 'Push', 'DeviceCheck')]
    [string]$Command = 'Status'
)

$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & git -C $repoRoot @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git failed: git $($Arguments -join ' ')"
    }
}

function Assert-CleanWorktree {
    $dirty = & git -C $repoRoot status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read git status.' }
    if ($dirty) { throw 'Worktree has uncommitted changes. Commit or stash them before Sync.' }
}

function Invoke-PythonContract {
    param([string]$RelativePath)
    & python (Join-Path $repoRoot $RelativePath)
    if ($LASTEXITCODE -ne 0) { throw "Contract failed: $RelativePath" }
}

switch ($Command) {
    'Status' {
        Invoke-Git status --short --branch
        Invoke-Git log -5 --oneline --decorate
    }
    'Sync' {
        Assert-CleanWorktree
        Invoke-Git fetch origin
        $upstream = & git -C $repoRoot rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $upstream) {
            Invoke-Git merge --ff-only $upstream
        } else {
            Write-Output 'No upstream is configured yet. Run Push after the first commit.'
        }
    }
    'Check' {
        $contracts = @(
            'splat-native-ios\scripts\test_reconstruction_contracts.py',
            'splat-native-ios\scripts\test_mesh_durability_contract.py',
            'splat-native-ios\scripts\test_worldmap_durability_contract.py',
            'splat-native-ios\scripts\test_s9_memory_drain_contract.py',
            'splat-native-ios\scripts\test_s13_depth_seed_contract.py',
            'splat-native-ios\scripts\test_s14_rgb_dense_seed_contract.py'
        )
        foreach ($contract in $contracts) { Invoke-PythonContract $contract }
        Invoke-Git diff --check
        Write-Output 'Local Scaniverse contract gate: PASS'
    }
    'Push' {
        Invoke-Git push --set-upstream origin HEAD
        Write-Output 'Pushed. Only the lightweight Linux gate runs for this development branch.'
    }
    'DeviceCheck' {
        $branch = (& git -C $repoRoot branch --show-current).Trim()
        if (-not $branch) { throw 'DeviceCheck requires a named branch.' }
        & gh workflow run splat-native-ios.yml --repo ALLSUNDAY1122/ALLSUNDAY1122.github.io --ref $branch
        if ($LASTEXITCODE -ne 0) { throw 'Unable to dispatch the macOS/Xcode gate. Check gh auth status.' }
        Write-Output "Dispatched macOS/Xcode validation for $branch. This does not upload to TestFlight."
    }
}
