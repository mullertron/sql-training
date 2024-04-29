param(
    [string]$storageAccountName,
    [string]$containersToCreate,
    [string]$resourceGroupName,
    [string]$domain,
    [string]$PWord,
    [string]$serviceacc,
    [string]$vmname
)

Connect-AzAccount -Identity
$containers = $containersToCreate | ConvertFrom-Json -AsHashtable
$stg = Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName
$context = $stg.Context
$UName = "$domain\$serviceacc"
$domain = $domain
$SMOWmiserver = '$SMOWmiserver'
$ChangeService = '$ChangeService'
$_ = '$_'

$powershellContentOne = @"
$UName = "$domain\$serviceacc"
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | out-null
$SMOWmiserver = New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer") 
$SMOWmiserver.Services | select name, type, ServiceAccount, DisplayName, Properties, StartMode, StartupParameters | Format-Table
$SMOWmiserver.Services | select name, type, ServiceAccount, DisplayName, Properties, StartMode, StartupParameters | Format-List
$ChangeService=$SMOWmiserver.Services | where {$_.name -eq "MSSQLSERVER"} 
$ChangeService
$ChangeService.SetServiceAccount('$UName', '$PWord')
.\updateSQLAgent.ps1
"@



$powershellContentTwo = @"  
$UName = "$domain\$serviceacc"
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | out-null 
$SMOWmiserver = New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer") 
$SMOWmiserver.Services | select name, type, ServiceAccount, DisplayName, Properties, StartMode, StartupParameters | Format-Table
$SMOWmiserver.Services | select name, type, ServiceAccount, DisplayName, Properties, StartMode, StartupParameters | Format-List
$ChangeService=$SMOWmiserver.Services | where {$_.name -eq "SQLSERVERAGENT"} 
$ChangeService
$ChangeService.SetServiceAccount('$UName, '$PWord')
"@ 


$powershellContentOne  | Out-File -Encoding UTF8 "updateSQLService.ps1"
$powershellContentTwo  | Out-File -Encoding UTF8 "updateSQLAgent.ps1"


foreach ($container in $containers.keys) {
    Write-Host "`n Creating container $container"
    New-AzStorageContainer -Name $container -Context $context -Permission Off
    Write-Host "`n Creating blobs in $container container"
    foreach ($blob in $containers[$container]) {
        Write-Host "`n Creating blob $blob"
        $Blob1HT = @{
            File             = "./$blob"
            Container        = $container
            Blob             = $blob
            Context          = $context
            StandardBlobTier = 'Hot'
        }
        Set-AzStorageBlobContent @Blob1HT
    }
}