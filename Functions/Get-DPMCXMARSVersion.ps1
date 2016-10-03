function Get-DPMCXMARSVersion 
{
    [CmdletBinding()]
    param (

        [parameter(ParameterSetName = "GetVersion")]
        [string]$Version,
        [parameter(ParameterSetName = "ListVersion")]
        [switch]$ListVersion
    )

PROCESS {      

            $functionpath = Split-Path -Path ${function:Get-DPMCXMARSVersion}.File
            $modulepath = Split-Path -Path $functionpath
            $mappingtablemodulepath = Join-Path -Path $modulepath -ChildPath 'MARSVersionMappingTable.json'

            $mappingtablepath = $mappingtablemodulepath

            $mappingtable = Get-Content -Path $mappingtablepath -Raw | ConvertFrom-Json

            If ($PSBoundParameters['ListVersion']) {
            
            Write-Verbose -Message "Parameter Set: ListVersion"
            Write-Verbose -Message "mappingtablepath: $mappingtablepath"

            return $mappingtable

            break

             }

        
                  $FriendlyName = ($mappingtable | Where-Object {$_.Name -eq $Version}).FriendlyName
                  $ShortFriendlyName = ($mappingtable | Where-Object {$_.Name -eq $Version}).ShortFriendlyName
                  
                  if (-not ($FriendlyName)) {

                  $FriendlyName = "Unknown MARS build number"

                  }

                
                $output =  [pscustomobject]@{
                MARSVersion = $Version
                MARSVersionFriendlyName = $FriendlyName
                ShortFriendlyName = $ShortFriendlyName
                }

                return $output
   
   }
    
}