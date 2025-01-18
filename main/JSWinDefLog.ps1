Clear-Host


Write-Host "";
Write-Host "";
Write-Host -ForegroundColor Red "    __  __  __    __ _          ___      __";
Write-Host -ForegroundColor Red "   \ \/ _\/ / /\ \ (_)_ __    /   \___ / _|";
Write-Host -ForegroundColor Red "    \ \ \ \ \/  \/ / | '_ \  / /\ / _ \ |_ ";
Write-Host -ForegroundColor Red " /\_/ /\ \ \  /\  /| | | | |/ /_//  __/  _|";
Write-Host -ForegroundColor Red " \___/\__/  \/  \/ |_|_| |_/___,' \___|_|  ";
Write-Host -ForegroundColor Red "                                           ";
Write-Host "";
Write-Host "";


# Get threat detection information and select desired fields
$threats = Get-MpThreatDetection | Select-Object InitialDetectionTime, LastThreatStatusChangeTime, ProcessName, Resources

# Display the information in a grid view
$threats | Out-GridView -PassThru -Title 'Windows Security Script by Neight01'
