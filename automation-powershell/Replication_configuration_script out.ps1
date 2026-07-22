<#
Replication configuration scripting
- Modes:
  * Custom Publications list provided -> scripts only those publications; per-publication and combined files for _Selected.
  * Subscriber provided -> auto-discover publications to that subscriber.
  * Only publisher provided -> auto-discover all publications on publisher.
- Produces per-publication folder files and combined files.
#>

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Rmo')

# --- Configuration (can edit here) ---
$BaseScriptPath        = "N:\Replication_Configration_Scriptout"
$SqlInstancePublisher  = 'PRICSQL02'
$SqlInstanceDistributor= 'IES-PR-DIST2'
$SqlInstanceSubscriber = ''            # set '<subscriber server>' to scope discovery to a subscriber
$CustomPublications    = @(
#"WrExpertData_RP_FEED","WrExpertUsers_RP_FEED"
)           # list names here to use custom mode (leave empty to auto-discover)

# --- Helpers ---
function Clean-ScriptText { param([string]$Text) if ($null -eq $Text) { return $null } ; $t = $Text -replace "`r`n","`n" ; $t = $t.Trim() ; $t = $t -replace "(\n){3,}","`n`n" ; return ($t -replace "`n","`r`n") }

# --- Output folder ---
if (-not [string]::IsNullOrEmpty($SqlInstanceSubscriber)) { $OutputFolderName = "{0}_{1}" -f $SqlInstancePublisher, $SqlInstanceSubscriber } else { $OutputFolderName = (Get-Date -Format "yyyy-MM-dd") }
$OutputFolderPath = Join-Path -Path $BaseScriptPath -ChildPath $OutputFolderName
if (-not (Test-Path -Path $OutputFolderPath)) { try { New-Item -Path $OutputFolderPath -ItemType Directory -Force | Out-Null } catch { Throw ("Failed to create output folder {0}: {1}" -f $OutputFolderPath, $_) } }

# --- Validate write access ---
try { $tf = Join-Path $OutputFolderPath ".__write_test"; New-Item -Path $tf -ItemType File -Force | Out-Null; Remove-Item -Path $tf -Force } catch { Throw ("No write access to {0}: {1}" -f $OutputFolderPath, $_) }

# --- Connect RMO ---
try { $DistributorServer = New-Object Microsoft.SqlServer.Replication.ReplicationServer($SqlInstanceDistributor) } catch { Throw ("Failed to connect to Distributor {0}: {1}" -f $SqlInstanceDistributor, $_) }
try { $PublisherServer   = New-Object Microsoft.SqlServer.Replication.ReplicationServer($SqlInstancePublisher) } catch { Throw ("Failed to connect to Publisher {0}: {1}" -f $SqlInstancePublisher, $_) }

# --- Script options ---
$SO_Creation = [Microsoft.SqlServer.Replication.ScriptOptions]::Creation
$ScriptOptionsDistributor  = $SO_Creation -bor [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo
$ScriptOptionsEnableDB     = $SO_Creation -bor [Microsoft.SqlServer.Replication.ScriptOptions]::EnableReplicationDB -bor [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo
$ScriptOptionsPublication  = $SO_Creation -bor [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeCreateSnapshotAgent -bor [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo
$ScriptOptionsArticles     = $SO_Creation -bor [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo
$ScriptOptionsSubscription = $SO_Creation -bor [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo

# --- 1) Distributor scripts ---
$distOut = @()
try { $d1 = $DistributorServer.Script($ScriptOptionsDistributor); if ($d1) { $distOut += (Clean-ScriptText -Text $d1) } } catch { Write-Warning ("Distributor.Script failed: {0}" -f $_) }
try { $d2 = $DistributorServer.ScriptInstallDistributor($SqlInstanceDistributor, $ScriptOptionsDistributor); if ($d2) { $distOut += (Clean-ScriptText -Text $d2) } } catch { Write-Warning ("ScriptInstallDistributor failed: {0}" -f $_) }
$distFile = Join-Path $OutputFolderPath ("1_{0}_Distribution.SQL" -f $SqlInstanceDistributor)
if ($distOut.Count -gt 0) { $distOut | Out-File -FilePath $distFile -Encoding UTF8 }

# --- Helpers to find/discover publications ---
function Get-PublicationByName { param($Server,$Name) foreach ($repDb in $Server.ReplicationDatabases) { try { $p = $repDb.TransPublications | Where-Object { $_.Name -eq $Name } ; if ($p) { return @{ Publication=$p; ReplicationDatabase=$repDb } } } catch { Write-Warning ("Enumerate TransPublications failed for DB {0}: {1}" -f $repDb.Name, $_) } } return $null }
function Discover-Publications {
    param($Server,$SubscriberInstance)
    $found = @()
    foreach ($repDb in $Server.ReplicationDatabases) {
        try {
            foreach ($pub in $repDb.TransPublications) {
                try {
                    if ([string]::IsNullOrEmpty($SubscriberInstance)) { $found += @{ Publication=$pub; ReplicationDatabase=$repDb } }
                    else {
                        $subs = $pub.TransSubscriptions
                        if ($subs -ne $null -and $subs.Count -gt 0) {
                            foreach ($s in $subs) {
                                $matched = $false
                                $candidateProps = @('Subscriber','SubscriberName','SubscriberServer','SubscriberInstance')
                                foreach ($p in $candidateProps) {
                                    if ($s.PSObject.Properties.Match($p).Count -gt 0) {
                                        $val = $s.$p
                                        if ($val -ne $null) { if (([string]$val).ToLower().Contains($SubscriberInstance.ToLower())) { $matched = $true ; break } }
                                    }
                                }
                                if (-not $matched) { try { if (([string]$s).ToLower().Contains($SubscriberInstance.ToLower())) { $matched = $true } } catch {} }
                                if ($matched) { $found += @{ Publication=$pub; ReplicationDatabase=$repDb } ; break }
                            }
                        }
                    }
                } catch { Write-Warning ("Inspect pub {0} in DB {1} failed: {2}" -f $pub.Name, $repDb.Name, $_) }
            }
        } catch { Write-Warning ("Enumerate TransPublications failed for DB {0}: {1}" -f $repDb.Name, $_) }
    }
    return $found
}

# --- 2) Determine publications to script ---
$ResolvedPublications = @()
if ($CustomPublications -and $CustomPublications.Count -gt 0) {
    foreach ($n in $CustomPublications) {
        $r = Get-PublicationByName -Server $PublisherServer -Name $n
        if ($r) { $ResolvedPublications += @{ Publication=$r.Publication; ReplicationDatabase=$r.ReplicationDatabase; Name=$n } } else { Write-Warning ("Publication '{0}' not found; skipping." -f $n) }
    }
} else {
    $discovered = Discover-Publications -Server $PublisherServer -SubscriberInstance $SqlInstanceSubscriber
    if ($discovered.Count -eq 0) { Write-Warning ("No publications discovered for publisher '{0}' subscriber '{1}'." -f $SqlInstancePublisher, $SqlInstanceSubscriber); return }
    foreach ($e in $discovered) { $ResolvedPublications += @{ Publication=$e.Publication; ReplicationDatabase=$e.ReplicationDatabase; Name=$e.Publication.Name } }
}
if ($ResolvedPublications.Count -eq 0) { Write-Warning "No publications resolved. Exiting."; return }

$TargetReplicationDatabases = @{}
foreach ($entry in $ResolvedPublications) { $repDb = $entry.ReplicationDatabase ; if (-not $TargetReplicationDatabases.ContainsKey($repDb.Name)) { $TargetReplicationDatabases[$repDb.Name] = $repDb } }

# --- 2) Enable DB scripts for selected replication DBs ---
$PublicationDBScripts = @()
foreach ($repDbName in $TargetReplicationDatabases.Keys) {
    try { $s = $TargetReplicationDatabases[$repDbName].Script($ScriptOptionsEnableDB); $s = Clean-ScriptText -Text $s ; if ($s) { $PublicationDBScripts += $s } } catch { Write-Warning ("Script EnableDB failed for {0}: {1}" -f $repDbName, $_) }
}

if ($CustomPublications -and $CustomPublications.Count -gt 0) { $enableDbFileName = "2_{0}_EnableDB_for_Replication_Selected.SQL" -f $SqlInstancePublisher }
elseif (-not [string]::IsNullOrEmpty($SqlInstanceSubscriber)) { $enableDbFileName = "2_{0}_EnableDB_for_Replication_to_{1}.SQL" -f $SqlInstancePublisher, $SqlInstanceSubscriber }
else { $enableDbFileName = "2_{0}_EnableDB_for_Replication.SQL" -f $SqlInstancePublisher }
$enableDbFilePath = Join-Path -Path $OutputFolderPath -ChildPath $enableDbFileName
if ($PublicationDBScripts.Count -gt 0) { $PublicationDBScripts | Out-File -FilePath $enableDbFilePath -Encoding UTF8 }

$AllPublicationsScripts = @(); $AllArticlesScripts = @(); $AllSubscriptionsScripts = @()

# --- 3/4/5) Per-publication and collectors ---
$perSuffix = ""
if ($CustomPublications -and $CustomPublications.Count -gt 0) { $perSuffix = "_Selected" }

foreach ($entry in $ResolvedPublications) {
    $pubName = $entry.Name
    $publicationObj = $entry.Publication
    $repDb = $entry.ReplicationDatabase
    $pubFolder = Join-Path -Path $OutputFolderPath -ChildPath $pubName
    if (-not (Test-Path $pubFolder)) { New-Item -Path $pubFolder -ItemType Directory -Force | Out-Null }

    # Publication (3)
    try {
        $ps = $publicationObj.Script($ScriptOptionsPublication); $ps = Clean-ScriptText -Text $ps
        if ($ps) {
            $pfile = Join-Path $pubFolder ("3_{0}_Publication_{1}{2}.SQL" -f $SqlInstancePublisher, $pubName, $perSuffix)
            $ps | Out-File -FilePath $pfile -Encoding UTF8
            $AllPublicationsScripts += ("-- Publication: {0}`r`n" -f $pubName); $AllPublicationsScripts += $ps; $AllPublicationsScripts += ("`r`n-- End Publication {0}`r`n" -f $pubName)
        }
    } catch { Write-Warning ("Publication script failed for {0}: {1}" -f $pubName, $_) }

    # Articles (4)
    $articleScripts = @()
    foreach ($article in $publicationObj.TransArticles) {
        try {
            $as = $article.Script($ScriptOptionsArticles); $as = Clean-ScriptText -Text $as
            if ($as) {
                $articleScripts += $as
                $AllArticlesScripts += ("-- Publication: {0} | Article: {1}`r`n" -f $pubName, $article.Name)
                $AllArticlesScripts += $as
                $AllArticlesScripts += ("`r`n-- End Article {0}`r`n" -f $article.Name)
            }
        } catch { Write-Warning ("Article script failed {0}: {1}" -f $article.Name, $_) }
    }
    if ($articleScripts.Count -gt 0) { $afile = Join-Path $pubFolder ("4_{0}_Articles_{1}{2}.SQL" -f $SqlInstancePublisher, $pubName, $perSuffix); $articleScripts | Out-File -FilePath $afile -Encoding UTF8 }

    # Subscriptions (5) — ***FILTERED BY SUBSCRIBER (Option B)***
    $subscriptionScripts = @()
    foreach ($sub in $publicationObj.TransSubscriptions) {

        # --- Subscriber filtering (contains-match) ---
        if (-not [string]::IsNullOrEmpty($SqlInstanceSubscriber)) {
            $subMatch = $false
            $candidateProps = @('Subscriber','SubscriberName','SubscriberServer','SubscriberInstance')

            foreach ($p in $candidateProps) {
                if ($sub.PSObject.Properties.Match($p).Count -gt 0) {
                    $val = $sub.$p
                    if ($val -ne $null -and ([string]$val).ToLower().Contains($SqlInstanceSubscriber.ToLower())) {
                        $subMatch = $true
                        break
                    }
                }
            }

            if (-not $subMatch) {
                try {
                    if (([string]$sub).ToLower().Contains($SqlInstanceSubscriber.ToLower())) {
                        $subMatch = $true
                    }
                } catch {}
            }

            if (-not $subMatch) { continue }   # skip non-matching subscribers
        }

        # --- Script only matching subscription ---
        try {
            $ss = $sub.Script($ScriptOptionsSubscription); $ss = Clean-ScriptText -Text $ss
            if ($ss) {
                $subscriptionScripts += $ss
                $AllSubscriptionsScripts += ("-- Publication: {0} | Subscriber: {1} | SubscriptionId: {2}`r`n" -f $pubName, $sub.Subscriber, $sub.SubscriptionId)
                $AllSubscriptionsScripts += $ss
                $AllSubscriptionsScripts += ("`r`n-- End Subscription {0}`r`n" -f $sub.SubscriptionId)
            }
        } catch { Write-Warning ("Subscription script failed for {0}: {1}" -f $pubName, $_) }
    }

    if ($subscriptionScripts.Count -gt 0) { $sfile = Join-Path $pubFolder ("5_{0}_Subscriber_{1}{2}.SQL" -f $SqlInstancePublisher, $pubName, $perSuffix); $subscriptionScripts | Out-File -FilePath $sfile -Encoding UTF8 }
}

# --- Decide combined filenames ---
if ($CustomPublications -and $CustomPublications.Count -gt 0) {
    if (-not [string]::IsNullOrEmpty($SqlInstanceSubscriber)) {
        $pubCombinedName = "3_{0}_Publications_to_{1}_Selected.SQL" -f $SqlInstancePublisher, $SqlInstanceSubscriber
        $artCombinedName = "4_{0}_Articles_to_{1}_Selected.SQL" -f $SqlInstancePublisher, $SqlInstanceSubscriber
        $subCombinedName = "5_{0}_Subscriptions_to_{1}_Selected.SQL" -f $SqlInstancePublisher, $SqlInstanceSubscriber
    } else {
        $pubCombinedName = "3_{0}_Publications_Selected.SQL" -f $SqlInstancePublisher
        $artCombinedName = "4_{0}_Articles_Selected.SQL" -f $SqlInstancePublisher
        $subCombinedName = "5_{0}_Subscriptions_Selected.SQL" -f $SqlInstancePublisher
    }
} else {
    if (-not [string]::IsNullOrEmpty($SqlInstanceSubscriber)) {
        $pubCombinedName = "3_{0}_Publications_to_{1}.SQL" -f $SqlInstancePublisher, $SqlInstanceSubscriber
        $artCombinedName = "4_{0}_Articles_to_{1}.SQL" -f $SqlInstancePublisher, $SqlInstanceSubscriber
        $subCombinedName = "5_{0}_Subscriptions_to_{1}.SQL" -f $SqlInstancePublisher, $SqlInstanceSubscriber
    } else {
        $pubCombinedName = "3_{0}_Publications.SQL" -f $SqlInstancePublisher
        $artCombinedName = "4_{0}_Articles.SQL" -f $SqlInstancePublisher
        $subCombinedName = "5_{0}_Subscriptions.SQL" -f $SqlInstancePublisher
    }
}

# --- Write combined files ---
if ($AllPublicationsScripts.Count -gt 0) { $AllPublicationsScripts | Out-File -FilePath (Join-Path $OutputFolderPath $pubCombinedName) -Encoding UTF8 }
if ($AllArticlesScripts.Count -gt 0)     { $AllArticlesScripts     | Out-File -FilePath (Join-Path $OutputFolderPath $artCombinedName) -Encoding UTF8 }
if ($AllSubscriptionsScripts.Count -gt 0){ $AllSubscriptionsScripts| Out-File -FilePath (Join-Path $OutputFolderPath $subCombinedName) -Encoding UTF8 }

Write-Host ("Scripts generated in: {0}" -f $OutputFolderPath)
