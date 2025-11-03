$ts = (Get-Date).ToString("yyyyMMdd_HHmmss")

if (-not ([bool](([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")))) {
    Write-Error "Dieses Script muss als Administrator ausgeführt werden."
    exit 1
}

$crashControlKey = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
Write-Host "JSKernel: Setze Kernel-Dump (CrashDumpEnabled = 2) in $crashControlKey ..."
Set-ItemProperty -Path $crashControlKey -Name "CrashDumpEnabled" -Value 2 -Type DWord

Write-Host "JSKernel: Setze Dump-Dateinamen und Minidump-Ordner ..."
Set-ItemProperty -Path $crashControlKey -Name "DumpFile" -Value "%SystemRoot%\Memory.dmp" -Type ExpandString
Set-ItemProperty -Path $crashControlKey -Name "MinidumpDir" -Value "%SystemRoot%\Minidump" -Type ExpandString

$memGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
Write-Host "JSKernel: Physischer RAM: $memGB GB"

$pagefiles = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PageFileUsage -ErrorAction SilentlyContinue
if ($pagefiles) {
    $totalPageMB = ($pagefiles | Measure-Object -Property AllocatedBaseSize -Sum).Sum
    Write-Host "JSKernel: Aktuelle Pagefile-Größe (MB, all pagefiles): $totalPageMB MB"
} else {
    Write-Host "JSKernel: Konnte Pagefile-Info nicht ermitteln."
    $totalPageMB = 0
}

$ramMB = [int](([int64](Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory) / 1MB)
if ($totalPageMB -lt $ramMB) {
    Write-Warning "JSKernel: Empfehlung: Pagefile sollte mindestens so groß wie RAM (~$ramMB MB) sein."
    $choice = Read-Host "JSKernel: Pagefile auf Systemlaufwerk auf 'System verwaltet' setzen? (y/N)"
    if ($choice -match '^[yY]') {
        Write-Host "JSKernel: Setze Pagefile auf Systemverwaltet..."
        $regPF = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-ItemProperty -Path $regPF -Name "PagingFiles" -Value "C:\pagefile.sys 0 0" -Type MultiString
        Set-ItemProperty -Path $regPF -Name "PagingFile" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-Host "JSKernel: Pagefile konfiguriert. Neustart erforderlich."
    } else {
        Write-Host "JSKernel: Keine Änderung an Pagefile vorgenommen."
    }
} else {
    Write-Host "JSKernel: Pagefile scheint ausreichend groß."
}

$kbdKeys = @("HKLM:\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters",
             "HKLM:\SYSTEM\CurrentControlSet\Services\i8042prt\Parameters")
foreach ($k in $kbdKeys) {
    try {
        if (-not (Test-Path $k)) {
            New-Item -Path $k -Force | Out-Null
        }
        Set-ItemProperty -Path $k -Name "CrashOnCtrlScroll" -Value 1 -Type DWord
        Write-Host "JSKernel: CrashOnCtrlScroll gesetzt in $k"
    } catch {
        Write-Warning "JSKernel: Fehler beim Setzen von CrashOnCtrlScroll in $k : $_"
    }
}

Write-Host ""
Write-Host "JSKernel: Kernel-Dump-Konfiguration wurde gesetzt."
Write-Host "JSKernel: Neustart notwendig, damit Änderungen aktiv werden."
$rebootChoice = Read-Host "JSKernel: Jetzt neu starten? (y/N)"
if ($rebootChoice -match '^[yY]') {
    Write-Host "JSKernel: Starte neu..."
    Restart-Computer
} else {
    Write-Host "JSKernel: Änderungen werden nach Neustart aktiv."
}
