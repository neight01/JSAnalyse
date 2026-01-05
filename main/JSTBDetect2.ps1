Clear-Host
Write-Host ""
Write-Host ""
Write-Host -ForegroundColor Red "   __  __  _____  ___    ___     _            _   "
Write-Host -ForegroundColor Red "   \ \/ _\/__   \/ __\  /   \___| |_ ___  ___| |_ "
Write-Host -ForegroundColor Red "    \ \ \   / /\/__\// / /\ / _ \ __/ _ \/ __| __|"
Write-Host -ForegroundColor Red " /\_/ /\ \ / / / \/  \/ /_//  __/ ||  __/ (__| |_ "
Write-Host -ForegroundColor Red " \___/\__/ \/  \_____/___,' \___|\__\___|\___|\__|"
Write-Host -ForegroundColor Red "                                                  "
Write-Host -ForegroundColor Red "               AHK Scan – Johannes Schwein        "
Write-Host ""
Start-Sleep -Seconds 5
Clear-Host

# ================== AHK SIGNATUREN ==================
$Signatures = @(
    @{ regex = 'PixelGetColor'; weight = 3 },
    @{ regex = 'ImageSearch'; weight = 3 },
    @{ regex = 'Click(\s|,)'; weight = 3 },
    @{ regex = 'MouseClick'; weight = 3 },
    @{ regex = 'Send(Input|Play)?'; weight = 2 },
    @{ regex = 'GetKeyState'; weight = 2 },
    @{ regex = 'SetTimer'; weight = 1 },
    @{ regex = 'Sleep\s*,?\s*\d+'; weight = 1 },
    @{ regex = 'CoordMode\s*,?\s*Pixel'; weight = 2 },
    @{ regex = 'CoordMode\s*,?\s*Mouse'; weight = 2 },
    @{ regex = 'While\s*\(|Loop'; weight = 1 },
    @{ regex = '~RButton|~LButton'; weight = 2 },
    @{ regex = 'Hotkey\s*,?\s*RButton'; weight = 2 },
    @{ regex = '#InstallMouseHook'; weight = 2 },
    @{ regex = '#Persistent'; weight = 1 }
)

# ================== SCORE ==================
function Score-Matches {
    param($MatchedSignatures)
    $score = 0
    foreach ($m in $MatchedSignatures) { $score += $m.weight }
    return $score
}

# ================== DRIVES ==================
function Get-AllDriveRoots {
    $roots = @()
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        if (Test-Path $_.Root) { $roots += $_.Root }
    }
    return $roots
}

# ================== DATEI SCAN ==================
function Scan-Files-OnRoots {
    param($Roots)
    $results = @()

    foreach ($root in $Roots) {
        Write-Host "Durchsuche $root ..." -ForegroundColor Yellow
        try {
            $files = Get-ChildItem -Path $root -Recurse -Force -Include *.ahk -ErrorAction SilentlyContinue
        } catch { continue }

        foreach ($f in $files) {
            try {
                $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
            } catch { continue }

            $matched = @()
            foreach ($sig in $Signatures) {
                if ($content -match $sig.regex) { $matched += $sig }
            }

            if ($matched.Count -gt 0) {
                $results += [PSCustomObject]@{
                    Type      = 'File'
                    Path      = $f.FullName
                    FileName  = $f.Name
                    Score     = Score-Matches $matched
                    Matches   = ($matched | ForEach-Object { $_.regex }) -join '; '
                    LastWrite = $f.LastWriteTime
                }
            }
        }
    }
    return $results
}

# ================== PROZESS SCAN ==================
function Scan-Processes {
    $procResults = @()
    $ahkProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'AutoHotkey.*\.exe' }

    foreach ($p in $ahkProcs) {
        $cmd = $p.CommandLine
        $matched = @()

        foreach ($sig in $Signatures) {
            if ($cmd -and $cmd -match $sig.regex) { $matched += $sig }
        }

        if ($matched.Count -gt 0) {
            $procResults += [PSCustomObject]@{
                Type        = 'Process'
                PID         = $p.ProcessId
                Name        = $p.Name
                Score       = Score-Matches $matched
                Matches     = ($matched | ForEach-Object { $_.regex }) -join '; '
                CommandLine = $cmd
            }
        }
    }
    return $procResults
}

# ================== START ==================
$startTime = Get-Date
Write-Host "Starte AHK Triggerbot Scan" -ForegroundColor Cyan

$roots = Get-AllDriveRoots
$fileFindings = Scan-Files-OnRoots $roots
$procFindings = Scan-Processes

$fileFindings = $fileFindings | Sort-Object Score -Descending
$procFindings = $procFindings | Sort-Object Score -Descending

$endTime = Get-Date
$desktop = [Environment]::GetFolderPath('Desktop')
$reportPath = Join-Path $desktop ("AHK_Triggerbot_Report_{0:yyyyMMdd_HHmmss}.html" -f $endTime)

# ================== HTML ==================
$html = @"
<!doctype html>
<html>
<head>
<meta charset='utf-8'>
<title>AHK Triggerbot Scan</title>
<style>
body { font-family: Arial; background:#111; color:#eee; padding:20px; }
h1 { color:#ff4444; }
table { border-collapse: collapse; width:100%; }
th,td { border:1px solid #444; padding:8px; }
th { background:#222; }
tr:nth-child(even){background:#1a1a1a;}
</style>
</head>
<body>
<h1>AHK Triggerbot Scan – Johannes Schwein</h1>
<p>Start: $startTime<br>Ende: $endTime</p>

<h2>Verdächtige Dateien</h2>
<table>
<tr><th>Pfad</th><th>Score</th><th>Matches</th></tr>
"@

foreach ($f in $fileFindings) {
    $html += "<tr><td>$($f.Path)</td><td>$($f.Score)</td><td>$($f.Matches)</td></tr>"
}

$html += @"
</table>
<h2>Verdächtige Prozesse</h2>
<table>
<tr><th>PID</th><th>Name</th><th>Score</th><th>Matches</th></tr>
"@

foreach ($p in $procFindings) {
    $html += "<tr><td>$($p.PID)</td><td>$($p.Name)</td><td>$($p.Score)</td><td>$($p.Matches)</td></tr>"
}

$html += "</table><hr><p>Report automatisch erstellt</p></body></html>"

$html | Out-File $reportPath -Encoding UTF8
Start-Process $reportPath
Write-Host "Report gespeichert: $reportPath" -ForegroundColor Green
