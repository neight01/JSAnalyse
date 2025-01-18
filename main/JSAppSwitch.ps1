Clear-Host
Write-Host @"

   __  __    _               __          _ _       _     
   \ \/ _\  /_\  _ __  _ __ / _\_      _(_) |_ ___| |__  
    \ \ \  //_\\| '_ \| '_ \\ \\ \ /\ / / | __/ __| '_ \ 
 /\_/ /\ \/  _  \ |_) | |_) |\ \\ V  V /| | || (__| | | |
 \___/\__/\_/ \_/ .__/| .__/\__/ \_/\_/ |_|\__\___|_| |_|
                |_|   |_|                                
                       
"@ -ForegroundColor Cyan

Write-Host "Made by Neight01`n"


$AppSwitchedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched"

Get-ItemProperty -Path $AppSwitchedPath |
    findstr /i /C:":\" |
    Sort-Object LastWriteTime |
    Out-GridView -PassThru -Title 'Appswitch Script by Neight01'
