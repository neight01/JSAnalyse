$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$outDir = "$env:USERPROFILE\Desktop\JSDriver_$timestamp"
New-Item -Path $outDir -ItemType Directory -Force | Out-Null

# HTML Sammelcontainer
$Global:HtmlSections = @()

function Convert-ToHtmlSafe($text) {
    return [System.Web.HttpUtility]::HtmlEncode($text)
}

function Save-Output($name, $scriptblock) {
    $file = Join-Path $outDir ($name + ".txt")

    try {
        $output = & $scriptblock *>&1 | Out-String
        $output | Out-File -FilePath $file -Encoding UTF8

        $htmlSafe = Convert-ToHtmlSafe $output
        $Global:HtmlSections += @"
<h2>$name</h2>
<pre>$htmlSafe</pre>
<hr/>
"@

        return $file
    } catch {
        $err = "Fehler beim Ausführen von $name : $_"
        $err | Out-File -FilePath $file -Encoding UTF8

        $Global:HtmlSections += @"
<h2>$name</h2>
<pre>FEHLER: $(Convert-ToHtmlSafe $err)</pre>
<hr/>
"@

        return $file
    }
}

function Generate-HtmlReport {
    $htmlPath = Join-Path $outDir "JSDriver_Report_$timestamp.html"

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>JSDriver Report</title>
<style>
body { background:#111; color:#eee; font-family: Consolas, monospace; padding:20px; }
h1 { color:#00ffff; }
h2 { color:#9ad68b; }
pre { background:#1a1a1a; padding:10px; overflow:auto; }
hr { border:1px solid #333; }
</style>
</head>
<body>
<h1>JSDriver System Report</h1>
<p><b>Erstellt:</b> $(Get-Date)</p>
<hr/>
$($Global:HtmlSections -join "`n")
</body>
</html>
"@

    $html | Out-File -FilePath $htmlPath -Encoding UTF8
    Start-Process $htmlPath
}

function Zip-Results {
    param([string]$targetZip)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if(Test-Path $targetZip) { Remove-Item $targetZip -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($outDir, $targetZip)
}

function Pause() { Write-Host ""; Read-Host "Drücke Enter um fortzufahren..." > $null }

# ================= TASKS =================
$Tasks = @{
    "hostname" = { hostname }
    "systeminfo" = { systeminfo }
    "win_bios" = { Get-CimInstance Win32_BIOS | Format-List * }
    "computer_system" = { Get-CimInstance Win32_ComputerSystem | Format-List * }
    "get_process" = { Get-Process | Sort CPU -Descending | Format-Table -AutoSize }
    "tasklist_verbose" = { tasklist /v }
    "services" = { Get-Service | Where Status -ne Stopped | Format-Table -AutoSize }
    "netstat_ano" = { netstat -ano }
    "network_adapters" = { Get-NetAdapter | Format-Table -AutoSize }
    "ip_config" = { ipconfig /all }
    "driverquery" = { driverquery /v }
    "scheduled_tasks" = { schtasks /query /fo LIST /v }
    "users" = { Get-CimInstance Win32_UserAccount | Format-Table Name,SID,Disabled -AutoSize }
}

function Show-Header {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "          JSDriver by Neight01           " -ForegroundColor Cyan
    Write-Host " Ausgabe: $outDir" -ForegroundColor Yellow
    Write-Host " Zeitstempel: $timestamp" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
}

function Show-Menu {
    Show-Header
    $i = 1
    foreach ($k in $Tasks.Keys) {
        Write-Host ("[{0}] {1}" -f $i, $k)
        $i++
    }
    Write-Host ""
    Write-Host "[A] Alle ausführen"
    Write-Host "[H] HTML Report erzeugen"
    Write-Host "[O] Ausgabeordner öffnen"
    Write-Host "[Z] Zip erstellen"
    Write-Host "[Q] Beenden"
}

function Run-Task-ByIndex {
    param([int]$index)
    $key = $Tasks.Keys[$index - 1]
    Save-Output $key $Tasks[$key] | Out-Null
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Auswahl"
    switch ($choice.ToUpper()) {
        { $_ -match '^\d+$' } { Run-Task-ByIndex ([int]$choice); Pause }
        "A" { foreach($k in $Tasks.Keys){ Save-Output $k $Tasks[$k] | Out-Null }; Pause }
        "H" { Generate-HtmlReport }
        "O" { Start-Process explorer.exe $outDir }
        "Z" {
            $zip = "$env:USERPROFILE\Desktop\JSDriver_$timestamp.zip"
            Zip-Results $zip
            Write-Host "ZIP erstellt: $zip" -ForegroundColor Green
            Pause
        }
        "Q" { break }
    }
}

Write-Host "Beende JSDriver"
