Configuration Computer_JoinDomainSpecifyingDC_Config
{
    param
     (

         [Parameter(Mandatory)]
         [String]$ComputerName,

         [Parameter(Mandatory)]
         [String]$DomainName,
 
         [Parameter(Mandatory)]
         [System.Management.Automation.PSCredential]$Admincreds



     )



    Import-DscResource -ModuleName ComputerManagementDsc

[System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost {
        Computer JoinDomain {
            Name = $ComputerName
            DomainName = $DomainName
            Credential = $DomainCreds
        }
    }
}





