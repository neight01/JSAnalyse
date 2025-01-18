Clear-Host
Clear-Host
Write-Host @"
   __  __  __           _                 _________  
   \ \/ _\/ _\_   _ ___| |_ ___ _ __ ___ |___ /___ \ 
    \ \ \ \ \| | | / __| __/ _ \ '_ ` _ \  |_ \ __) |
 /\_/ /\ \_\ \ |_| \__ \ ||  __/ | | | | |___) / __/ 
 \___/\__/\__/\__, |___/\__\___|_| |_| |_|____/_____| 
              |___/                                  
" -ForegroundColor Magenta

Write-Host "Made by Neight01 for Johannes Schwein Analysen`n"

$system32Path = "$env:SystemRoot\System32"

# Get all files in System32 directory
$files = Get-ChildItem -Path $system32Path -File -Recurse -ErrorAction SilentlyContinue

foreach ($file in $files) {
    # Check if the file is an executable
    if ($file.Extension -eq ".exe") {
        # Check if the file has a digital signature
        $signature = $null
        try {
            $signature = (Get-AuthenticodeSignature $file.FullName).Status
        } catch {
            # Ignore errors caused by unsigned files
        }

        if ($signature -ne "Valid") {
            Write-Host "Unsigned: $($file.FullName)"
        }
    }
}
