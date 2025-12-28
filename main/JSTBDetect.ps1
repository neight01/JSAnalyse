Clear-Host

Write-Host ""
Write-Host -ForegroundColor Red "   __  __  _____  ___    ___     _            _   "
Write-Host -ForegroundColor Red "   \ \/ _\/__   \/ __\  /   \___| |_ ___  ___| |_ "
Write-Host -ForegroundColor Red "    \ \ \   / /\/__\// / /\ / _ \ __/ _ \/ __| __|"
Write-Host -ForegroundColor Red " /\_/ /\ \ / / / \/  \/ /_//  __/ ||  __/ (__| |_ "
Write-Host -ForegroundColor Red " \___/\__/ \/  \_____/___,' \___|\__\___|\___|\__|"
Write-Host -ForegroundColor Red "                 Made by Johannes Schwein         "
Write-Host ""
Start-Sleep 2
Clear-Host

# ================= SIGNATURES =================

$PythonSignatures = @(
    @{ regex = 'pyautogui\.(mouseDown|mouseUp|click|moveTo)'; weight = 3 },
    @{ regex = 'pynput\.mouse|pynput\.keyboard'; weight = 3 },
    @{ regex = 'GetPixel\(|GetDC\('; weight = 3 },
    @{ regex = 'mouseDown\(|mouseUp\('; weight = 2 },
    @{ regex = 'time\.sleep\('; weight = 1 }
)

$PowerShellSignatures = @(
    @{ regex = 'Add-Type\s+-MemberDefinition'; weight = 4 },
    @{ regex = 'DllImport\("user32\.dll"\)'; weight = 4 },
    @{ regex = 'mouse_event\(|SendInput\('; weight = 4 },
    @{ regex = 'GetAsyncKeyState'; weight = 3 },
    @{ regex = 'GetPixel\(|GetDC\('; weight = 3 },
    @{ regex = 'CopyFromScreen'; weight = 2 },
    @{ regex = 'System\.Drawing\.Bitmap'; weight = 2 },
    @{ regex = 'while\s*\(\s*\$true\s*\)'; weight = 2 },
    @{ regex = 'Start-Sleep'; weight = 1 }
)

$ConfigKeywords = @(
    "aimbot","triggerbot","smoothing","esp","skeleton",
    "bone","bones","fov","silent","recoil","rcs"
)

# ================= UTILS =================

function Get-AllRoots {
    $roots = @()
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        if (Test-Path $_.Root) { $roots += $_.Root }
    }
    return $roots
}

function Get-Score($matches) {
    $s = 0
    foreach ($m in $matches) { $s += $m.weight }
    return $s
}

# ================= FILE SCAN =================

function Scan-Files {
    param($Roots)

    $results = @()

    foreach ($root in $Roots) {

        Write-Host "Scanne $root ..." -ForegroundColor Yellow

        $files = Get-ChildItem -Path $root -Recurse -Force `
            -Include *.py,*.pyw,*.ps1,*.txt,*.json `
            -ErrorAction SilentlyContinue

        foreach ($file in $files) {

            try {
                $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            } catch { continue }

            $ext = $file.Extension.ToLower()
            $matches = @()

            # PYTHON
            if ($ext -eq ".py" -or $ext -eq ".pyw" -or $ext -eq ".txt") {
                foreach ($sig in $PythonSignatures) {
                    if ($content -match $sig.regex) { $matches += $sig }
                }
            }

            # POWERSHELL
            if ($ext -eq ".ps1" -or $ext -eq ".txt") {
                foreach ($sig in $PowerShellSignatures) {
                    if ($content -match $sig.regex) { $matches += $sig }
                }
            }

            # CONFIG
            if ($ext -eq ".json" -or $ext -eq ".txt") {
                foreach ($k in $ConfigKeywords) {
                    if ($content -match "(?i)\b$k\b") {
                        $matches += @{ regex = "config:$k"; weight = 2 }
                        break
                    }
                }
            }

            if ($matches.Count -gt 0) {
                $results += [PSCustomObject]@{
                    Type     = "File"
                    Target   = $file.FullName
                    Score    = Get-Score $matches
                    Matches  = ($matches.regex -join "; ")
                    Modified = $file.LastWriteTime
                }
            }
        }
    }
    return $results
}

# ================= PROCESS SCAN =================

function Scan-Processes {

    $results = @()

    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(python|pythonw|powershell|pwsh)\.exe$' }

    foreach ($p in $procs) {

        $matches = @()
        $cmd = $p.CommandLine

        foreach ($sig in ($PythonSignatures + $PowerShellSignatures)) {
            if ($cmd -match $sig.regex) { $matches += $sig }
        }

        if ($matches.Count -gt 0) {
            $results += [PSCustomObject]@{
                Type    = "Process"
                Target  = "$($p.Name) (PID $($p.ProcessId))"
                Score   = Get-Score $matches
                Matches = ($matches.regex -join "; ")
            }
        }
    }
    return $results
}

# ================= MAIN =================

$start = Get-Date
Write-Host "Starte JSTBDetect Scan..." -ForegroundColor Cyan

$all = @()
$all += Scan-Files (Get-AllRoots)
$all += Scan-Processes

if ($all.Count -eq 0) {
    Write-Host "Keine verdächtigen Inhalte gefunden." -ForegroundColor Green
    return
}

$all = $all | Sort-Object Score -Descending

# ================= REPORT =================

$desktop = [Environment]::GetFolderPath("Desktop")
$report = Join-Path $desktop ("JSTBDetect_Report_{0:yyyyMMdd_HHmmss}.html" -f (Get-Date))

$html = @"
<html>
<head>
<meta charset='utf-8'>
<style>
body{background:#111;color:#eee;font-family:Arial}
table{border-collapse:collapse;width:100%}
th,td{border:1px solid #444;padding:6px}
th{background:#222}
</style>
</head>
<body>
<h1>JSTBDetect Report</h1>
<p>Start: $start<br>Ende: $(Get-Date)</p>
<table>
<tr><th>Typ</th><th>Ziel</th><th>Score</th><th>Matches</th></tr>
"@

foreach ($r in $all) {
    $html += "<tr><td>$($r.Type)</td><td>$($r.Target)</td><td>$($r.Score)</td><td>$($r.Matches)</td></tr>"
}

$html += "</table></body></html>"
$html | Out-File -Encoding UTF8 -FilePath $report
Start-Process $report
