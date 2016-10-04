function New-DPMCXMARSAgentReport
{
 [CmdletBinding()]
  param (
    [ValidateNotNullOrEmpty()]
    [PSCredential] $Credential,
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $ComputerName = 'localhost',
    [string] $ReportPath,
    [string] $MailEncoding = 'Unicode',
    [string] $MailFrom,
    [string[]] $MailTo,
    [string] $MailSubject = 'Microsoft Azure Recovery Services Agent Report',
    [string] $SMTPServer
  )

$ReportGeneratedTimeStamp = Get-Date

$parameters = @{
ComputerName = $ComputerName
}

if ($PSBoundParameters.ContainsKey('Credential')) {

$parameters.Add('Credential',$Credential)

}

$MARSAgentInfo = Get-DPMCXMARSAgent @parameters
$MARSAgentAvailableVersions = Get-DPMCXMARSVersion -ListVersion

# To do: Error handling and prompt for automatic install using PowerShellGet
Import-Module PScribo

$document = Document 'Server Configuration Status Report' {

                
    Section -Style Heading1 'Microsoft Azure Recovery Services Agent Report' {
            
        Paragraph -Style Heading3 "Report generated at: $ReportGeneratedTimeStamp"
        Paragraph -Style Heading3 "Report generated on computer: $($env:computername)"
                                  
           $MARSAgentInfo | Select-Object ComputerName, IsInstalled,Version,@{
                  n = 'Friendly Version Name'
                  e = {
                    $_.FriendlyVersionName
                  }
                },DPMIsInstalled,Connection,ConnectionError | 
                Table

BlankLine

Paragraph -Style Heading2 "Available versions"
$MARSAgentAvailableVersions | Select-Object @{
                  n = 'Version'
                  e = {
                    $_.Name
                  }
                },@{
                  n = 'Friendly Name'
                  e = {
                    $_.FriendlyName
                  }
                }, Description | Table

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
  ErrorAction = 'Stop'
 }

try {

    Send-MailMessage @mailParams

    Write-Output "MARS report sent successfully to $MailTo using SMTP server $SMTPServer"

}

catch {

    Write-Output "An error occured while trying to send the MARS report to $MailTo using SMTP server $SMTPServer : $($_.Exception.Message)"

}

}