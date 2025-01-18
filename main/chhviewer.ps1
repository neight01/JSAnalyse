$inputFile = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt');
$host.ui.RawUI.WindowTitle = "CHHViewer - Made by Neight01 and Johannes Schwein"
Clear-Host
Write-Host "";
Write-Host -ForegroundColor Magenta @"
      ________  ____  __ _    ___                       
     / ____/ / / / / / /| |  / (_)__ _      _____  _____
    / /   / /_/ / /_/ / | | / / / _ \ | /| / / _ \/ ___/
   / /___/ __  / __  /  | |/ / /  __/ |/ |/ /  __/ /    
   \____/_/ /_/_/ /_/   |___/_/\___/|__/|__/\___/_/     
"@;
Write-Host -ForegroundColor White "CHHViewer - Made by Neight01 and Johannes Schwein - " -NoNewLine
Write-Host -ForegroundColor White "https://aquila.mt/jsnet/neight";
Write-Host "";

function Test-Admin {;$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent());$currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator);}
if (!(Test-Admin)) {
    Write-Warning " Please Run This Script as Admin."
    Start-Sleep 10
    Exit
}

try {
	$sw = [Diagnostics.Stopwatch]::StartNew()
    $data = Get-Content -Path $inputFile
	Write-Host -ForegroundColor Blue " Extracting " -NoNewLine
	Write-Host -ForegroundColor Gray "$($data.count) Items from $($env:USERNAME)"
    if ($data) {
		$sw.stop()
		$t = $sw.Elapsed.TotalMinutes
		Write-Host ""
		Write-Host " Elapsed Time $t Minutes" -ForegroundColor Yellow
        $data | Out-GridView -PassThru -Title "CHH Viewer - Made by Neight01 and Johannes Schwein | User: $($env:USERNAME) - Items: $($data.count)"
    } else {
        Write-Host -ForegroundColor Yellow "No data found in the file."
    }
} catch {
    Write-Host -ForegroundColor Red "Error reading file"
}
