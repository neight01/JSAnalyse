# ==============================
# DMA / Environment Check
# Made by Johannes Schwein
# ==============================

Clear-Host

Write-Host ""
Write-Host "   ██████╗ ███╗   ███╗ █████╗     ██████╗ ██╗  ██╗███████╗ ██████╗██╗  ██╗"
Write-Host "   ██╔══██╗████╗ ████║██╔══██╗    ██╔══██╗██║  ██║██╔════╝██╔════╝██║ ██╔╝"
Write-Host "   ██║  ██║██╔████╔██║███████║    ██████╔╝███████║█████╗  ██║     █████╔╝ "
Write-Host "   ██║  ██║██║╚██╔╝██║██╔══██║    ██╔═══╝ ██╔══██║██╔══╝  ██║     ██╔═██╗ "
Write-Host "   ██████╔╝██║ ╚═╝ ██║██║  ██║    ██║     ██║  ██║███████╗╚██████╗██║  ██╗"
Write-Host "   ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝    ╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝"
Write-Host ""
Write-Host "        DMA / Environment Check – Made by Johannes Schwein"
Write-Host ""
Start-Sleep 2

# ------------------------------
# Helper
# ------------------------------
function Print-Progress($msg) {
    Write-Host "[*] $msg" -ForegroundColor Cyan
}

function Parse-VIDPID($text) {
    $vid = ""
    $pid = ""
    if ($text -match "VID_([0-9A-F]{4})") { $vid = $Matches[1] }
    if ($text -match "PID_([0-9A-F]{4})") { $pid = $Matches[1] }

    return @{
        VID = $vid
        PID = $pid
        DeviceHunt = if ($vid -and $pid) {
            "https://devicehunt.com/view/type/usb/vendor/$vid/device/$pid"
        } else { "" }
    }
}

# ------------------------------
# Windows Install Date
# ------------------------------
Print-Progress "Lese Windows Installationsdatum..."
$installDate = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallDate
$installDate = [DateTimeOffset]::FromUnixTimeSeconds($installDate).DateTime

# ------------------------------
# All PnP Devices
# ------------------------------
Print-Progress "Scanne alle Plug&Play Geräte..."
$AllDevices = Get-PnpDevice -PresentOnly | ForEach-Object {
    $ids = Parse-VIDPID $_.InstanceId
    [PSCustomObject]@{
        Name         = $_.FriendlyName
        Class        = $_.Class
        Manufacturer = $_.Manufacturer
        Status       = $_.Status
        InstanceId   = $_.InstanceId
        VID          = $ids.VID
        PID          = $ids.PID
        DeviceHunt   = if ($ids.DeviceHunt) { "<a href='$($ids.DeviceHunt)' target='_blank'>Lookup</a>" } else { "-" }
    }
}

# ------------------------------
# Drivers
# ------------------------------
Print-Progress "Scanne installierte Treiber..."
$Drivers = Get-CimInstance Win32_PnPSignedDriver | Select-Object `
    DeviceName, Manufacturer, DriverVersion, DriverDate, InfName

# ------------------------------
# Kernel / Services
# ------------------------------
Print-Progress "Scanne Kernel-Treiber & Services..."
$Services = Get-CimInstance Win32_SystemDriver | Select-Object `
    Name, State, StartMode, PathName

# ------------------------------
# USB History
# ------------------------------
Print-Progress "Scanne USB-Historie..."
$USBResults = @()
$usbRoots = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB","HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"

foreach ($root in $usbRoots) {
    if (!(Test-Path $root)) { continue }
    Get-ChildItem $root -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $p = Get-ItemProperty $_.PSPath
            $ids = Parse-VIDPID $_.Name

            $USBResults += [PSCustomObject]@{
                Name         = if ($p.FriendlyName) { $p.FriendlyName } else { "Unknown" }
                Manufacturer = if ($p.Mfg) { $p.Mfg } else { "Unknown" }
                Serial       = $_.Name
                VID          = $ids.VID
                PID          = $ids.PID
                DeviceHunt   = if ($ids.DeviceHunt) { "<a href='$($ids.DeviceHunt)' target='_blank'>Lookup</a>" } else { "-" }
            }
        } catch {}
    }
}

# ------------------------------
# Network (LAN only)
# ------------------------------
Print-Progress "Analysiere Netzwerk (LAN)..."
$Network = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
    Where-Object { $_.RemoteAddress -match "^(192\.168|10\.|172\.)" } |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State

# ------------------------------
# HTML
# ------------------------------
Print-Progress "Erstelle HTML Report..."

$style = @"
<style>
body{background:#0e0e0e;color:#eaeaea;font-family:Arial;padding:20px}
h1,h2{color:#ff5555}
table{border-collapse:collapse;width:100%;margin-bottom:25px;font-size:13px}
th,td{border:1px solid #333;padding:4px 6px}
th{background:#1a1a1a}
tr:nth-child(even){background:#141414}
a{color:#6fb6ff;text-decoration:none}
.small{color:#aaa;font-size:12px}
</style>
"@

function To-Table($title,$data) {
    if (!$data) { return "<h2>$title</h2><p>Keine Daten</p>" }
    $html = "<h2>$title</h2><table><tr>"
    $data[0].PSObject.Properties.Name | ForEach-Object { $html += "<th>$_</th>" }
    $html += "</tr>"
    foreach ($row in $data) {
        $html += "<tr>"
        foreach ($p in $row.PSObject.Properties) {
            $html += "<td>$($p.Value)</td>"
        }
        $html += "</tr>"
    }
    $html += "</table>"
    return $html
}

$html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>DMA Environment Check – Johannes Schwein</title>
$style
</head>
<body>

<h1>DMA / Environment Check</h1>
<p class="small">
<b>Made by Johannes Schwein</b><br>
Windows Installationsdatum: $installDate
</p>

$(To-Table "Alle Geräte (PnP)" $AllDevices)
$(To-Table "Installierte Treiber" $Drivers)
$(To-Table "Kernel-Treiber & Services" $Services)
$(To-Table "USB-Historie" $USBResults)
$(To-Table "LAN Netzwerkverbindungen" $Network)

<hr>
<p class="small">Report erstellt am $(Get-Date)</p>

</body>
</html>
"@

$path = "$([Environment]::GetFolderPath('Desktop'))\DMA_Environment_Report_$(Get-Date -Format yyyyMMdd_HHmmss).html"
$html | Out-File $path -Encoding UTF8

Print-Progress "Fertig!"
Start-Process $path
