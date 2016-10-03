function New-DPMCXServerConfigurationReport
{
 [CmdletBinding()]
  param (
    [ValidateNotNullOrEmpty()]
    [PSCredential] $Credential,
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $DpmServerName = 'localhost',
    [string] $ReportPath,
    [string] $MailEncoding = 'Unicode',
    [string] $MailFrom,
    [string] $MailTo,
    [string] $MailSubject = 'DPM Configuration Status Report',
    [string] $SMTPServer
  )

$ReportGeneratedTimeStamp = Get-Date

$parameters = @{
DpmServerName = $DpmServerName
}

if ($PSBoundParameters.ContainsKey('Credential')) {

$parameters.Add('Credential',$Credential)

}

$DPMServerConfigurationStatus = Get-DPMCXServerConfiguration @parameters

# To do: Error handling and prompt for automatic install using PowerShellGet
Import-Module PScribo

$document = Document 'Server Configuration Status Report' {

                
    Section -Style Heading1 'DPM Servers' {


        Section -Style Heading2 'Server Configuration Status Report' {
            
            Paragraph -Style Heading3 "Report generated on: $ReportGeneratedTimeStamp"
                                  
           $DPMServerConfigurationStatus | Select-Object @{
                  n = 'DPM Server'
                  e = {
                    $_.DPMServer
                  }
                },Connection,Version,
                @{
                  n = 'Active Alerts'
                  e = {
                    $_.ActiveAlerts
                  }
                },
                @{
                  n = 'Agents'
                  e = {
                    $_.ProtectedServers
                  }
                },
                Volumes,
                @{
                  n = 'Vss Snapshots'
                  e = {
                    $_.VssSnapshots
                  }
                },
                @{
                  n = 'Total Disk Capacity'
                  e = {
                    $_.TotalDiskCapacity
                  }
                },
                @{
                  n = 'Unallocated Disk Capacity'
                  e = {
                    $_.UnallocatedDiskCapacity
                  }
                },
                @{
                  n = 'Latest DPM DB Backup'
                  e = {
                    $_.LatestDPMDBBackup
                  }
                },                
                @{
                  n = 'RAM'
                  e = {
                    $_.TotalRAM
                  }
                },
                @{
                  n = 'Page File'
                  e = {
                    $_.PageFileSize
                  }
                },
                @{
                  n = 'Page File Recommended'
                  e = {
                    $_.PageFileSizeRecommended
                  }
                },
                @{
                  n = 'SQL Max RAM'
                  e = {
                    $_.SQLMaxRAM
                  }
                },
                @{
                  n = 'SQL Max RAM Recommended'
                  e = {
                    $_.SQLMaxRAMRecommended
                  }
                },Errors | 
                Table
           
           
           


        }
    }


    Section -Style Heading1 'DPM Server Sizing Guidelines' {
            
           Get-DPMCXSizingBaseline | Table -List
                   
    }

}

$HTMLFile = $document | Export-Document -Path $env:TEMP -Format Html
$body = Get-Content -Path $HTMLFile.FullName | Out-String

 $mailParams=@{
  To= $MailTo
  From= $MailFrom
  Subject= $MailSubject
  SMTPServer= $SMTPServer
  Body = $body 
  BodyAsHTML=$true
  Encoding = $MailEncoding  
 }

# To do: Error handling
Send-MailMessage @mailParams

}