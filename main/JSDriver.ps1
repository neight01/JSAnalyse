# JSDriver_Menu.ps1
# Interaktives Sammel-Skript für System- und Sicherheitsrelevante Infos.
# Als Administrator ausführen!

# -------------------------
# Setup: Ausgabepfad & Hilfsfunktionen
# -------------------------
$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$outDir = "$env:USERPROFILE\Desktop\JSDriver_$timestamp"
New-Item -Path $outDir -ItemType Directory -Force | Out-Null

function Save-Output($name, $scriptblock) {
    $file = Join-Path $outDir ($name + ".txt")
    try {
        & $scriptblock *>&1 | Out-File -FilePath $file -Encoding UTF8
        return $file
    } catch {
        $err = "Fehler beim Ausführen von $name : $_"
        $err | Out-File -FilePath $file -Encoding UTF8
        return $file
    }
}

function Zip-Results {
    param([string]$targetZip)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if(Test-Path $targetZip) { Remove-Item $targetZip -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($outDir, $targetZip)
}

function Pause() { Write-Host ""; Read-Host "Drücke Enter um fortzufahren..." > $null }

# -------------------------
# Definiere Tasks (Name -> ScriptBlock)
# -------------------------
$Tasks = @{
    "hostname" = { hostname }
    "systeminfo" = { systeminfo }
    "win_bios" = { Get-CimInstance -ClassName Win32_BIOS | Format-List * }
    "computer_system" = { Get-CimInstance -ClassName Win32_ComputerSystem | Format-List * }

    "get-process" = { Get-Process | Sort-Object -Property CPU -Descending | Format-Table -AutoSize }
    "tasklist_verbose" = { tasklist /v }
    "services" = { Get-Service | Where-Object {$_.Status -ne 'Stopped'} | Sort-Object Status,Name | Format-Table -AutoSize }

    "netstat_ano" = { netstat -ano }
    "net_tcp_connections" = { Get-NetTCPConnection | Sort-Object State -Descending | Format-Table -AutoSize }
    "network_adapters" = { Get-NetAdapter | Format-Table -AutoSize }
    "ip_config" = { ipconfig /all }

    "driverquery" = { driverquery /v }
    "signed_drivers" = { Get-CimInstance -ClassName Win32_PnPSignedDriver | Select-Object DeviceName,Manufacturer,DriverVersion,DriverProviderName,DriverDate,Signer | Format-Table -AutoSize }

    "event_system" = { Get-WinEvent -LogName System -MaxEvents 500 | Format-List TimeCreated,Id,LevelDisplayName,Message }
    "event_application" = { Get-WinEvent -LogName Application -MaxEvents 500 | Format-List TimeCreated,Id,LevelDisplayName,Message }
    "event_security" = { Get-WinEvent -LogName Security -MaxEvents 200 | Format-List TimeCreated,Id,LevelDisplayName,Message }

    "installed_programs" = { Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* , HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* 2>$null | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate | Format-Table -AutoSize }
    "scheduled_tasks" = { schtasks /query /fo LIST /v }
    "autoruns_hint" = { "Wenn Autoruns (Sysinternals) vorhanden ist, führe autoruns.exe /accepteula /nobanner /save <Pfad> aus. Autoruns nicht automatisch heruntergeladen." }

    "unsigned_drivers" = { Get-CimInstance -ClassName Win32_PnPSignedDriver | Where-Object {$_.Signer -eq $null -or $_.Signer -eq ""} | Select-Object DeviceName,Manufacturer,DriverVersion,DriverProviderName,DriverDate | Format-Table -AutoSize }

    "users" = { Get-CimInstance -ClassName Win32_UserAccount | Format-Table Name,SID,Disabled,LocalAccount -AutoSize }
    "disk_info" = { Get-PhysicalDisk | Format-List *; Get-Volume | Format-Table -AutoSize }
    "installed_updates" = { wmic qfe get HotFixID,InstalledOn,Description /format:table }
}

# -------------------------
# Menu-Funktionen
# -------------------------
function Show-AsciiHeader {
    Clear-Host
    # ASCII Art (wie gewünscht)
    Write-Host "    __  __    ___      _                " -ForegroundColor Cyan
    Write-Host "    \ \/ _\  /   \_ __(_)_   _____ _ __ " -ForegroundColor Cyan
    Write-Host "     \ \ \  / /\ / '__| \ \ / / _ \ '__|  " -ForegroundColor Cyan
    Write-Host "  /\_/ /\ \/ /_//| |  | |\ V /  __/ |    " -ForegroundColor Cyan
    Write-Host "  \___/\__/___,' |_|  |_| \_/ \___|_|                         " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "               JSDriver by Neight01" -ForegroundColor Yellow
}

function Show-Header {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "          JSDriver by Neight01           " -ForegroundColor Cyan
    Write-Host " Ausgabe: $outDir" -ForegroundColor Yellow
    Write-Host " Zeitstempel: $timestamp" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
}

function Show-Menu {
    Show-Header
    $i = 1
    foreach ($k in $Tasks.Keys) {
        Write-Host ("[{0}] {1}" -f $i, $k)
        $i++
    }
    Write-Host ""
    Write-Host "[A] Alle ausführen"
    Write-Host "[O] Ausgabeordner öffnen"
    Write-Host "[F] Eine erzeugte Datei öffnen"
    Write-Host "[Z] Zip erstellen"
    Write-Host "[Q] Beenden"
}

function Run-Task-ByIndex {
    param([int]$index)
    if($index -lt 1 -or $index -gt $Tasks.Count) { Write-Host "Ungültige Auswahl"; return }
    $key = $Tasks.Keys[$index - 1]
    Write-Host "=== Starte Task: $key ===" -ForegroundColor Green
    $path = Save-Output $key $Tasks[$key]
    Write-Host "Ergebnis gespeichert in: $path" -ForegroundColor Cyan
}

function Run-All {
    foreach ($k in $Tasks.Keys) {
        Write-Host "=== $k ===" -ForegroundColor Green
        Save-Output $k $Tasks[$k] | Out-Null
    }
    Write-Host "Alle Tasks ausgeführt." -ForegroundColor Cyan
}

function Open-OutputFolder {
    Start-Process explorer.exe $outDir
}

function Open-GeneratedFile {
    $files = Get-ChildItem -Path $outDir -File | Select-Object Name
    if($files.Count -eq 0) { Write-Host "Keine Dateien im Ausgabeordner." ; return }
    Write-Host "Verfügbare Dateien:"
    $j = 1
    foreach ($f in $files) {
        Write-Host ("[{0}] {1}" -f $j, $f.Name)
        $j++
    }
    $sel = Read-Host "Datei-Nummer wählen (oder leer = abbrechen)"
    if(-not [int]::TryParse($sel, [ref]$null)) { return }
    $idx = [int]$sel
    if($idx -lt 1 -or $idx -gt $files.Count) { Write-Host "Ungültige Auswahl"; return }
    $fileToOpen = Join-Path $outDir $files[$idx - 1].Name
    Start-Process notepad.exe $fileToOpen
}

# -------------------------
# Start: ASCII Header anzeigen, kurz warten, dann Menu
# -------------------------
Show-AsciiHeader
Start-Sleep -Seconds 2

# -------------------------
# Hauptloop
# -------------------------
while ($true) {
    Show-Menu
    $choice = Read-Host "Wähle eine Option (Nummer/A/O/F/Z/Q)"
    switch -regex ($choice) {
        '^[0-9]+$' {
            $num = [int]$choice
            Run-Task-ByIndex -index $num
            Pause
        }
        '^[aA]$' {
            Run-All
            # Ordner öffnen nach dem Durchlauf
            Open-OutputFolder
            Pause
        }
        '^[oO]$' {
            Open-OutputFolder
        }
        '^[fF]$' {
            Open-GeneratedFile
            Pause
        }
        '^[zZ]$' {
            $zipPath = Join-Path $env:USERPROFILE\Desktop "JSDriver_$timestamp.zip"
            Zip-Results -targetZip $zipPath
            Write-Host "Zip erstellt: $zipPath" -ForegroundColor Cyan
            Pause
        }
        '^[qQ]$' { break }
        default {
            Write-Host "Ungültige Eingabe."
            Pause
        }
    }
}

Write-Host "Beende JSDriver. Alle Dateien: $outDir"
