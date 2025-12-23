Clear-Host
Write-Host ""
Write-Host -ForegroundColor Red "   ____  __  __    ___      ________  ___ "
Write-Host -ForegroundColor Red "  / __ \/ / / /   /   |    / ____/  |/  / "
Write-Host -ForegroundColor Red " / / / / / / /   / /| |   / /   / /|_/ /  "
Write-Host -ForegroundColor Red "/ /_/ / /_/ /   / ___ |  / /___/ /  / /   "
Write-Host -ForegroundColor Red "\___\_\____/   /_/  |_|  \____/_/  /_/    "
Write-Host -ForegroundColor Red "        DMA Environment Check"
Write-Host ""
Start-Sleep 3
Clear-Host

# ================= CONFIG =================
$Keywords = @(
    "dma","pcie","fpga","leech","memory","mem",
    "scatter","kernel","rwdrv","winio","portio",
    "inpout","phys","bar0"
)

function Get-Score {
    param($Text)
    $score = 0
    foreach ($k in $Keywords) {
        if ($Text -match $k) { $score += 2 }
    }
    return $score
}

$driverResults = @()
$deviceResults = @()
$serviceResults = @()

# ================= DRIVERS =================
$drivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue
foreach ($d in $drivers) {
    $text = "$($d.DeviceName) $($d.DriverName) $($d.Manufacturer)"
    $score = Get-Score $text

    if (-not $d.IsSigned) { $score += 4 }
    if ($d.Manufacturer -eq "" -or $d.Manufacturer -eq "Unknown") { $score += 2 }

    if ($score -gt 0) {
        $driverResults += [PSCustomObject]@{
            Type = "Driver"
            Name = $d.DeviceName
            Manufacturer = $d.Manufacturer
            Signed = $d.IsSigned
            Driver = $d.DriverName
            Score = $score
        }
    }
}

# ================= PCI DEVICES =================
$devices = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match "^PCI" }
foreach ($dev in $devices) {
    $text = "$($dev.Name) $($dev.DeviceID)"
    $score = Get-Score $text
    if ($score -gt 0) {
        $deviceResults += [PSCustomObject]@{
            Type = "PCI Device"
            Name = $dev.Name
            DeviceID = $dev.DeviceID
            Score = $score
        }
    }
}

# ================= SERVICES =================
$services = Get-CimInstance Win32_SystemDriver
foreach ($s in $services) {
    $text = "$($s.Name) $($s.DisplayName) $($s.PathName)"
    $score = Get-Score $text
    if ($score -gt 0) {
        $serviceResults += [PSCustomObject]@{
            Type = "Kernel Service"
            Name = $s.Name
            Path = $s.PathName
            State = $s.State
            Score = $score
        }
    }
}

# ================= HTML REPORT =================
$all = $driverResults + $deviceResults + $serviceResults
$all = $all | Sort-Object Score -Descending

$desktop = [Environment]::GetFolderPath("Desktop")
$path = Join-Path $desktop ("DMA_Check_{0:yyyyMMdd_HHmmss}.html" -f (Get-Date))

$html = @"
<html>
<head>
<title>DMA Environment Check</title>
<style>
body { background:#111; color:#eee; font-family:Arial; }
table { width:100%; border-collapse:collapse; }
th,td { border:1px solid #444; padding:6px; }
th { background:#222; }
tr:nth-child(even){background:#1a1a1a;}
h1 { color:#ff5555; }
</style>
</head>
<body>
<h1>DMA Environment Scan</h1>
<p><b>Total findings:</b> $($all.Count)</p>
<table>
<tr><th>Type</th><th>Name</th><th>Details</th><th>Score</th></tr>
"@

foreach ($r in $all) {
    $details = ($r | Out-String)
    $html += "<tr><td>$($r.Type)</td><td>$($r.Name)</td><td><pre>$details</pre></td><td>$($r.Score)</td></tr>"
}

$html += "</table><p>Generated: $(Get-Date)</p></body></html>"

$html | Out-File $path -Encoding UTF8
Start-Process $path

Write-Host "Report erstellt: $path" -ForegroundColor Green
