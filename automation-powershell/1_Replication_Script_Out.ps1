 

#Requires -Version 5.1
<#
.SYNOPSIS
    Scripts out SQL Server replication configuration to dated folders.
.DESCRIPTION
    Connects to a Distributor and Publisher using RMO, scripts all replication
    components to .SQL files in a date-stamped folder, then prunes folders
    older than 15 days. Designed to run daily via Task Scheduler.
#>



[CmdletBinding()]
param()

#Start-Transcript -Path "C:\dba\ps\myscript.log" -Append
#whoami | Out-File C:\dba\ps\whoami.txt

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Countinue'

# --- Configuration ---
$baseScriptPath          = '<EnterPath>'
$SqlInstanceDistributor  = 'Distributor_ServerName'
$SqlInstancePublisher    = '<Publisher_Name>'
$RetentionDays           = 15
$LogFile                 = Join-Path $baseScriptPath 'Replication_Script.log'

# --- Start transcript ---
Start-Transcript -Path $LogFile -Append
$scriptStart = Get-Date
Write-Host "[$scriptStart] Replication scripting job started."

try {
    # --- Load RMO assembly ---
    $rmoAssembly = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Rmo')
    if (-not $rmoAssembly) {
        throw 'Microsoft.SqlServer.Rmo assembly could not be loaded. Ensure SQL Server SMO is installed.'
    }
    Write-Host 'RMO assembly loaded successfully.'

    # --- Create date-stamped output folder ---
    $currentDate       = Get-Date -Format 'yyyy-MM-dd'
    $outputFolderPath  = Join-Path $baseScriptPath $currentDate

    if (-not (Test-Path $outputFolderPath)) {
        New-Item -Path $outputFolderPath -ItemType Directory | Out-Null
        Write-Host "Created output folder: $outputFolderPath"
    } else {
        Write-Host "Output folder already exists: $outputFolderPath"
    }

    # ---------------------------------------------------------------
    # 1. Script Distributor
    # ---------------------------------------------------------------
    Write-Host "Connecting to Distributor: $SqlInstanceDistributor"
    $DistributorServer = New-Object 'Microsoft.SqlServer.Replication.ReplicationServer' $SqlInstanceDistributor

    $ScriptOptsDist = [Microsoft.SqlServer.Replication.ScriptOptions]::Creation -bor
                      [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo

    $distributionDbScript  = $DistributorServer.Script($ScriptOptsDist)
    $distributorInstScript = $DistributorServer.ScriptInstallDistributor($SqlInstanceDistributor, $ScriptOptsDist)

    $distributorFilePath = Join-Path $outputFolderPath ("1_{0}_Distribution.SQL" -f $SqlInstanceDistributor)
    $distributorInstScript, $distributionDbScript | Out-File -FilePath $distributorFilePath -Encoding UTF8
    Write-Host "Distributor script saved: $distributorFilePath"

    # ---------------------------------------------------------------
    # 2. Script Publisher components
    # ---------------------------------------------------------------
    Write-Host "Connecting to Publisher: $SqlInstancePublisher"
    $PublisherServer = New-Object 'Microsoft.SqlServer.Replication.ReplicationServer' $SqlInstancePublisher

    # --- 2a. Enable DB for Replication ---
    $ScriptOptsEnableDB = [Microsoft.SqlServer.Replication.ScriptOptions]::Creation -bor
                          [Microsoft.SqlServer.Replication.ScriptOptions]::EnableReplicationDB -bor
                          [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo

    $enableDbScript    = $PublisherServer.ReplicationDatabases.Script($ScriptOptsEnableDB)
    $enableDbFilePath  = Join-Path $outputFolderPath ("2_{0}_EnableDB_for_Replication.SQL" -f $SqlInstancePublisher)
    $enableDbScript | Out-File -FilePath $enableDbFilePath -Encoding UTF8
    Write-Host "Enable DB script saved: $enableDbFilePath"

    # --- 2b. Publications ---
    $ScriptOptsPub = [Microsoft.SqlServer.Replication.ScriptOptions]::Creation -bor
                     [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeCreateSnapshotAgent -bor
                     [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo

    $pubScript     = $PublisherServer.ReplicationDatabases.TransPublications.Script($ScriptOptsPub)
    $pubFilePath   = Join-Path $outputFolderPath ("3_{0}_Publication.SQL" -f $SqlInstancePublisher)
    $pubScript | Out-File -FilePath $pubFilePath -Encoding UTF8
    Write-Host "Publication script saved: $pubFilePath"

    # --- 2c. Articles ---
    $ScriptOptsArticles = [Microsoft.SqlServer.Replication.ScriptOptions]::Creation -bor
                          [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo

    $articlesScript   = $PublisherServer.ReplicationDatabases.TransPublications.TransArticles.Script($ScriptOptsArticles)
    $articlesFilePath = Join-Path $outputFolderPath ("4_{0}_Articles.SQL" -f $SqlInstancePublisher)
    $articlesScript | Out-File -FilePath $articlesFilePath -Encoding UTF8
    Write-Host "Articles script saved: $articlesFilePath"

    # --- 2d. Subscriptions ---
    $ScriptOptsSub = [Microsoft.SqlServer.Replication.ScriptOptions]::Creation -bor
                     [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo

    $subscriberScript   = $PublisherServer.ReplicationDatabases.TransPublications.TransSubscriptions.Script($ScriptOptsSub)
    $subscriberFilePath = Join-Path $outputFolderPath ("5_{0}_Subscriber.SQL" -f $SqlInstancePublisher)
    $subscriberScript | Out-File -FilePath $subscriberFilePath -Encoding UTF8
    Write-Host "Subscriptions script saved: $subscriberFilePath"

    Write-Host "`nAll replication scripts generated successfully in: $outputFolderPath"

    # ---------------------------------------------------------------
    # 3. Cleanup folders older than $RetentionDays days
    # ---------------------------------------------------------------
    Write-Host "`nCleaning up folders older than $RetentionDays days from: $baseScriptPath"
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)

    Get-ChildItem -Path $baseScriptPath -Directory | ForEach-Object {
        $folderDate = [datetime]::MinValue
        $parsed = [datetime]::TryParseExact(
            $_.Name,
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$folderDate
        )
        if ($parsed -and $folderDate -lt $cutoffDate) {
            Write-Host "Removing old folder: $($_.FullName)"
            Remove-Item -Path $_.FullName -Recurse -Force
        }
    }
    Write-Host 'Cleanup complete.'
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    # Re-throw so Task Scheduler sees a non-zero exit and can alert
    throw
}
finally {
    $duration = (Get-Date) - $scriptStart
    Write-Host ("`nJob finished in {0:mm}m {0:ss}s." -f $duration)
    Stop-Transcript
}

#Stop-Transcript


 
