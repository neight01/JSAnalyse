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

# ================= PYTHON SIGNATURES =================
$PythonSignatures = @(
    @{ regex = 'pyautogui\.(mouseDown|mouseUp|click|moveTo)'; weight = 3 },
    @{ regex = 'pynput\.mouse|pynput\.keyboard'; weight = 3 },
    @{ regex = 'GetPixel\(|GetDC\('; weight = 3 },
    @{ regex = 'time\.sleep\('; weight = 1 },
    @{ regex = 'mouseDown\(|mouseUp\('; weight = 2 }
)

# ================= POWERSHELL SIGNATURES =================
$PowerShellSignatures = @(
    @{ regex = 'Add-Type\s+-MemberDefinition'; weight = 4 },
    @{ regex = 'DllImport\("user32\.dll"\)'; weight = 4 },
    @{ regex = 'mouse_event\(|SendInput\('; weight = 4 },
    @{ regex = 'GetAsyncKeyState'; weight = 3 },
    @{ regex = 'GetDC\(|GetPixel\('; weight = 3 },
    @{ regex = 'CopyFromScreen'; weight = 2 },
    @{ regex = 'System\.Drawing\.Bitmap'; weight = 2 },
    @{ regex = 'while\s*\(\s*\$true\s*\)'; weight = 2 },
    @{ regex = 'Start-Sleep'; weight = 1 }
)

# ================= CONFIG KEYWORDS =================
$ConfigKeywords = @(
    "aimbot",
    "triggerbot",
    "smoothing",
    "esp",
    "skeleton",
    "bone",
    "bones",
    "fov",
    "silent",
    "recoil",
    "rcs"
)

# ================= UTILS =================
function Get-AllRoots {
    Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path $_.Root } | ForEach-Object { $_.Root }
}

function Get-Score($matches) {
    ($matches | Measure-Object weight -Sum).Sum
}

# ================= FILE SCAN =================
function Scan-Files {
    param($Roots)

    $results = @()

    foreach ($root in $Roots) {
        Write-Host "Scanne $root ..." -ForegroundColor Yellow

        $files = Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue `
            -Include *.py,*.pyw,*.ps1,*.txt,*.json

        foreach ($file in $files) {

            try { $content = Get-Content $file.FullName -Raw -ErrorAction Stop }
            catch { continue }

            $ext = $file.Extension.ToLower()
            $matches = @()

            # ---- PYTHON CODE
            if ($ext -in @(".py", ".pyw", ".txt")) {
                foreach ($sig in $PythonSignatures) {
                    if ($content -match $sig.regex) { $matches += $sig }
                }
            }

            # ---- POWERSHELL CODE
            if ($ext -in @(".ps1", ".txt")) {
                foreach ($sig in $PowerShellSignatures) {
                    if ($content -match $sig.regex) { $matches += $sig }
                }
            }

            # ---- CONFIG FILES
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
                    Extension = $ext
                    Score     = Get-Score $matches
                    Matches   = ($matches.regex -join "; ")
                    Modified  = $file.LastWriteTime
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

        foreach ($sig in $PythonSignatures + $PowerShellSignatures) {
            if ($cmd -match $sig.regex) { $matches += $sig }
        }

        if ($matches.Count -gt 0) {
            $results += [PSCustomObject]@{
                Type        = "Process"
                PID         = $p.ProcessId
                Name        = $p.Name
                Score       = Get-Score $matches
                Matches     = ($matches.regex -join "; ")
                CommandLine = $cmd
            }
        }
    }
    return $results
}

# ================= MAIN =================
$start = Get-Date
Write-Host "Starte Triggerbot Scan..." -ForegroundColor Cyan

$roots = Get-AllRoots
$fileResults = Scan-Files $roots
$procResults = Scan-Processes

$all = $fileResults + $procResults | Sort-Object Score -Descending

if ($all.Count -eq 0) {
    Write-Host "Keine verdächtigen Inhalte gefunden." -ForegroundColor Green
    return
}

# ================= REPORT =================
$desktop = [Environment]::GetFolderPath("Desktop")
$report = Join-Path $desktop ("Triggerbot_Report_{0:yyyyMMdd_HHmmss}.html" -f (Get-Date))

$html = @"
<html><head><style>
body{background:#111;color:#eee;font-family:Arial}
table{border-collapse:collapse;width:100%}
th,td{border:1px solid #444;padding:6px}
th{background:#222}
</style></head><body>
<h1>Triggerbot / Cheat Scan Report</h1>
<p>Scanstart: $start<br>Scanende: $(Get-Date)</p>
<table>
<tr><th>Typ</th><th>Pfad / Prozess</th><th>Score</th><th>Matches</th></tr>
"@

foreach ($r in $all) {
    $html += "<tr><td>$($r.Type)</td><td>$($r.Path ?? $r.Name)</td><td>$($r.Score)</td><td>$($r.Matches)</td></tr>"
}

$html += "</table></body></html>"
$html | Out-File $report -Encoding UTF8
Start-Process $report
