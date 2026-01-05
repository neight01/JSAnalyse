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

# ================= SIGNATURES =================

$Signatures = @(
    # -------- Python --------
    @{ regex = 'pyautogui\.(click|mouseDown|mouseUp|moveTo|pixel|screenshot)'; weight = 3 },
    @{ regex = 'pynput\.mouse|pynput\.keyboard'; weight = 3 },
    @{ regex = 'GetPixel\(|PixelSearch|ImageSearch'; weight = 3 },
    @{ regex = 'time\.sleep\(|random\.uniform\('; weight = 1 },
    @{ regex = 'mouseDown\(|mouseUp\('; weight = 2 },
    @{ regex = 'winsound\.'; weight = 1 },

    # -------- AutoHotkey --------
    @{ regex = 'PixelSearch\s*,\s*'; weight = 3 },
    @{ regex = 'ImageSearch\s*,\s*'; weight = 3 },
    @{ regex = 'Click\b'; weight = 2 },
    @{ regex = 'GetKeyState\s*\('; weight = 2 },
    @{ regex = '~RButton|~LButton|RButton::|LButton::'; weight = 2 },
    @{ regex = 'Loop\s*,?\s*\d*'; weight = 1 },
    @{ regex = 'Sleep\s*,\s*\d+'; weight = 1 },
    @{ regex = 'Send(Input)?\s*,\s*'; weight = 1 },
    @{ regex = '#IfWinActive|#If'; weight = 1 },
    @{ regex = 'DllCall\s*\('; weight = 3 }
)

# ================= FUNCTIONS =================

function Score-Matches {
    param($Matches)
    $score = 0
    foreach ($m in $Matches) { $score += $m.weight }
    return $score
}

function Get-AllRoots {
    Get-PSDrive -PSProvider FileSystem |
    Where-Object { Test-Path $_.Root } |
    ForEach-Object { $_.Root }
}

function Scan-Files {
    param($Roots)

    $results = @()

    foreach ($root in $Roots) {
        Write-Host "[SCAN] $root" -ForegroundColor Yellow

        try {
            $files = Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue `
                -Include *.py,*.pyw,*.ahk
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
                    Type       = if ($f.Extension -eq ".ahk") { "AHK File" } else { "Python File" }
                    Path       = $f.FullName
                    FileName   = $f.Name
                    Score      = Score-Matches $matched
                    Matches    = ($matched | ForEach-Object { $_.regex }) -join "; "
                    LastWrite  = $f.LastWriteTime
                }
            }
        }
    }
    return $results
}

# ================= SCAN =================

$startTime = Get-Date
Write-Host "Starting Triggerischen Scan..." -ForegroundColor Cyan

$roots = Get-AllRoots
$findings = Scan-Files -Roots $roots | Sort-Object Score -Descending

$endTime = Get-Date

# ================= REPORT =================

$desktop = [Environment]::GetFolderPath("Desktop")
$report = Join-Path $desktop ("Triggerbot_Report_{0:yyyyMMdd_HHmmss}.html" -f $endTime)

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>Triggerbot Scan</title>
<style>
body { background:#111; color:#eee; font-family:Arial; padding:20px }
h1 { color:#ff4444 }
table { width:100%; border-collapse:collapse }
th,td { border:1px solid #444; padding:8px }
th { background:#222 }
tr:nth-child(even) { background:#1a1a1a }
</style>
</head>
<body>
<h1>Triggerbot Scan Report</h1>
<p>Started: $startTime<br>Finished: $endTime</p>

<table>
<tr>
<th>#</th><th>Type</th><th>Path</th><th>Score</th><th>Matches</th><th>Last Modified</th>
</tr>
"@

$i = 1
foreach ($f in $findings) {
    $m = [System.Web.HttpUtility]::HtmlEncode($f.Matches)
    $html += "<tr><td>$i</td><td>$($f.Type)</td><td>$($f.Path)</td><td>$($f.Score)</td><td>$m</td><td>$($f.LastWrite)</td></tr>"
    $i++
}

if ($findings.Count -eq 0) {
    $html += "<tr><td colspan='6'>No suspicious files found</td></tr>"
}

$html += "</table></body></html>"

$html | Out-File -Encoding UTF8 $report
Start-Process $report

Write-Host "Scan finished. Report saved to Desktop." -ForegroundColor Green
