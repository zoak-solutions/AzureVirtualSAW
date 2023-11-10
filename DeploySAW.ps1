# DeploySAW.ps1 
# Stop on errors
[CmdletBinding()]
Param(
    [switch]$Destroy,
    [switch]$NoDeploy,
    [switch]$SkipNetwork,
    [switch]$SkipVDIEnv,
    [switch]$SkipRegKey,
    [ValidateScript({ if ($_) { Test-Path $_ } })]
    [string]$ConfigFile = "$(( get-item $PSScriptRoot ).FullName)\config\SAWDeployerConfigItems.ps1"
)
$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
$script_name = $MyInvocation.MyCommand.Name
$script_path = $PSScriptRoot
Start-Transcript -Append "$script_path\logs\$script_name-$timestamp.log"
try {
    Write-Debug -Message "Script name: $script_name"
    # Load config items
    if (!(Test-Path $ConfigFile)) {
        Write-Error -Message "$ConfigFile not found. Exiting." -ErrorAction Stop
    }
    else {
        . $ConfigFile
    }

    Write-Host "### Start at: $(Get-Date) ###"
    # Function to copy a file removing prefix in filname and replacing with a new prefix
    function Copy-FileWithNewPrefix {
        param (
            [Parameter(Mandatory)]
            [string]$SourceFile,
            [Parameter(Mandatory)]
            [string]$DestinationFile,
            [Parameter(Mandatory)]
            [string]$OldPrefix,
            [Parameter(Mandatory)]
            [string]$NewPrefix
        )
        $NewFileName = $DestinationFile -replace $OldPrefix, $NewPrefix
        Copy-Item -Path $SourceFile -Destination $NewFileName
    }

    # Check for SAWDeployerConfigItems.ps1
    if (!(Test-Path .\config\SAWDeployerConfigItems.ps1) -and (Test-Path .\config\EXAMPLE_SAWDeployerConfigItems.ps1)) {
        write-host "Only the EXAMPLE_SAWDeployerConfigItems.ps1 file found in ./config, shall I make a copy of this as ./config/SAWDeployerConfigItems.ps1 for use?:"  -Confirm
        if ($confirmation -eq 'y') {
            Copy-FileWithNewPrefix .\config\EXAMPLE_SAWDeployerConfigItems.ps1 .\config\SAWDeployerConfigItems.ps1 'EXAMPLE_' ''
        }
        else {
            Write-Error -Message "No appropriate config file in ./config dir. Exiting." -ErrorAction Stop
        }
    }
    else {
        . .\config\SAWDeployerConfigItems.ps1
    }

    function Install-DependentModule {
        param (
            [Parameter(Mandatory = $true)][string]$ModuleName
        )
        if (!(Get-Module -ListAvailable -Name $ModuleName)) {
            Write-Host "Installing module: $ModuleName"
            Install-Module -Name $ModuleName -Repository PSGallery -Force -Scope CurrentUser
        }
        else {
            Write-Host "Module: $ModuleName installed already."
        }
    }

    function Login-Azure() {
        # Bug on local machine here, https://learn.microsoft.com/en-us/answers/questions/1299863/how-to-fix-method-get-serializationsettings-does-n
        $context = Get-AzContext  
  
        if (!$context) {  
            Connect-AzAccount
        }   
        else {  
            Write-Host " Already connected"  
        }  
    }  
    function Destroy-SAWEnvironment {
        param (
            [Parameter(Mandatory)]
            [string]$RGToDestroy
        )
        Write-Host "Destroying resource group: $RGToDestroy"
        if (!(Get-AzResourceGroup -Name $RGToDestroy -ErrorAction SilentlyContinue)) {
            Write-Error -Message "Resource group: $RGToDestroy not found. Exiting." -ErrorAction Stop
        }
        else {
            Write-Host "Destroying Resource group: $RGToDestroy (this can take some time...)."
            Remove-AzResourceGroup -Name $RGToDestroy -Force 
            Write-Host "Resource group: $RGToDestroy destroyed."
        }
    }

    # MAIN
    Write-Host "Checking for required modules..."
    $ModuleDependencies = @('Az')
    Write-Host("Current Execution Policy: ")
    Get-ExecutionPolicy -Scope CurrentUser
    foreach ($Module in $ModuleDependencies) {
        Install-DependentModule -ModuleName $Module
    }

    # Login to Azure
    Write-Host "Logging into Azure if not already logged in..."
    Login-Azure

    # Run with switches controlling what to do
    if ($Destroy) {
        Destroy-SAWEnvironment -RGToDestroy $SAWResourceGroupName
    } if ($NoDeploy) {
        Write-Host "###############################################" 
        Write-Host "-NoDeploy switch present, skipping deployment and exiting." 
        Write-Host "###############################################"
        Exit
    } if ($SkipVDIEnv) {
        Write-Host "Skipping VDIEnv deploy"
    }
    else {
        Write-Host "Deploying SAW VDI environment..."
        .\scripts\CreateAzureVDIEnv.ps1
        Write-Host "SAW environment deployed."
    } if ($SkipNetwork) {
        Write-Host "Skipping network deploy"
    }
    else {
        Write-Host "Deploying SAW network..."
        .\scripts\CreateSAWNets.ps1
        Write-Host "SAW network deployed."
    } if ($SkipRegKey) {
        Write-Host "Skipping Reg Key create"
    }
    else {
        Write-Host "Creating session host Registration Key.."
        .\scripts\CreateRegKey.ps1
        Write-Host "SAW Registration Key Created"
    }
    Write-Host "### DONE at: $(Get-Date)  ###"
} # End try
catch {
    Write-Error "Error in script: $_" -ErrorAction Stop
}
finally {
    Stop-Transcript
}
