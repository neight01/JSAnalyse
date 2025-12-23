# ================= HEADER =================
Clear-Host
Write-Host ""
Write-Host -ForegroundColor Red "   __  __  _____  ___    ___     _            _   "
Write-Host -ForegroundColor Red "   \ \/ _\/__   \/ __\  /   \___| |_ ___  ___| |_ "
Write-Host -ForegroundColor Red "    \ \ \   / /\/__\// / /\ / _ \ __/ _ \/ __| __|"
Write-Host -ForegroundColor Red " /\_/ /\ \ / / / \/  \/ /_//  __/ ||  __/ (__| |_ "
Write-Host -ForegroundColor Red " \___/\__/ \/  \_____/___,' \___|\__\___|\___|\__|"
Write-Host -ForegroundColor Red "                                                  "
Write-Host -ForegroundColor Red "            DMA Environment Check"
Write-Host -ForegroundColor Red "               Made by Johannes Schwein"
Write-Host ""
Start-Sleep 3
Clear-Host

$StartTime = Get-Date

function Print-Progress($msg) {
    Write-Host "[*] $msg" -ForegroundColor Cyan
}

# ================= KEYWORDS =================
$Keywords = @(
    "dma","pcie","fpga","leech","mem","memory","scatter",
    "rwdrv","winio","portio","inpout","phys","bar0","kernel"
)

function Get-ScoreAndReason($Text) {
    $score = 0
    $reasons = @()
    foreach ($k in $Keywords) {
        if ($Text -match $k) {
            $score += 2
            $reasons += "Keyword: $k"
        }
    }
    return @{ Score = $score; Reason = ($reasons -join ", ") }
}

# ================= WINDOWS INSTALL DATE =================
Print-Progress "Lese Windows Installationsdatum..."
$installRaw = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallDate
$WindowsInstallDate = [DateTimeOffset]::FromUnixTimeSeconds($installRaw).DateTime
$WindowsInstallAgeDays = (New-TimeSpan -Start $WindowsInstallDate -End (Get-Date)).Days

# ================= RESULTS =================
$AllDevices   = @()
$Drivers      = @()
$Services     = @()
$USBHistory   = @()
$NetworkInfo  = @()

# ================= ALL DEVICES (PnP) =================
Print-Progress "Scanne ALLE Geräte (PnP)..."
$devices = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue
$i = 0
foreach ($d in $devices) {
    $i++
    Write-Host "    -> Gerät $i / $($devices.Count)" -ForegroundColor DarkGray

    $text = "$($d.Name) $($d.Manufacturer) $($d.PNPDeviceID)"
    $res = Get-ScoreAndReason $text
    $score = $res.Score
    $reason = $res.Reason

    if (-not $d.Manufacturer -or $d.Manufacturer -eq "Unknown") {
        $score += 2
        $reason += ", Unknown Manufacturer"
    }

    if ($score -gt 0) {
        $AllDevices += [PSCustomObject]@{
            Name = $d.Name
            Class = $d.PNPClass
            Manufacturer = $d.Manufacturer
            DeviceID = $d.PNPDeviceID
            Status = $d.Status
            Score = $score
            Reason = $reason
        }
    }
}

# ================= DRIVERS =================
Print-Progress "Scanne installierte Treiber..."
$drivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue
$i = 0
foreach ($dr in $drivers) {
    $i++
    Write-Host "    -> Treiber $i / $($drivers.Count)" -ForegroundColor DarkGray

    $text = "$($dr.DeviceName) $($dr.DriverName) $($dr.Manufacturer)"
    $res = Get-ScoreAndReason $text
    $score = $res.Score
    $reason = $res.Reason

    if (-not $dr.IsSigned) {
        $score += 4
        $reason += ", Unsigned Driver"
    }
    if (-not $dr.Manufacturer -or $dr.Manufacturer -eq "Unknown") {
        $score += 2
        $reason += ", Unknown Manufacturer"
    }

    if ($score -gt 0) {
        $Drivers += [PSCustomObject]@{
            Device = $dr.DeviceName
            Manufacturer = $dr.Manufacturer
            Signed = $dr.IsSigned
            DriverFile = $dr.DriverName
            Score = $score
            Reason = $reason
        }
    }
}

# ================= KERNEL SERVICES =================
Print-Progress "Scanne Kernel-Services..."
$services = Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue
$i = 0
foreach ($s in $services) {
    $i++
    Write-Host "    -> Service $i / $($services.Count)" -ForegroundColor DarkGray

    $text = "$($s.Name) $($s.DisplayName) $($s.PathName)"
    $res = Get-ScoreAndReason $text

    if ($res.Score -gt 0) {
        $Services += [PSCustomObject]@{
            Name = $s.Name
            Path = $s.PathName
            State = $s.State
            Score = $res.Score
            Reason = $res.Reason
        }
    }
}

# ================= USB HISTORY =================
Print-Progress "Scanne USB-Historie..."
$usbRoots = @(
    "HKLM:\SYSTEM\CurrentControlSet\Enum\USB",
    "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
)

foreach ($root in $usbRoots) {
    if (-not (Test-Path $root)) { continue }
    $items = Get-ChildItem $root -Recurse -ErrorAction SilentlyContinue
    $i = 0
    foreach ($it in $items) {
        $i++
        Write-Host "    -> USB-Eintrag $i" -ForegroundColor DarkGray
        try {
            $p = Get-ItemProperty $it.PSPath -ErrorAction Stop
            $name = $p.FriendlyName
            $mfg  = $p.Mfg
            $text = "$name $mfg $($it.Name)"
            $res = Get-ScoreAndReason $text
            $score = $res.Score
            $reason = $res.Reason

            if (-not $name) { $score += 2; $reason += ", No FriendlyName" }
            if (-not $mfg -or $mfg -eq "Unknown") { $score += 2; $reason += ", Unknown Manufacturer" }

            if ($score -gt 0) {
                $USBHistory += [PSCustomObject]@{
                    Name = $name
                    Manufacturer = $mfg
                    RegistryKey = $it.Name
                    Score = $score
                    Reason = $reason
                }
            }
        } catch {}
    }
}

# ================= NETWORK / LAN =================
Print-Progress "Analysiere Netzwerk (LAN)..."
$conns = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue
$i = 0
foreach ($c in $conns) {
    $i++
    Write-Host "    -> Verbindung $i / $($conns.Count)" -ForegroundColor DarkGray
    if ($c.RemoteAddress -match "^(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[0-1]))") {
        $NetworkInfo += [PSCustomObject]@{
            LocalAddress  = $c.LocalAddress
            LocalPort     = $c.LocalPort
            RemoteAddress = $c.RemoteAddress
            RemotePort    = $c.RemotePort
            State         = $c.State
            Note          = "Local LAN Connection"
        }
    }
}

$adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
foreach ($a in $adapters) {
    if ($a.Status -eq "Up") {
        $NetworkInfo += [PSCustomObject]@{
            LocalAddress  = $a.Name
            LocalPort     = "-"
            RemoteAddress = "-"
            RemotePort    = "-"
            State         = $a.Status
            Note          = "Active Network Adapter"
        }
    }
}

# ================= HTML BUILD =================
function Build-Table($title, $data) {
    if (-not $data -or $data.Count -eq 0) {
        return "<h2>$title</h2><p>Keine Auffälligkeiten</p>"
    }
    $html = "<h2>$title</h2><table><tr>"
    foreach ($p in $data[0].PSObject.Properties.Name) { $html += "<th>$p</th>" }
    $html += "</tr>"
    foreach ($row in $data) {
        $html += "<tr>"
        foreach ($p in $row.PSObject.Properties) { $html += "<td>$($p.Value)</td>" }
        $html += "</tr>"
    }
    return $html + "</table>"
}

$EndTime = Get-Date
$desktop = [Environment]::GetFolderPath("Desktop")
$path = Join-Path $desktop ("DMA_Check_Johannes_Schwein_{0:yyyyMMdd_HHmmss}.html" -f $EndTime)

$html = @"
<html>
<head>
<title>DMA Environment Check - Johannes Schwein</title>
<style>
body { background:#111; color:#eee; font-family:Arial; padding:20px; }
table { border-collapse:collapse; width:100%; margin-bottom:25px; }
th,td { border:1px solid #444; padding:6px; }
th { background:#222; }
tr:nth-child(even){background:#1a1a1a;}
h1 { color:#ff5555; }
h2 { color:#9ad68b; }
</style>
</head>
<body>
<h1>DMA Environment Check</h1>
<p><b>Made by Johannes Schwein</b></p>

<p>
<b>Windows Installationsdatum:</b> $WindowsInstallDate<br>
<b>Windows Alter:</b> $WindowsInstallAgeDays Tage
</p>

<p>
Scan Start: $StartTime<br>
Scan Ende: $EndTime<br>
Laufzeit: $([Math]::Round(($EndTime - $StartTime).TotalSeconds,2)) Sekunden
</p>

<hr>
$(Build-Table "Alle Geräte (PnP)" $AllDevices)
$(Build-Table "Installierte Treiber" $Drivers)
$(Build-Table "Kernel-Services" $Services)
$(Build-Table "USB-Historie" $USBHistory)
$(Build-Table "Netzwerk / LAN" $NetworkInfo)

<hr>
<p><i>Hinweis: Dieses Tool liefert Indizien, keinen Beweis.</i></p>
</body>
</html>
"@

$html | Out-File $path -Encoding UTF8
Start-Process $path

Write-Host "`n[✓] Scan abgeschlossen." -ForegroundColor Green
Write-Host "[✓] HTML-Report erstellt:" -ForegroundColor Green
Write-Host $path -ForegroundColor Yellow
