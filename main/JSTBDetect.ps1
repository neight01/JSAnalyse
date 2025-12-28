Clear-Host
Write-Host ""
Write-Host ""
Write-Host -ForegroundColor Red "   __  __  _____  ___    ___     _            _   "
Write-Host -ForegroundColor Red "   \ \/ _\/__   \/ __\  /   \___| |_ ___  ___| |_ "
Write-Host -ForegroundColor Red "    \ \ \   / /\/__\// / /\ / _ \ __/ _ \/ __| __|"
Write-Host -ForegroundColor Red " /\_/ /\ \ / / / \/  \/ /_//  __/ ||  __/ (__| |_ "
Write-Host -ForegroundColor Red " \___/\__/ \/  \_____/___,' \___|\__\___|\___|\__|"
Write-Host -ForegroundColor Red "                                                  "
Write-Host -ForegroundColor Red "                 Made by Johannes Schwein         "
Write-Host ""
Start-Sleep -Seconds 5
Clear-Host

$Signatures = @(
    @{regex = 'pyautogui\.(mouseDown|mouseUp|click|moveTo)'; weight = 3},
    @{regex = 'GetPixel\(|gdi32|GetDC\('; weight = 3},
    @{regex = '\bsearch_color\b'; weight = 3},
    @{regex = '\bclick_delay\b'; weight = 2},
    @{regex = '\bpynput\.mouse\.Listener\b'; weight = 3},
    @{regex = 'winsound\.'; weight = 1},
    @{regex = 'customtkinter|tkinter|CTk'; weight = 1},
    @{regex = 'pyautogui\.FailSafeException'; weight = 2},
    @{regex = 'mouseDown\(|mouseUp\('; weight = 2},
    @{regex = 'windll\.LoadLibrary\(|user32\.GetSystemMetrics'; weight = 2},
    @{regex = '\brunning\b|\balive\b|\bright_mouse_pressed\b'; weight = 1},
    @{regex = 'time\.sleep\(|random\.uniform\('; weight = 1},
    @{regex = 'pyautogui\.screenshot|pyautogui\.pixel'; weight = 2},
    @{regex = 'pynput\.mouse|pynput\.keyboard'; weight = 2}
)

function Score-Matches {
    param($MatchedSignatures)
    $score = 0
    foreach ($m in $MatchedSignatures) { $score += $m.weight }
    return $score
}

function Get-AllDriveRoots {
    $roots = @()
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($d in $drives) { if (Test-Path $d.Root) { $roots += $d.Root } }
    return $roots
}

function Scan-Files-OnRoots {
    param($Roots)
    $results = @()
    foreach ($root in $Roots) {
        Write-Host "Durchsuche $root ..." -ForegroundColor Yellow
        try { $files = Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue -Force -Include *.py,*.pyw } catch { continue }
        foreach ($f in $files) {
            try { $content = Get-Content -LiteralPath $f.FullName -ErrorAction Stop -Raw } catch { continue }
            $matched = @()
            foreach ($sig in $Signatures) { try { if ($content -match $sig.regex) { $matched += $sig } } catch {} }
            if ($matched.Count -gt 0) {
                $score = Score-Matches -MatchedSignatures $matched
                $entry = [PSCustomObject]@{
                    Type = 'File'
                    Path = $f.FullName
                    FileName = $f.Name
                    Score = $score
                    Matches = ($matched | ForEach-Object { $_.regex }) -join '; '
                    LastWrite = $f.LastWriteTime
                }
                $results += $entry
            }
        }
    }
    return $results
}

function Scan-Processes {
    $procResults = @()
    try { $pyProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(python|pythonw)(\.exe)?$' } } catch { return $procResults }
    foreach ($p in $pyProcs) {
        $cmd = $p.CommandLine
        $matched = @()
        foreach ($sig in $Signatures) { try { if ($cmd -and ($cmd -match $sig.regex)) { $matched += $sig } } catch {} }
        if ($matched.Count -eq 0 -and $cmd -match '\.py') {
            $scriptPath = ($cmd -split '\s+' | Where-Object { $_ -match '\.py$' }) | Select-Object -First 1
            if ($scriptPath) {
                try {
                    $abs = if (Test-Path $scriptPath) { $scriptPath } else { Join-Path -Path (Split-Path -Parent $p.ExecutablePath) -ChildPath $scriptPath }
                    if (Test-Path $abs) {
                        $content = Get-Content -LiteralPath $abs -Raw -ErrorAction SilentlyContinue
                        foreach ($sig in $Signatures) { try { if ($content -match $sig.regex) { $matched += $sig } } catch {} }
                    }
                } catch {}
            }
        }
        if ($matched.Count -gt 0) {
            $score = Score-Matches -MatchedSignatures $matched
            $entry = [PSCustomObject]@{
                Type = 'Process'
                PID = $p.ProcessId
                Name = $p.Name
                CommandLine = $cmd
                Score = $score
                Matches = ($matched | ForEach-Object { $_.regex }) -join '; '
            }
            $procResults += $entry
        }
    }
    return $procResults
}

$startTime = Get-Date
Write-Host "Starte JSTBDetect" -ForegroundColor Cyan
Write-Host "Startzeit: $startTime" -ForegroundColor Cyan

$roots = Get-AllDriveRoots
$fileFindings = Scan-Files-OnRoots -Roots $roots
$procFindings = Scan-Processes

$fileFindings = $fileFindings | Sort-Object -Property Score -Descending
$procFindings = $procFindings | Sort-Object -Property Score -Descending

$all = $fileFindings + $procFindings
if ($all.Count -eq 0) { Write-Host "Keine verdächtigen Triggerbot-Signaturen gefunden." -ForegroundColor Green }

$endTime = Get-Date
$desktop = [Environment]::GetFolderPath('Desktop')
$reportPath = Join-Path $desktop ("Triggerbot_Scan_Report_{0:yyyyMMdd_HHmmss}.html" -f $endTime)

$htmlHeader = @"
<!doctype html>
<html>
<head>
<meta charset='utf-8'>
<title>Johannes Schwein Triggerbot Scan</title>
<style>
body { font-family: Arial; background:#111; color:#eee; padding:20px; }
h1 { color:#ff4444; }
table { border-collapse: collapse; width:100%; margin-bottom:20px; }
th, td { border: 1px solid #444; padding:8px; text-align:left; }
th { background:#222; color:#fff; }
tr:nth-child(even) { background:#1a1a1a; }
a { color:#7ec0ff; text-decoration:none; }
.summary { margin-bottom:20px; padding:10px; background:#0f0f0f; border:1px solid #333; }
.section-title { color:#9ad68b; }
</style>
</head>
<body>
<h1>Johannes Schwein Triggerbot Scan</h1>
<div class='summary'>
<p><strong>Scan gestartet:</strong> $startTime<br/>
<strong>Scan beendet:</strong> $endTime<br/>
<strong>Gefundene verdächtige Dateien:</strong> $($fileFindings.Count)<br/>
<strong>Gefundene verdächtige Prozesse:</strong> $($procFindings.Count)<br/>
</p>
</div>
<h2 class='section-title'>Verdächtige Dateien</h2>
<table>
<tr><th>#</th><th>Pfad</th><th>Score</th><th>Matches</th><th>Letzte Änderung</th></tr>
"@

$fileRows = ""
if ($fileFindings -and $fileFindings.Count -gt 0) {
    $n = 1
    foreach ($f in $fileFindings) {
        $escapedMatches = [System.Web.HttpUtility]::HtmlEncode($f.Matches)
        $fileRows += "<tr><td>$n</td><td>$($f.Path)</td><td>$($f.Score)</td><td>$escapedMatches</td><td>$($f.LastWrite)</td></tr>`n"
        $n++
    }
} else { $fileRows = "<tr><td colspan='5'>Keine verdächtigen Dateien gefunden</td></tr>`n" }

$procTableHeader = @"
</table>
<h2 class='section-title'>Verdächtige Prozesse (sortiert nach Score)</h2>
<table>
<tr><th>#</th><th>PID</th><th>Name</th><th>Score</th><th>Matches</th><th>CommandLine</th></tr>
"@

$procRows = ""
if ($procFindings -and $procFindings.Count -gt 0) {
    $n = 1
    foreach ($p in $procFindings) {
        $escapedMatches = [System.Web.HttpUtility]::HtmlEncode($p.Matches)
        $escapedCmd = [System.Web.HttpUtility]::HtmlEncode($p.CommandLine)
        $procRows += "<tr><td>$n</td><td>$($p.PID)</td><td>$($p.Name)</td><td>$($p.Score)</td><td>$escapedMatches</td><td><code>$escapedCmd</code></td></tr>`n"
        $n++
    }
} else { $procRows = "<tr><td colspan='6'>Keine verdächtigen Prozesse gefunden</td></tr>`n" }

$fileNameSummary = @"
</table>
<h2 class='section-title'>Verdächtige Dateinamen Übersicht</h2>
<table>
<tr><th>#</th><th>Dateiname</th></tr>
"@

$summaryRows = ""
if ($fileFindings -and $fileFindings.Count -gt 0) {
    $n = 1
    foreach ($f in $fileFindings) {
        $summaryRows += "<tr><td>$n</td><td>$($f.FileName)</td></tr>`n"
        $n++
    }
} else { $summaryRows = "<tr><td colspan='2'>Keine verdächtigen Dateien gefunden</td></tr>`n" }

$footer = "</table><hr/><p>Report automatisch erstellt am $endTime</p></body></html>"

$fullHtml = $htmlHeader + $fileRows + $procTableHeader + $procRows + $fileNameSummary + $summaryRows + $footer

try {
    $fullHtml | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "HTML-Report gespeichert: $reportPath" -ForegroundColor Green
    Start-Process -FilePath $reportPath
} catch {
    Write-Host "Fehler beim Speichern des Reports: $_" -ForegroundColor Red
}



