# =====================================================
# DMA / Environment Check
# Made by Johannes Schwein
# =====================================================
Clear-Host

Write-Host ""
Write-Host "   DMA / Environment Check"
Write-Host "   Made by Johannes Schwein"
Write-Host ""
Start-Sleep 2

function Print-Progress($msg) {
    Write-Host "[*] $msg" -ForegroundColor Cyan
}

# ------------------------------
# Windows Install Date
# ------------------------------
Print-Progress "Lese Windows Installationsdatum..."
$installDateRaw = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallDate
$installDate = [DateTimeOffset]::FromUnixTimeSeconds($installDateRaw).DateTime

# ------------------------------
# PnP Devices (über WMI / CIM)
# ------------------------------
function Parse-VIDPID($text) {
    $vid=""; $devPID=""
    if ($text -match "VID_([0-9A-F]{4})") { $vid=$Matches[1] }
    if ($text -match "PID_([0-9A-F]{4})") { $devPID=$Matches[1] }
    return @{
        VID = $vid
        PID = $devPID
        DeviceHunt = if ($vid -and $devPID) {
            "https://devicehunt.com/view/type/usb/vendor/$vid/device/$devPID"
        } else { "" }
    }
}

Print-Progress "Scanne alle PnP-Geräte..."
$PnPDevices = Get-CimInstance Win32_PnPEntity | ForEach-Object {
    $ids = Parse-VIDPID $_.PNPDeviceID
    [PSCustomObject]@{
        Name = if ($_.Name) { $_.Name } else { "Unknown" }
        Class = $_.PNPClass
        Manufacturer = if ($_.Manufacturer) { $_.Manufacturer } else { "Unknown" }
        Status = if ($_.Status) { $_.Status } else { "Unknown" }
        InstanceId = $_.PNPDeviceID
        VID = $ids.VID
        DevicePID = $ids.PID
        DeviceHunt = if ($ids.DeviceHunt) { "<a href='$($ids.DeviceHunt)' target='_blank'>Lookup</a>" } else { "-" }
    }
}

# ------------------------------
# Kernel Drivers ONLY
# ------------------------------
Print-Progress "Scanne Kernel-Treiber..."
$KernelDrivers = Get-CimInstance Win32_SystemDriver |
    Where-Object { $_.ServiceType -like "*Kernel*" } |
    Select-Object Name, State, StartMode, PathName

# ------------------------------
# Windows Services
# ------------------------------
Print-Progress "Scanne Windows Services..."
$ImportantServices = @("DiagTrack","SysMain","EventLog","DPS","WSearch")
$Services = Get-CimInstance Win32_Service | ForEach-Object {
    $flag = ""
    if ($ImportantServices -contains $_.Name -and $_.State -ne "Running") { $flag="IMPORTANT SERVICE DISABLED" }
    [PSCustomObject]@{
        Name = $_.Name
        DisplayName = $_.DisplayName
        State = $_.State
        StartMode = $_.StartMode
        Flag = $flag
        Path = $_.PathName
    }
}

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
                Name = if ($p.FriendlyName) { $p.FriendlyName } else { "Unknown" }
                Manufacturer = if ($p.Mfg) { $p.Mfg } else { "Unknown" }
                Serial = $_.Name
                VID = $ids.VID
                DevicePID = $ids.PID
                DeviceHunt = if ($ids.DeviceHunt) { "<a href='$($ids.DeviceHunt)' target='_blank'>Lookup</a>" } else { "-" }
            }
        } catch {}
    }
}

# ------------------------------
# LAN Connections
# ------------------------------
Print-Progress "Analysiere LAN Netzwerk..."
$Network = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
    Where-Object { $_.RemoteAddress -match "^(192\.168|10\.|172\.)" } |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State

# ------------------------------
# HTML Helpers
# ------------------------------
function To-Table($title,$data,$rowClassScript) {
    if (!$data -or $data.Count -eq 0) { return "<h2>$title</h2><p>Keine Daten</p>" }
    $html = "<h2>$title</h2><table><tr>"
    $data[0].PSObject.Properties.Name | ForEach-Object { $html += "<th>$_</th>" }
    $html += "</tr>"
    foreach ($row in $data) {
        $cls = if ($rowClassScript) { & $rowClassScript $row } else { "" }
        $html += "<tr class='$cls'>"
        foreach ($p in $row.PSObject.Properties) { $html += "<td>$($p.Value)</td>" }
        $html += "</tr>"
    }
    $html += "</table>"
    return $html
}

# ------------------------------
# HTML Report
# ------------------------------
Print-Progress "Erstelle HTML Report..."

$style = @"
<style>
body{background:#0e0e0e;color:#eaeaea;font-family:Arial;padding:20px}
h1,h2{color:#ff5555}
table{border-collapse:collapse;width:100%;margin-bottom:20px;font-size:12px}
th,td{border:1px solid #333;padding:3px 6px;vertical-align:top}
th{background:#1a1a1a}
tr:nth-child(even){background:#141414}
.running{background:#102010}
.stopped{background:#2a1010}
.flagged{background:#3a2a00}
a{color:#6fb6ff;text-decoration:none}
.small{font-size:12px;color:#aaa}
</style>
"@

$html = @"
<!doctype html>
<html>
<head>
<meta charset='utf-8'>
<title>DMA Environment Check – Johannes Schwein</title>
$style
</head>
<body>

<h1>DMA / Environment Check</h1>
<p class='small'><b>Made by Johannes Schwein</b><br>Windows Installationsdatum: $installDate</p>

$(To-Table "Alle PnP-Geräte" $PnPDevices $null)
$(To-Table "Kernel-Treiber" $KernelDrivers { param($r) if ($r.State -ne 'Running'){ 'stopped' } else { 'running' } })
$(To-Table "Windows Services" $Services { param($r) if ($r.Flag){ 'flagged' } elseif ($r.State -ne 'Running'){ 'stopped' } else { 'running' } })
$(To-Table "USB-Historie" $USBResults $null)
$(To-Table "LAN Netzwerkverbindungen" $Network $null)

<hr><p class='small'>Report erstellt am $(Get-Date)</p>

</body>
</html>
"@

$path = "$([Environment]::GetFolderPath('Desktop'))\DMA_Environment_Report_$(Get-Date -Format yyyyMMdd_HHmmss).html"
$html | Out-File $path -Encoding UTF8

Print-Progress "Fertig – öffne Report"
Start-Process $path
