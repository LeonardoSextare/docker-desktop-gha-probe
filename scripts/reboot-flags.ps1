# Prints the usual signs that Windows is waiting for a restart.
$checks = [ordered]@{
    'CBS RebootPending'          = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    'WindowsUpdate RebootRequired' = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    'PendingFileRenameOperations' = $null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
}
$checks.GetEnumerator() | Format-Table Name, Value -AutoSize | Out-String
