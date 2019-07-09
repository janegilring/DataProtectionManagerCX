<#
Helper function used "as-is" based on:
https://blogs.technet.microsoft.com/dpm/2010/09/11/why-good-scripts-may-start-to-fail-on-you-for-instance-with-timestamps-like-01010001-000000/
https://winception.wordpress.com/2010/12/17/dpm-management-shell-to-find-recovery-points-in-data-protection-manager/
#>

Function Initialize-DPMCXDataSourceProperty ($DataSource) {

$Eventcount = 0
For($i = 0;$i -lt $datasource.count;$i++)
{
[void](Register-ObjectEvent $datasource[$i] -EventName DataSourceChangedEvent -SourceIdentifier "DPMExtractEvent$i" -Action{$Eventcount++})
}
$datasource | Select-Object LatestRecoveryPoint,Computer > $null
$begin = Get-Date
While (((Get-Date).subtract($begin).seconds -lt 30) -and ($Eventcount -lt $datasource.count) ) {Start-Sleep -Milliseconds 500}
Unregister-Event -SourceIdentifier DPMExtractEvent* -Confirm:$false

}
