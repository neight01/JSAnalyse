# ===============================
# JSTBDetect.ps1 (PS 5.1 SAFE)
# ===============================

$ScanPath = [Environment]::GetFolderPath("Desktop")

$Extensions = @(".js", ".txt", ".json", ".ps1", ".py")

$CheatKeywordsGeneral = @(
    "triggerbot",
    "aimbot",
    "mouse_event",
    "SendInput",
    "SetCursorPos",
    "GetAsyncKeyState",
    "pyautogui",
    "pynput",
    "mouse.move",
    "mouse.click"
)

$CheatKeywordsConfig = @(
    "smoothing",
    "esp",
    "skeleton",
    "fov",
    "aim_key",
    "bone",
    "head",
    "chest"
)

$Results = @()

function Get-SafeText {
    param ($Path)
    try {
        return Get-Content $Path -Raw -ErrorAction Stop
    } catch {
        return ""
    }
}

Get-ChildItem -Path $ScanPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $Extensions -contains $_.Extension.ToLower()
} | ForEach-Object {

    $File = $_
    $Content = Get-SafeText $File.FullName
    if ($Content -eq "") { return }

    foreach ($kw in $CheatKeywordsGeneral) {
        if ($Content -match [regex]::Escape($kw)) {
            $Results += [PSCustomObject]@{
                Type = "Cheat Keyword"
                Name = $File.Name
                Path = $File.FullName
                Keyword = $kw
            }
        }
    }

    if ($File.Extension -in @(".json", ".txt")) {
        foreach ($kw in $CheatKeywordsConfig) {
            if ($Content -match [regex]::Escape($kw)) {
                $Results += [PSCustomObject]@{
                    Type = "Cheat Config"
                    Name = $File.Name
                    Path = $File.FullName
                    Keyword = $kw
                }
            }
        }
    }
}

# ===============================
# HTML REPORT
# ===============================

$html = @"
<html>
<head>
<title>JSTB Detect Report</title>
<style>
body { font-family: Arial; background:#111; color:#eee }
table { border-collapse: collapse; width:100% }
th,td { border:1px solid #555; padding:6px }
th { background:#222 }
tr:nth-child(even){background:#1b1b1b}
</style>
</head>
<body>
<h2>JSTB Detection Report</h2>
<table>
<tr>
<th>Type</th>
<th>File</th>
<th>Keyword</th>
</tr>
"@

foreach ($r in $Results) {
    $fileName = ""
    if ($r.Path -ne $null -and $r.Path -ne "") {
        $fileName = $r.Path
    } else {
        $fileName = $r.Name
    }

    $html += "<tr><td>$($r.Type)</td><td>$fileName</td><td>$($r.Keyword)</td></tr>"
}

$html += "</table></body></html>"

$OutFile = "$env:TEMP\JSTBDetect_Report.html"
$html | Out-File -Encoding UTF8 $OutFile

Start-Process $OutFile
