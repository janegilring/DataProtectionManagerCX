function Get-DPMCXVersion 
{
    [CmdletBinding()]
    param (

        [parameter(ParameterSetName = "GetVersion")]
        [string]$Version,
        [parameter(ParameterSetName = "ListVersion")]
        [switch]$ListVersion
    )

    BEGIN {        

            $functionpath = Split-Path -Path ${function:Get-DPMVersion}.File
            $modulepath = Split-Path -Path $functionpath
            $mappingtablemodulepath = Join-Path -Path $modulepath -ChildPath 'DPMVersionMappingTable.json'

            $mappingtablepath = $mappingtablemodulepath

            $mappingtable = Get-Content -Path $mappingtablepath -Raw | ConvertFrom-Json

            If ($PSBoundParameters['ListVersion']) {
            
            Write-Verbose -Message "Parameter Set: ListVersion"
            Write-Verbose -Message "mappingtablepath: $mappingtablepath"

            return $mappingtable
            break

             }

        
        }

    PROCESS {

                  $FriendlyName = ($mappingtable | Where-Object {$_.Name -eq $Version}).FriendlyName
                  
                  if (-not ($FriendlyName)) {

                  $FriendlyName = "Unknown DPM build number"

                  }

                
                $output =  [pscustomobject]@{
                DPMVersion = $Version
                DPMVersionFriendlyName = $FriendlyName
                }

                return $output
   
   }
    
}