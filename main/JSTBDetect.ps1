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
    foreach ($d in $drives) {
        if (Test-Path $d.Root) { $roots += $d.Root }
    }
    return $roots
}

function Scan-Files-OnRoots {
    param($Roots)
    $results = @()
    foreach ($root in $Roots) {
        Write-Host "Durchsuche $root ..." -ForegroundColor Yellow
        try {
            $files = Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue -Force -Include *.py,*.pyw
        } catch {
            continue
        }
        foreach ($f in $files) {
            try {
                $content = Get-Content -LiteralPath $f.FullName -ErrorAction Stop -Raw
            } catch {
                continue
            }
            $matched = @()
            foreach ($sig in $Signatures) {
                try {
                    if ($content -match $sig.regex) { $matched += $sig }
                } catch { }
            }
            if ($matched.Count -gt 0) {
                $score = Score-Matches -MatchedSignatures $matched
                $entry = [PSCustomObject]@{
                    Type = 'File'
                    Path = $f.FullName
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
    try {
        $pyProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match '^(python|pythonw)(\.exe)?$'
        }
    } catch {
        return $procResults
    }
    foreach ($p in $pyProcs) {
        $cmd = $p.CommandLine
        $matched = @()
        foreach ($sig in $Signatures) {
            try {
                if ($cmd -and ($cmd -match $sig.regex)) { $matched += $sig }
            } catch { }
        }
        if ($matched.Count -eq 0) {
            if ($p.CommandLine -and ($p.CommandLine -match '\.py')) {
                $scriptPath = ($p.CommandLine -split '\s+' | Where-Object { $_ -match '\.py$' }) | Select-Object -First 1
                if ($scriptPath) {
                    try {
                        $abs = $scriptPath
                        if (-not (Test-Path $abs)) {
                            $abs = Join-Path -Path (Split-Path -Parent $p.ExecutablePath) -ChildPath $scriptPath
                        }
                        if (Test-Path $abs) {
                            $content = Get-Content -LiteralPath $abs -Raw -ErrorAction SilentlyContinue
                            foreach ($sig in $Signatures) {
                                try {
                                    if ($content -match $sig.regex) { $matched += $sig }
                                } catch { }
                            }
                        }
                    } catch { }
                }
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
    Write-Host ""
    Write-Host "Gefundene verdächtige Objekte (nach Score sortiert):" -ForegroundColor Cyan
    $i = 1
    foreach ($s in $sorted) {
        Write-Host "[$i] Type: $($s.Type)  Score: $($s.Score)  Path/PID: $($s.Path -or $s.PID)" -ForegroundColor Magenta
        Write-Host "     Matches: $($s.Matches)"
        if ($s.Type -eq 'Process') { Write-Host "     CommandLine: $($s.CommandLine)" }
        if ($s.Type -eq 'File') { Write-Host "     LastWrite: $($s.LastWrite)" }
        $i++
    }
}

Write-Host ""
Write-Host "Scan beendet: $(Get-Date -Format u)" -ForegroundColor Cyan

$save = Read-Host "Möchtest du die Resultate als JSON speichern? (Pfad oder leer für nein)"
if ($save) {
    try {
        $sorted | ConvertTo-Json -Depth 5 | Out-File -FilePath $save -Encoding UTF8
        Write-Host "Ergebnis gespeichert in: $save" -ForegroundColor Green
    } catch {
        Write-Host "Konnte JSON nicht speichern: $_" -ForegroundColor Yellow
    }
}
