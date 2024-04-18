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
Import-DscResource -ModuleName ComputerManagementDsc, xPendingReboot

[System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

Node localhost {

    LocalConfigurationManager 
{
    RebootNodeIfNeeded = $true
}

    xPendingReboot Reboot
{
   Name = "Reboot"
}

    Script Reboot {
        TestScript = {
                        return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
                      }
        SetScript = {
			            New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
			            $global:DSCMachineStatus = 1 
                      }
          GetScript = { return @{result = 'result'}}
                        }


        Computer JoinDomain {
            Name = $ComputerName
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[Script]Reboot"
        }
    }
}