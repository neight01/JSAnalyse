Clear-Host
Write-Host ""
Write-Host ""
Write-Host -ForegroundColor Red "   __  __  _____  ___    ___     _            _   "
Write-Host -ForegroundColor Red "   \ \/ _\/__   \/ __\  /   \___| |_ ___  ___| |_ "
Write-Host -ForegroundColor Red "    \ \ \   / /\/__\// / /\ / _ \ __/ _ \/ __| __|"
Write-Host -ForegroundColor Red " /\_/ /\ \ / / / \/  \/ /_//  __/ ||  __/ (__| |_ "
Write-Host -ForegroundColor Red " \___/\__/ \/  \_____/___,' \___|\__\___|\___|\__|"
Write-Host -ForegroundColor Red "                                                  "
Write-Host -ForegroundColor Red "              Made by Neight01                    "
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
        try {
            $enumerator = [System.IO.Directory]::EnumerateFiles($root, '*.py', [System.IO.SearchOption]::AllDirectories) +
                          [System.IO.Directory]::EnumerateFiles($root, '*.pyw', [System.IO.SearchOption]::AllDirectories)
        } catch { continue }

        foreach ($file in $enumerator) {
            try { $info = Get-Item -LiteralPath $file -ErrorAction SilentlyContinue } catch { continue }

            try {
                $matches = Select-String -Path $file -Pattern ($Signatures | ForEach-Object { $_.regex }) -AllMatches -ErrorAction SilentlyContinue
                if ($matches.Count -gt 0) {
                    $foundPatterns = $matches | Select-Object -ExpandProperty Pattern -Unique
                    $matchedSigs = @()
                    foreach ($p in $Signatures) { foreach ($fp in $foundPatterns) { if ($fp -eq $p.regex) { $matchedSigs += $p; break } } }
                    if ($matchedSigs.Count -gt 0) {
                        $score = Score-Matches -MatchedSignatures $matchedSigs
                        $entry = [PSCustomObject]@{
                            Type = 'File'
                            Path = $file
                            Score = $score
                            Matches = ($matchedSigs | ForEach-Object { $_.regex }) -join '; '
                            LastWrite = $info.LastWriteTime
                        }
                        $results += $entry
                    }
                }
            } catch { }
        }
    }
    return $results
}

function Scan-Processes {
    $procResults = @()
    try { $pyProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(python|pythonw)(\.exe)?$' } } catch { return $procResults }
    foreach ($p in $pyProcs) {
        $cmd = $p.CommandLine; $matched = @()
        foreach ($sig in $Signatures) { try { if ($cmd -and ($cmd -match $sig.regex)) { $matched += $sig } } catch { } }
        if ($matched.Count -eq 0 -and $cmd -match '\.py') {
            $scriptPath = ($cmd -split '\s+' | Where-Object { $_ -match '\.py$' }) | Select-Object -First 1
            if ($scriptPath) {
                try {
                    $abs = if (Test-Path $scriptPath) { $scriptPath } else { Join-Path -Path (Split-Path -Parent $p.ExecutablePath) -ChildPath $scriptPath }
                    if (Test-Path $abs) {
                        $content = Get-Content -LiteralPath $abs -Raw -ErrorAction SilentlyContinue
                        foreach ($sig in $Signatures) { try { if ($content -match $sig.regex) { $matched += $sig } } catch { } }
                    }
                } catch { }
            }
        }
        if ($matched.Count -gt 0) {
            $score = Score-Matches -MatchedSignatures $matched
            $entry = [PSCustomObject]@{
                Type = 'Process'; PID = $p.ProcessId; Name = $p.Name; CommandLine = $cmd; Score = $score; Matches = ($matched | ForEach-Object { $_.regex }) -join '; '
            }
            $procResults += $entry
        }
    }
    return $procResults
}

Write-Host "Starte Johannes Schwein Triggerbot-Detect" -ForegroundColor Cyan
Write-Host "Startzeit: $(Get-Date -Format u)" -ForegroundColor Cyan

$roots = Get-AllDriveRoots
$fileFindings = Scan-Files-OnRoots -Roots $roots
$procFindings = Scan-Processes
$all = $fileFindings + $procFindings

if ($all.Count -eq 0) {
    Write-Host "Keine verdächtigen Triggerbot-Signaturen gefunden." -ForegroundColor Green
} else {
    $sorted = $all | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='Type';Descending=$false}
    Write-Host ""; Write-Host "Gefundene verdächtige Objekte (nach Score sortiert):" -ForegroundColor Cyan
    $i = 1
    foreach ($s in $sorted) {
        Write-Host "[$i] Type: $($s.Type)  Score: $($s.Score)  Path/PID: $($s.Path -or $s.PID)" -ForegroundColor Magenta
        Write-Host "     Matches: $($s.Matches)"
        if ($s.Type -eq 'Process') { Write-Host "     CommandLine: $($s.CommandLine)" }
        if ($s.Type -eq 'File') { Write-Host "     LastWrite: $($s.LastWrite)" }
        $i++
    }

    $htmlPath = Join-Path $env:TEMP "triggerbot_scan_report.html"
    $html = "<html><head><title>Triggerbot Scan Report</title><style>
        body{font-family:Arial;background:#1e1e1e;color:white;}
        table{border-collapse:collapse;width:100%;}
        th,td{border:1px solid #555;padding:5px;text-align:left;}
        th{background:#333;} tr:nth-child(even){background:#2e2e2e;}
        .score-high{color:red;font-weight:bold;}
    </style></head><body><h2>Triggerbot Scan Report - $(Get-Date)</h2><table><tr><th>#</th><th>Type</th><th>Score</th><th>Path/PID</th><th>Matches</th><th>LastWrite / CommandLine</th></tr>"

    $j = 1
    foreach ($s in $sorted) {
        $scoreClass = if ($s.Score -ge 5) { "score-high" } else { "" }
        $details = if ($s.Type -eq 'File') { $s.LastWrite } else { $s.CommandLine }
        $html += "<tr class='$scoreClass'><td>$j</td><td>$($s.Type)</td><td>$($s.Score)</td><td>$($s.Path -or $s.PID)</td><td>$($s.Matches)</td><td>$details</td></tr>"
        $j++
    }
    $html += "</table></body></html>"
    $html | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Host "HTML Report gespeichert in: $htmlPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Scan beendet: $(Get-Date -Format u)" -ForegroundColor Cyan
