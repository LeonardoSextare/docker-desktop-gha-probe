# Collects the runner inventory. Every section writes its raw output to the
# job log and to the report file, and a failing section does not stop the rest.
param(
    [Parameter(Mandatory)]
    [string] $OutFile
)

# GitHub's shell wrapper sets 'Stop'; here stderr from a native command must
# be recorded, not turned into a terminating error.
$ErrorActionPreference = 'Continue'
$env:WSL_UTF8 = '1'   # wsl.exe prints UTF-16 by default, which breaks the log

function Write-Section {
    param([string] $Title, [scriptblock] $Block)

    $header = "`n===== $Title ====="
    $body = try {
        & $Block 2>&1 | Out-String -Width 300
    } catch {
        "ERROR: $($_.Exception.Message)"
    }
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        $body += "(exit code: $LASTEXITCODE)`n"
        $global:LASTEXITCODE = 0
    }
    $text = "$header`n$body"
    Write-Host $text
    Add-Content -Path $OutFile -Value $text -Encoding utf8
}

Write-Section 'Runner image' {
    "ImageOS=$env:ImageOS"
    "ImageVersion=$env:ImageVersion"
    "RUNNER_NAME=$env:RUNNER_NAME"
    "RUNNER_ARCH=$env:RUNNER_ARCH"
}

Write-Section 'OS version' {
    # Format-List on each object: a single table for objects of different
    # types prints the second one as empty lines.
    [Environment]::OSVersion | Format-List
    Get-ComputerInfo -Property OsName, OsVersion, OsBuildNumber, WindowsVersion, OsDisplayVersion, WindowsEditionId, OsArchitecture |
        Format-List
}

Write-Section 'CPU' {
    Get-CimInstance Win32_Processor | Format-List Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors,
        VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions, VMMonitorModeExtensions
}

Write-Section 'Memory' {
    $cs = Get-CimInstance Win32_ComputerSystem
    "TotalPhysicalMemory (GB) = {0:N1}" -f ($cs.TotalPhysicalMemory / 1GB)
    "Model = $($cs.Model)"
    "HypervisorPresent = $($cs.HypervisorPresent)"
}

Write-Section 'Disk' {
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
        Format-Table DeviceID, @{ n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 1) } },
            @{ n = 'FreeGB'; e = { [math]::Round($_.FreeSpace / 1GB, 1) } } -AutoSize
}

Write-Section 'Hyper-V info (Get-ComputerInfo)' {
    Get-ComputerInfo -Property HyperV* | Format-List
}

Write-Section 'systeminfo' { systeminfo }

Write-Section 'Optional features' {
    'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform', 'Microsoft-Hyper-V', 'Microsoft-Hyper-V-All', 'Containers' |
        ForEach-Object {
            $featureName = $_
            try { Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction Stop | Select-Object FeatureName, State, RestartRequired }
            catch { "${featureName}: $($_.Exception.Message)" }
        } | Format-Table -AutoSize
}

Write-Section 'Server features (Get-WindowsFeature)' {
    Get-WindowsFeature -Name Hyper-V*, Containers, Microsoft-Windows-Subsystem-Linux -ErrorAction Stop |
        Format-Table Name, InstallState -AutoSize
}

Write-Section 'Hypervisor launch type (bcdedit)' { bcdedit /enum '{current}' }

Write-Section 'KB5127648' {
    $hotfix = Get-HotFix -Id KB5127648 -ErrorAction SilentlyContinue
    if ($hotfix) { $hotfix } else { 'KB5127648 NOT found in Get-HotFix' }
}

Write-Section 'All hotfixes' { Get-HotFix | Sort-Object InstalledOn | Format-Table HotFixID, Description, InstalledOn -AutoSize }

Write-Section 'wsl --version' { wsl --version }
Write-Section 'wsl --status' { wsl --status }
Write-Section 'wsl --list --verbose' { wsl --list --verbose }

Write-Section 'docker location' { Get-Command docker -All -ErrorAction Stop | Format-List Source, Version }
Write-Section 'docker version' { docker version }
Write-Section 'docker info' { docker info }
Write-Section 'docker context ls' { docker context ls }
Write-Section 'Docker services' { Get-Service *docker* -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType -AutoSize }
Write-Section 'Docker Desktop present?' {
    Test-Path 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    Get-ChildItem '\\.\pipe\' | Where-Object Name -like '*docker*' | Select-Object -ExpandProperty Name
}

Write-Section "PowerShell ($($PSVersionTable.PSEdition))" {
    $PSVersionTable
    Get-Module Pester -ListAvailable | Format-Table Name, Version, Path -AutoSize
}

exit 0
