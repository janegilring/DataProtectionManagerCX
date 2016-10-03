function New-DPMCXRecoveryPointStatusReport
{

 [CmdletBinding()]
  param (
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $DpmServerName = 'localhost',
    [datetime] $OlderThan,
    [string] $ReportPath,
    [string] $MailFrom,
    [string] $MailTo,
    [string] $MailSubject = 'DPM Recovery Point Status Report',
    [string] $SMTPServer
  )

$ReportGeneratedTimeStamp = Get-Date

$parameters = @{
DpmServerName = $DpmServerName
}

if ($OlderThan) {

$parameters.Add('OlderThan',$OlderThan)

}

$DPMRecoveryPointStatus = Get-DPMCXRecoveryPointStatus @parameters

# To do: Error handling and prompt for automatic install using PowerShellGet
Import-Module PScribo

$document = Document 'DPM Recovery Point Status Report' {

                
                 Style -Name 'AttentionRequired' -Color White -BackgroundColor Red -Bold


    Section -Style Heading1 'DPM Servers' {


        Section -Style Heading2 'DPM Recovery Point Status Report' {
            
            Paragraph -Style Heading3 "Report generated on: $ReportGeneratedTimeStamp"

            if ($OlderThan) {
            
            Paragraph -Style Heading3 "Threshold: Recovery Points older than $OlderThan"

            #$DPMRecoveryPointStatus | Where-Object { $_.Status.ToString() -ne ''} | Set-Style -Style 'AttentionRequired'
            $DPMRecoveryPointStatus |  Where-Object { $_.LatestRecoveryPoint -ne $null} | Where-Object { $_.LatestRecoveryPoint -lt $OlderThan} | Set-Style -Style 'AttentionRequired'

            $DPMRecoveryPointStatus | Table -Columns DPMServer,ProtectionGroup,ProtectedComputer,DataSource,LatestRecoveryPoint,Status -ColumnWidths 15,15,15,15,15,25 -Headers DPMServer,ProtectionGroup,ProtectedComputer,DataSource,LatestRecoveryPoint,Status
            
            } else {
            
            Paragraph -Style Heading3 "Recovery Point status"

            $DPMRecoveryPointStatus | Table -Columns DPMServer,ProtectionGroup,ProtectedComputer,DataSource,LatestRecoveryPoint,Status -ColumnWidths 15,15,15,15,15,25 -Headers DPMServer,ProtectionGroup,ProtectedComputer,DataSource,LatestRecoveryPoint,Status


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
 }

# To do: Error handling
Send-MailMessage @mailParams

}