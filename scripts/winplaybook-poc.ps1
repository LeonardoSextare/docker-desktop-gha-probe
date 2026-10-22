# Proof of concept: runs real WinPlaybook commands, the way a user would,
# from a copy of the hello project. Works on Windows PowerShell 5.1 and PowerShell 7.
param(
    [Parameter(Mandatory)]
    [string] $RepositoryPath
)

$ErrorActionPreference = 'Continue'
$failedCount = 0

function Invoke-Check {
    param([string] $Name, [string] $ExpectedText, [scriptblock] $Block)

    Write-Host "`n===== $Name ====="
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $output = & $Block 2>&1 | Out-String -Width 300
    $exitCode = $LASTEXITCODE
    $stopwatch.Stop()

    Write-Host $output
    $isOk = ($exitCode -eq 0) -and ($output -like "*$ExpectedText*")
    $status = if ($isOk) { 'ok' } else { "FAILED (exit $exitCode)" }
    Write-Host ("-> {0} in {1:N1} s" -f $status, $stopwatch.Elapsed.TotalSeconds)
    if (-not $isOk) { $script:failedCount++ }
}

Write-Host "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
Import-Module (Join-Path $RepositoryPath 'module\WinPlaybook\WinPlaybook.psd1') -Force
Write-Host "WinPlaybook image: $(& (Get-Module WinPlaybook) { Get-ImageReference })"

$projectPath = Join-Path $env:RUNNER_TEMP "poc-project-$($PSVersionTable.PSEdition)"
Remove-Item $projectPath -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $RepositoryPath 'tests\data\projects\hello') $projectPath -Recurse
Push-Location $projectPath

Invoke-Check 'ansible-playbook site.yml' 'hello from WinPlaybook' {
    Invoke-WinPlaybook ansible-playbook site.yml
}

Invoke-Check 'ansible-playbook with a relative Windows path' 'hello from WinPlaybook' {
    Invoke-WinPlaybook ansible-playbook .\site.yml
}

Invoke-Check 'ansible with JSON extra variables' '"msg": "hello world"' {
    Invoke-WinPlaybook ansible localhost -m ansible.builtin.debug -a 'msg={{ greeting }}' -e '{"greeting": "hello world"}'
}

Pop-Location
exit $failedCount
