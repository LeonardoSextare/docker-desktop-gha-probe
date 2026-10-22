# Functional tests against the Docker Desktop Linux engine. Runs the same way
# on Windows PowerShell 5.1 and PowerShell 7, and prints the time of each test.
param(
    [Parameter(Mandatory)]
    [string] $ResultFile
)

$ErrorActionPreference = 'Continue'
$failedCount = 0

function Invoke-Test {
    param([string] $Name, [scriptblock] $Block)

    Write-Host "`n===== $Name ====="
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $output = & $Block 2>&1 | Out-String -Width 300
    $exitCode = $LASTEXITCODE
    $stopwatch.Stop()

    Write-Host $output
    $seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
    $status = if ($exitCode -eq 0) { 'ok' } else { "FAILED (exit $exitCode)" }
    Write-Host "-> $status in $seconds s"

    $edition = $PSVersionTable.PSEdition
    $version = $PSVersionTable.PSVersion
    Add-Content -Path $ResultFile -Value "| $edition $version | $Name | $status | $seconds |" -Encoding utf8
    if ($exitCode -ne 0) { $script:failedCount++ }
}

$projectPath = 'C:\temp\projeto'
New-Item -ItemType Directory -Force -Path $projectPath | Out-Null
Set-Content -Path "$projectPath\arquivo.txt" -Value 'hello from Windows' -Encoding ascii

Write-Host "docker in use: $((Get-Command docker).Source)"
docker context ls

Invoke-Test 'hello-world' { docker run --rm hello-world }

Invoke-Test 'Windows folder mount' {
    docker run --rm --volume "${projectPath}:/work" --workdir /work alpine ls -la
}

Invoke-Test 'pull winplaybook:0' { docker pull ghcr.io/leonardosextare/winplaybook:0 }

Invoke-Test 'ansible --version' { docker run --rm ghcr.io/leonardosextare/winplaybook:0 ansible --version }

# Records what reaches the container; the result is compared by hand.
Invoke-Test 'quoted JSON argument' { docker run --rm alpine echo '{\"a\": \"b c\"}' }

exit $failedCount
