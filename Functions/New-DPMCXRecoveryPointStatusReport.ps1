function New-DPMCXRecoveryPointStatusReport
{

 [CmdletBinding()]
  param (
    [ValidateNotNullOrEmpty()]
    [PSCredential] $Credential,
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $DpmServerName = 'localhost',
    [datetime] $OlderThan,
    [string] $ReportPath,
    [string] $MailEncoding = 'Unicode',
    [string] $MailFrom,
    [string[]] $MailTo,
    [string] $MailSubject = 'DPM Recovery Point Status Report',
    [string] $SMTPServer
  )

$ReportGeneratedTimeStamp = Get-Date

$parameters = @{
DpmServerName = $DpmServerName
}

if ($PSBoundParameters.ContainsKey('Credential')) {

$parameters.Add('Credential',$Credential)

}

if ($PSBoundParameters.ContainsKey('OlderThan')) {

$parameters.Add('OlderThan',$OlderThan)

}

$DPMRecoveryPointStatus = Get-DPMCXRecoveryPointStatus @parameters

# To do: Error handling and prompt for automatic install using PowerShellGet
Import-Module PScribo

$document = Document 'DPM Recovery Point Status Report' {

                
                 Style -Name 'AttentionRequired' -Color White -BackgroundColor Red -Bold


    Section -Style Heading1 'DPM Servers' {


        Section -Style Heading2 'DPM Recovery Point Status Report' {
            
            Paragraph -Style Heading3 "Report generated at: $ReportGeneratedTimeStamp"
            Paragraph -Style Heading3 "Report generated on computer: $($env:computername)"

            if ($OlderThan) {
            
            Paragraph -Style Heading3 "Threshold: Recovery Points older than $OlderThan"

            $DPMRecoveryPointStatus |  Where-Object { $_.LatestRecoveryPoint -ne $null} | Where-Object { $_.LatestRecoveryPoint -lt $OlderThan} | Set-Style -Style 'AttentionRequired'

            $DPMRecoveryPointStatus | Table -Columns DPMServer,Status,ProtectionGroup,ProtectedComputer,DataSource,LatestRecoveryPoint,Connection,Errors
            
            } else {
            
            Paragraph -Style Heading3 "Recovery Point status"

            $DPMRecoveryPointStatus | Table -Columns DPMServer,Status,ProtectionGroup,ProtectedComputer,DataSource,LatestRecoveryPoint,Connection,Errors


            }
            
            

        }
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