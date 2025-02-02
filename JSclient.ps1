Clear-Host
Write-Host @"

   __  __     ___ _ _            _   
   \ \/ _\   / __\ (_) ___ _ __ | |_ 
    \ \ \   / /  | | |/ _ \ '_ \| __|
 /\_/ /\ \ / /___| | |  __/ | | | |_ 
 \___/\__/ \____/|_|_|\___|_| |_|\__|
                       
"@ -ForegroundColor Cyan

Write-Host "Made by Neight01`n"

Write-Host "1: Rage"
Write-Host "2: Stealth"

$choice = Read-Host "Choose an option (1 or 2)"

if ($choice -eq "1" -or $choice -eq "2") {
    Write-Host "Loading JSClient"
    Start-Sleep -Seconds 1
    Write-Host "JSClient loaded"
} else {
    Write-Host "Invalid selection. Please run the script again."
}
