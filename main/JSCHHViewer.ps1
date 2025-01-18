$inputFile = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt');
$host.ui.RawUI.WindowTitle = "CHHViewer - Made by Neight01 and Johannes Schwein"
Clear-Host
Write-Host "";
Write-Host -ForegroundColor Magenta @"

   __  __     ___                     _                        
   \ \/ _\   / __\ /\  /\/\  /\/\   /(_) _____      _____ _ __ 
    \ \ \   / /   / /_/ / /_/ /\ \ / / |/ _ \ \ /\ / / _ \ '__|
 /\_/ /\ \ / /___/ __  / __  /  \ V /| |  __/\ V  V /  __/ |   
 \___/\__/ \____/\/ /_/\/ /_/    \_/ |_|\___| \_/\_/ \___|_|   
                                                               
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
