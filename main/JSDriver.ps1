# ===================== HEADER =====================
function Show-AsciiHeader {
    Clear-Host
    Write-Host "    __  __    ___      _                " -ForegroundColor Cyan
    Write-Host "    \ \/ _\  /   \_ __(_)_   _____ _ __ " -ForegroundColor Cyan
    Write-Host "     \ \ \  / /\ / '__| \ \ / / _ \ '__|" -ForegroundColor Cyan
    Write-Host "  /\_/ /\ \/ /_//| |  | |\ V /  __/ |   " -ForegroundColor Cyan
    Write-Host "  \___/\__/___,' |_|  |_| \_/ \___|_|   " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "              JSDriver by Neight01" -ForegroundColor Yellow
    Write-Host ""
}

Show-AsciiHeader
Start-Sleep 2

# ===================== SETUP =====================
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outDir = "$env:USERPROFILE\Desktop\JSDriver_$timestamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$results = @()

# ===================== HELPER =====================
function Run-Task {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host "-> Sammle $Name ..." -ForegroundColor Cyan
    $txtPath = Join-Path $outDir "$Name.txt"

    try {
        $output = & $Command *>&1
        $output | Out-File $txtPath -Encoding UTF8
    } catch {
        $_ | Out-File $txtPath -Encoding UTF8
    }

    $results += [PSCustomObject]@{
        Name = $Name
        File = $txtPath
    }
}

# ===================== TASKS (JEWEILS NUR EINMAL) =====================
Run-Task "hostname"            { hostname }
Run-Task "systeminfo"          { systeminfo }
Run-Task "bios"                { Get-CimInstance Win32_BIOS | Format-List * }
Run-Task "computer_system"     { Get-CimInstance Win32_ComputerSystem | Format-List * }
Run-Task "processes"           { Get-Process | Sort CPU -Descending | Format-Table -AutoSize }
Run-Task "services"            { Get-Service | Where Status -ne Stopped | Format-Table -AutoSize }
Run-Task "netstat"             { netstat -ano }
Run-Task "network_adapters"    { Get-NetAdapter | Format-Table -AutoSize }
Run-Task "ipconfig"            { ipconfig /all }
Run-Task "drivers"             { driverquery /v }
Run-Task "signed_drivers"      { Get-CimInstance Win32_PnPSignedDriver | Format-Table DeviceName,DriverVersion,Signer -AutoSize }
Run-Task "scheduled_tasks"     { schtasks /query /fo LIST /v }
Run-Task "users"               { Get-CimInstance Win32_UserAccount | Format-Table Name,SID,Disabled -AutoSize }
Run-Task "disks"               { Get-PhysicalDisk; Get-Volume }

# ===================== HTML REPORT =====================
$reportPath = Join-Path $outDir "JSDriver_Report.html"

$html = @"
<html>
<head>
<title>JSDriver Report</title>
<style>
body { font-family: Arial; background:#111; color:#eee; padding:20px }
h1 { color:#4fc3f7 }
table { border-collapse: collapse; width:100% }
th, td { border:1px solid #444; padding:8px }
th { background:#222 }
a { color:#81d4fa }
</style>
</head>
<body>
<h1>JSDriver System Report</h1>
<p><b>Erstellt:</b> $(Get-Date)</p>
<table>
<tr><th>Task</th><th>Datei</th></tr>
"@

foreach ($r in $results) {
    $name = $r.Name
    $file = Split-Path $r.File -Leaf
    $html += "<tr><td>$name</td><td><a href='$file'>$file</a></td></tr>"
}

$html += "</table></body></html>"

$html | Out-File $reportPath -Encoding UTF8

# ===================== FERTIG =====================
Write-Host ""
Write-Host "Scan abgeschlossen." -ForegroundColor Green
Write-Host "Report: $reportPath" -ForegroundColor Green

Start-Process $reportPath
