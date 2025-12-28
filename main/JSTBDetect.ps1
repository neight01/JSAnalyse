Clear-Host
Write-Host ""
Write-Host -ForegroundColor Red "   __  __  _____  ___    ___     _            _   "
Write-Host -ForegroundColor Red "   \ \/ _\/__   \/ __\  /   \___| |_ ___  ___| |_ "
Write-Host -ForegroundColor Red "    \ \ \   / /\/__\// / /\ / _ \ __/ _ \/ __| __|"
Write-Host -ForegroundColor Red " /\_/ /\ \ / / / \/  \/ /_//  __/ ||  __/ (__| |_ "
Write-Host -ForegroundColor Red " \___/\__/ \/  \_____/___,' \___|\__\___|\___|\__|"
Write-Host -ForegroundColor Red "                 Made by Johannes Schwein         "
Write-Host ""
Start-Sleep 3
Clear-Host

# ================= SIGNATURES (PY + TXT) =================
$CodeSignatures = @(
    @{ regex = 'pyautogui\.(mouseDown|mouseUp|click|moveTo)'; weight = 3 },
    @{ regex = 'GetPixel\(|gdi32|GetDC\('; weight = 3 },
    @{ regex = 'pynput\.mouse|pynput\.keyboard'; weight = 3 },
    @{ regex = 'mouseDown\(|mouseUp\('; weight = 2 },
    @{ regex = 'time\.sleep\(|random\.uniform\('; weight = 1 },
    @{ regex = 'pyautogui\.pixel|screenshot'; weight = 2 }
)

# ================= CONFIG KEYWORDS (JSON + TXT) =================
$ConfigKeywords = @(
    "aimbot",
    "smoothing",
    "esp",
    "skeleton",
    "bone",
    "bones",
    "fov",
    "triggerbot",
    "silent",
    "recoil",
    "rcs"
)

# ================= UTILS =================
function Get-AllRoots {
    Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path $_.Root } | ForEach-Object { $_.Root }
}

function Score-Matches($matches) {
    ($matches | Measure-Object weight -Sum).Sum
}

# ================= FILE SCAN =================
function Scan-Files {
    param($Roots)

    $results = @()

    foreach ($root in $Roots) {
        Write-Host "Scanne $root ..." -ForegroundColor Yellow

        $files = Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue `
            -Include *.py,*.pyw,*.txt,*.json

        foreach ($file in $files) {

            try {
                $content = Get-Content $file.FullName -Raw -ErrorAction Stop
            } catch { continue }

            $ext = $file.Extension.ToLower()
            $matches = @()

            # -------- CODE DETECTION (.py + .txt)
            if ($ext -in @(".py", ".pyw", ".txt")) {
                foreach ($sig in $CodeSignatures) {
                    if ($content -match $sig.regex) {
                        $matches += $sig
                    }
                }
            }

            # -------- CONFIG DETECTION (.json + .txt)
            if ($ext -in @(".json", ".txt")) {
                foreach ($key in $ConfigKeywords) {
                    if ($content -match "(?i)\b$key\b") {
                        $matches += @{ regex = "config:$key"; weight = 2 }
                        break
                    }
                }
            }

            if ($matches.Count -gt 0) {
                $results += [PSCustomObject]@{
                    Type      = "File"
                    Path      = $file.FullName
                    FileName  = $file.Name
                    Extension = $ext
                    Score     = Score-Matches $matches
                    Matches   = ($matches.regex -join "; ")
                    LastWrite = $file.LastWriteTime
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
        Where-Object { $_.Name -match '^pythonw?\.exe$' }

    foreach ($p in $procs) {
        $cmd = $p.CommandLine
        $matches = @()

        foreach ($sig in $CodeSignatures) {
            if ($cmd -match $sig.regex) {
                $matches += $sig
            }
        }

        if ($matches.Count -gt 0) {
            $results += [PSCustomObject]@{
                Type = "Process"
                PID  = $p.ProcessId
                Name = $p.Name
                Score = Score-Matches $matches
                Matches = ($matches.regex -join "; ")
                CommandLine = $cmd
            }
        }
    }

    return $results
}

# ================= MAIN =================
$start = Get-Date
Write-Host "Starte Scan..." -ForegroundColor Cyan

$roots = Get-AllRoots
$fileResults = Scan-Files $roots
$procResults = Scan-Processes

$all = $fileResults + $procResults | Sort-Object Score -Descending

if ($all.Count -eq 0) {
    Write-Host "Keine verdächtigen Dateien oder Prozesse gefunden." -ForegroundColor Green
    return
}

# ================= REPORT =================
$desktop = [Environment]::GetFolderPath("Desktop")
$path = Join-Path $desktop ("Triggerbot_Report_{0:yyyyMMdd_HHmmss}.html" -f (Get-Date))

$html = @"
<html><head><style>
body{background:#111;color:#eee;font-family:Arial}
table{border-collapse:collapse;width:100%}
th,td{border:1px solid #444;padding:6px}
th{background:#222}
</style></head><body>
<h1>Triggerbot Scan Report</h1>
<p>Start: $start<br>Ende: $(Get-Date)</p>
<table>
<tr><th>Typ</th><th>Pfad / Prozess</th><th>Score</th><th>Matches</th></tr>
"@

foreach ($r in $all) {
    $html += "<tr><td>$($r.Type)</td><td>$($r.Path ?? $r.Name)</td><td>$($r.Score)</td><td>$($r.Matches)</td></tr>"
}

$html += "</table></body></html>"
$html | Out-File $path -Encoding UTF8
Start-Process $path
