
                                                              Write-Host @"
   __  __  __   _____  ___     __  _   _____         __    __ 
   \ \/ _\/ _\  \_   \/ _ \ /\ \ \/_\ /__   \/\ /\  /__\  /__\
    \ \ \ \ \    / /\/ /_\//  \/ //_\\  / /\/ / \ \/ \// /_\  
 /\_/ /\ \_\ \/\/ /_/ /_\\/ /\  /  _  \/ /  \ \_/ / _  \//__  
 \___/\__/\__/\____/\____/\_\ \/\_/ \_/\/    \___/\/ \_/\__/  
                                                              
"@ -ForegroundColor Magenta

Write-Host "Made by Neight01`n"

# Define the path to the paths.txt file
$pathsFile = "paths.txt"

# Check if the paths.txt file exists
if (Test-Path $pathsFile -PathType Leaf) {
    # Read paths from the file
    $paths = Get-Content $pathsFile

    $unsignedFiles = @()

    foreach ($path in $paths) {
        # Check if the file exists
        if (Test-Path $path -PathType Leaf) {
            # Check if the file is an executable
            if ((Get-Item $path).Extension -eq ".exe") {
                # Check if the file has a digital signature
                $signature = $null
                try {
                    $signature = (Get-AuthenticodeSignature $path).Status
                } catch {
                    # Ignore errors caused by unsigned files
                }

                if ($signature -ne "Valid") {
                    $fileInfo = Get-Item $path
                    $fileProperties = @{
                        Name = $fileInfo.Name
                        Path = $fileInfo.FullName
                        Description = $fileInfo.VersionInfo.FileDescription
                        ProductName = $fileInfo.VersionInfo.ProductName
                        Company = $fileInfo.VersionInfo.CompanyName
                    }
                    $unsignedFiles += New-Object PSObject -Property $fileProperties
                }
            }
        } else {
            Write-Host "File not found: $path"
        }
    }

    # Display unsigned files in a grid view
    if ($unsignedFiles.Count -gt 0) {
        $unsignedFiles | Out-GridView -PassThru -Title 'UnSign Script by Neight01'
    } else {
        Write-Host "No unsigned files found."
    }
} else {
    Write-Host "Error: paths.txt file not found."
}
