# Initial GitHub.com connectivity check with 1 second timeout
$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -Delay 1

# Import Modules and External Profiles
# Ensure Terminal-Icons module is installed before importing
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module -Name Terminal-Icons
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Check for Profile Updates
function Update-Profile {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        $url = "https://raw.githubusercontent.com/Blanc-dot/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $PROFILE -Force
            Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        }
    } catch {
        Write-Error "Unable to check for `$profile updates"
    } finally {
        Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
    }
}
Update-Profile

function Update-PowerShell {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping PowerShell update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = [version]$PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = [version]$latestReleaseInfo.tag_name.Trim('v')
        
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            Write-Host "Updating PowerShell..." -ForegroundColor Yellow
            winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
            Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}
Update-PowerShell

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Utility Functions
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
          elseif (Test-CommandExists pvim) { 'pvim' }
          elseif (Test-CommandExists vim) { 'vim' }
          elseif (Test-CommandExists vi) { 'vi' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          elseif (Test-CommandExists sublime_text) { 'sublime_text' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

function Edit-Profile {
    vim $PROFILE.CurrentUserAllHosts
}
function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.directory)\$($_)"
    }
}

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# System Utilities
function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}

function reload-profile {
    & $profile
}

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function hb {
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }
    
    $FilePath = $args[0]
    
    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath -Raw
    } else {
        Write-Error "File path does not exist."
        return
    }
    
    $uri = "http://bin.christitus.com/documents"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Write-Output $url
    } catch {
        Write-Error "Failed to upload the document. Error: $_"
    }
}
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}

function tail {
  param($Path, $n = 10)
  Get-Content $Path -Tail $n
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

### Quality of Life Aliases

# Navigation Shortcuts
function docs { Set-Location -Path $HOME\Documents }

function dtop { Set-Location -Path $HOME\Desktop }

# Quick Access to Editing the Profile
function ep { vim $PROFILE }

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gp { git push }

function g { z Github }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns { Clear-DnsClientCache }

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}

# Unzip zip and .7z files in a folder
function unzipall {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Folder,
        [string]$SevenZipExe = "D:\scoop\apps\7zip\current\7z.exe"
    )

    Write-Host "Folder: $Folder"

    # Check if the folder exists
    if (-not (Test-Path $Folder -PathType Container)) {
        Write-Host "Folder does not exist." -ForegroundColor Red
        exit 1
    }

    # Set the location to the folder
    Set-Location -Path $Folder

    # List contents of the folder
    Write-Host "Contents of the folder:"
    Get-ChildItem -Path $Folder

    # Initialize archive count
    $ArchiveCount = 0

    # Get all zip and 7z files in the folder
    $Archives = Get-ChildItem -Path $Folder -File | Where-Object { $_.Name -like "*.zip" -or $_.Name -like "*.7z" }

    # If no archives found, exit
    if ($Archives.Count -eq 0) {
        Write-Host "No archives found in $Folder." -ForegroundColor Yellow
        exit 0
    }

    # Extract each archive
    foreach ($Archive in $Archives) {
        Write-Host "Extracting $($Archive.FullName)..."
        $OutputFolder = Join-Path -Path $Folder -ChildPath $Archive.BaseName
        & $SevenZipExe x $Archive.FullName "-o$OutputFolder" -y
        $ArchiveCount++
    }

    # Output summary
    Write-Host "All archives extracted successfully." -ForegroundColor Green
    Write-Host "Total number of archives found: $ArchiveCount" -ForegroundColor Green

    # Prompt user to delete extracted archives
    $DeleteFiles = Read-Host "Do you want to delete the extracted archives? (Y/N)"
    if ($DeleteFiles -eq "Y" -or $DeleteFiles -eq "y") {
        foreach ($Archive in $Archives) {
            Remove-Item -Path $Archive.FullName -Force
        }
        Write-Host "Extracted archives deleted successfully." -ForegroundColor Green
    } else {
        Write-Host "Extracted archives not deleted." -ForegroundColor Yellow
    }
}

# Function to move files from subdirectories to the root directory
function Defolder {
    # Prompt the user to enter the root directory path
    $rootDir = Read-Host "Enter the root directory path"

    # Check if the entered directory exists
    if (-not (Test-Path $rootDir -PathType Container)) {
        Write-Host "The specified directory does not exist."
        return
    }

    # Get a list of all subdirectories within the root directory
    $subDirs = Get-ChildItem -Path $rootDir -Directory

    # Iterate through each subdirectory
    foreach ($subDir in $subDirs) {
        # Get a list of all files within the subdirectory
        $files = Get-ChildItem -Path $subDir.FullName -File
        
        # Move each file to the root directory
        foreach ($file in $files) {
            Move-Item -Path $file.FullName -Destination $rootDir -Force
        }
    }

    # Ask the user if they want to delete the subdirectories
    $deleteSubDirs = Read-Host "Do you want to delete the subdirectories? (Y/N)"
    if ($deleteSubDirs -eq "Y" -or $deleteSubDirs -eq "y") {
        foreach ($subDir in $subDirs) {
            # Remove the now-empty subdirectory
            Remove-Item -Path $subDir.FullName -Force -Recurse
        }
        Write-Host "Subdirectories deleted successfully!"
    } else {
        Write-Host "Subdirectories not deleted."
    }

    Write-Host "All files moved successfully!"
}

# Auto disable power management on USB devices
function Disable-PowerManagement {
    $hubs = Get-WmiObject Win32_Serialport | Select-Object Name,DeviceID,Description
    $powerMgmt = Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi

    foreach ($p in $powerMgmt) {
        $IN = $p.InstanceName.ToUpper()
        foreach ($h in $hubs) {
            $PNPDI = $h.PNPDeviceID
            if ($IN -like "*$PNPDI*") {
                $p.enable = $False
                $p.psbase.put()
            }
        }
    }
}

# Scoop Install
function Install-Scoop {
    param (
        [string]$InstallPath = "D:\scoop"
    )

    # Prompt user for installation directory
    $InstallPath = Read-Host "Enter the path for Scoop installation (default is D:\scoop):"

    # Prompt user if they want to set up a global Scoop directory
    $response = Read-Host "Do you want to set up a global Scoop directory? (Y/N):"

    if ($response -eq "Y" -or $response -eq "y") {
        $ScoopGlobalDir = Read-Host "Enter the path for the global Scoop directory:"
        $command = "irm get.scoop.sh -outfile 'install.ps1'; .\install.ps1 -ScoopDir '$InstallPath' -ScoopGlobalDir '$ScoopGlobalDir' -NoProxy"
    } else {
        $command = "irm get.scoop.sh -outfile 'install.ps1'; .\install.ps1 -ScoopDir '$InstallPath' -NoProxy"
    }

    # Execute the installation command
    try {
        Invoke-Expression $command
        Write-Host "Scoop has been installed successfully."
    } catch {
        Write-Error "Failed to install Scoop. Error: $_"
    }
}

# Call the function to install Scoop
Install-Scoop


# Setup Ani-cli
function Setup-Anime {
    # Add the 'extras' bucket if it's not already added
    if (-not (scoop bucket list | Select-String -SimpleMatch 'extras')) {
        scoop bucket add extras
    }
    # Install desired packages
    scoop install ani-cli 
    scoop install fzf
    scoop install mpv
    scoop install git
    scoop install yt-dlp
}


# Watch Anime
Set-Alias -Name anime -Value ani-cli

## Final Line to set prompt
oh-my-posh init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json | Invoke-Expression
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
} else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}
