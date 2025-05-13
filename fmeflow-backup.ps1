<#
.SYNOPSIS
    Copies specific FME-related files and folders from a user-defined root directory
    into a single timestamped backup folder in the user's home directory.
    Suggests a default FME Flow root directory if not provided.

.DESCRIPTION
    This script prompts the user for a root FME Flow directory.
    If no directory is provided via parameter, it will prompt the user, suggesting
    "C:\Program Files\FMEFlow" as a default, which can be accepted or overridden.

    It then targets predefined FME-related files and folders within that root directory:
    - Utilities\tomcat (folder)
    - Server\fmeFlowConfig (folder)
    - Server\fmeFlowConfig.txt (file)
    - Server\fmeCommonConfig.txt (file)
    - Server\fmeFlowWebApplicationConfig.txt (file)
    - Server\fmeWebSocketConfig.txt (file)

    A single new directory is created in the user's home directory (e.g., C:\Users\YourUserName)
    with a name in the format 'FMEFlow_Backup_yyyyMMdd_HHmmss'.
    All specified source items are then copied into this new timestamped directory.

.PARAMETER FMEFlowRootDir
    The root directory of the FME Flow installation.
    If not provided as a parameter, the script will prompt for it, suggesting "C:\Program Files\FMEFlow".

.EXAMPLE
    PS C:\> .\Copy-FMEToUserHomeSingleFolder.ps1 -FMEFlowRootDir "D:\CustomFME\FMEFlow"

    This command will use "D:\CustomFME\FMEFlow" as the root. A single backup folder like
    C:\Users\YourUserName\FMEFlow_Backup_20240515_103000 will be created, and all FME items
    will be copied into it.

.EXAMPLE
    PS C:\> .\Copy-FMEToUserHomeSingleFolder.ps1
    (Script will then prompt: Please enter the FME Flow Root Directory (default: 'C:\Program Files\FMEFlow'): )
    User can press Enter to accept the default, or type a new path. A single backup folder will be
    created in their home directory.

.NOTES
    Author: Your Name/AI Assistant
    Date: 2025-05-14
    Ensure you have read permissions for the source paths and write permissions for the user's home directory.
    If a source path does not exist, a warning will be displayed for that specific item, and the script will skip it.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false,
               HelpMessage = "Enter the root directory of your FME Flow installation. If omitted, you will be prompted with a default.")]
    [string]$FMEFlowRootDir
)

# --- Script Start ---

# Define the default FME Flow root directory
$defaultFMEFlowRootDir = "C:\Program Files\FMEFlow"

# If FMEFlowRootDir is not provided as a parameter, prompt the user
if ([string]::IsNullOrWhiteSpace($FMEFlowRootDir)) {
    $userInput = Read-Host "Please enter the FME Flow Root Directory (default: '$defaultFMEFlowRootDir')"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        $FMEFlowRootDir = $defaultFMEFlowRootDir
        Write-Host "No input provided, using default FME Flow Root Directory: $FMEFlowRootDir"
    } else {
        $FMEFlowRootDir = $userInput
        Write-Host "User provided FME Flow Root Directory: $FMEFlowRootDir"
    }
} else {
     Write-Host "Using FME Flow Root Directory from parameter: $FMEFlowRootDir"
}


# Validate the provided FMEFlowRootDir
if (-not (Test-Path $FMEFlowRootDir -PathType Container)) {
    Write-Error "The specified FME Flow Root Directory does not exist or is not a folder: '$FMEFlowRootDir'. Exiting."
    exit 1
}

# Define the relative paths of the items to be backed up
$relativePaths = @(
    "Utilities\tomcat\conf",                  # Folder
    "Server\fmeFlowConfig",                   # Folder
    "Server\fmeFlowConfig.txt",               # File
    "Server\fmeCommonConfig.txt",             # File
    "Server\fmeFlowWebApplicationConfig.txt", # File
    "Server\fmeWebSocketConfig.txt"           # File
)

# Construct the full source paths
$SourcePaths = @()
foreach ($relativePathItem in $relativePaths) {
    $SourcePaths += Join-Path -Path $FMEFlowRootDir -ChildPath $relativePathItem
}

# Get the path to the current user's home directory
$backupBaseDir = $env:USERPROFILE
If (-not (Test-Path $backupBaseDir -PathType Container)) {
    Write-Error "Could not determine or access the user's home directory: '$backupBaseDir'. Exiting."
    exit 1
}
Write-Host "Backup base directory will be: $backupBaseDir"

# Get the current timestamp in a sortable format for the main backup folder name
$runTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Define the name of the single backup folder
$backupFolderName = "FMEFlow_Backup_$runTimestamp"

# Construct the full path for the new timestamped backup folder
$destinationFolderPath = Join-Path -Path $backupBaseDir -ChildPath $backupFolderName

# Try to create the new backup folder
try {
    Write-Host "`nCreating main backup folder at '$destinationFolderPath'..."
    $null = New-Item -ItemType Directory -Path $destinationFolderPath -ErrorAction Stop
    Write-Host "Successfully created main backup folder: $destinationFolderPath"
}
catch {
    Write-Error "Failed to create main backup folder: $destinationFolderPath. Error: $($_.Exception.Message)"
    exit 1 # Exit if main folder creation fails
}

$itemsCopiedCount = 0
Write-Host "`n--- Starting Backup Process ---"

# Loop through each source path identified
foreach ($sourcePath in $SourcePaths) {
    if (Test-Path $sourcePath) {
        $itemName = Split-Path -Path $sourcePath -Leaf
        try {
            Write-Host "Attempting to copy '$itemName' from '$sourcePath' to '$destinationFolderPath'..."
            Copy-Item -Path $sourcePath -Destination $destinationFolderPath -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully copied '$itemName' into '$destinationFolderPath'."
            $itemsCopiedCount++
        }
        catch {
            Write-Error "Failed to copy '$itemName' from '$sourcePath'. Error: $($_.Exception.Message)"
            Write-Warning "Skipping copy for '$itemName' due to error."
        }
    }
    else {
        Write-Warning "`nSource path not found: '$sourcePath'. Skipping this item."
    }
}

Write-Host "`n--- Script Finished ---"
Write-Host "All specified FME items have been processed."

if ($itemsCopiedCount -gt 0) {
    Write-Host "$itemsCopiedCount item(s) were copied to the backup folder."
    Write-Host "Backup location: $destinationFolderPath"
} elseif (Test-Path $destinationFolderPath) {
    Write-Host "The backup folder was created at '$destinationFolderPath', but no items were copied (e.g., source items not found or errors occurred)."
}
else {
    Write-Host "No backup folder was created, or no items were copied. Check warnings or errors above."
}

# --- Script End ---
