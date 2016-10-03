#requires -Version 2.0
function Get-DPMCXRecoveryPointStatus 
{
  [CmdletBinding()]
  param (
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $DpmServerName = 'localhost',
    [datetime] $OlderThan
  )

  begin {

    $output  = @()

  }


  process {

    Foreach ($computer in $DpmServerName) 
    {
      Write-Verbose -Message "Processing computer $computer"

      Remove-Variable -Name session -ErrorAction Ignore

      try 
      {
        $session = New-PSSession -ComputerName $computer -ErrorAction Stop
      }

      catch 
      {
        $output += New-Object -TypeName pscustomobject -Property @{
          'DPMServer'         = $computer
          'DataSource'        = $null
          'ProtectedComputer' = $null
          'ProtectionGroup'   = $null
          'LatestRecoveryPoint' = $null
          'Status'            = 'Failed to connect to DPM Server'
        }
      }

      $InitializeDPMCXDataSourcePropertyDefinition = "function Initialize-DPMCXDataSourceProperty { ${function:Initialize-DPMCXDataSourceProperty} }"

      if ($session) 
      {
        try 
        {
          Write-Verbose -Message 'Connected via PowerShell remoting, gathering Data Sources'

          $DPMDatasources = Invoke-Command -Session $session -ScriptBlock {
            try 
            {
              . ([ScriptBlock]::Create($using:InitializeDPMCXDataSourcePropertyDefinition))

              Import-Module -Name DataProtectionManager -ErrorAction Stop

              $VerbosePreference = $Using:VerbosePreference

              $HostName = [System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName

              $DPMServerConnection = Connect-DPMServer -DPMServerName $HostName -WarningAction SilentlyContinue

              $DPMDatasources = Get-DPMDatasource -DPMServerName $HostName -WarningAction SilentlyContinue

              Write-Verbose -Message 'Invoking Initialize-DPMCXDataSourceProperty'
              Initialize-DPMCXDataSourceProperty -DataSource $DPMDatasources

              $DPMDatasources = $DPMDatasources | ForEach-Object -Process {
                $computer = $_.Computer
                $ProductionServerName = $_.ProductionServerName
                $ProtectionGroup = $_.ProtectionGroup

                Write-Verbose -Message "Processing Data Source $ProductionServerName"

                $ProtectedObjects = $_.GetProtectedObjects()

                $LatestRecoveryPoint = $_.LatestRecoveryPoint

                $ProtectedObjects = $_.GetProtectedObjects()

                if ($ProtectedObjects) 
                {
                  $_ | Select-Object -Property Computer, name, objecttype, currentlyprotected, @{
                    n = 'LatestRecoveryPoint'
                    e = {
                      $LatestRecoveryPoint
                    }
                  }, ProductionServerName, ProtectionGroup

                  $ProtectedObjects | Select-Object -Property @{
                    n = 'Computer'
                    e = {
                      $computer
                    }
                  }, @{
                    n = 'name'
                    e = {
                      $_.DisplayPath
                    }
                  }, objecttype, currentlyprotected, @{
                    n = 'LatestRecoveryPoint'
                    e = {
                      $LatestRecoveryPoint
                    }
                  }, @{
                    n = 'ProductionServerName'
                    e = {
                      $ProductionServerName
                    }
                  }, @{
                    n = 'ProtectionGroup'
                    e = {
                      $ProtectionGroup
                    }
                  }
                }
                else 
                {
                  $_ | Select-Object -Property Computer, name, objecttype, currentlyprotected, @{
                    n = 'LatestRecoveryPoint'
                    e = {
                      $LatestRecoveryPoint
                    }
                  }, @{
                    n = 'ProductionServerName'
                    e = {
                      $ProductionServerName
                    }
                  }, @{
                    n = 'ProtectionGroup'
                    e = {
                      $ProtectionGroup
                    }
                  }
                }
              }


              if ($using:OlderThan) 
              {
                $DPMDatasources |
                Where-Object -FilterScript {
                  $_.CurrentlyProtected -and ($_.LatestRecoveryPoint -lt $using:OlderThan)
                } |
                Select-Object -Property @{
                  n = 'DPMServer'
                  e = {
                    $env:computername
                  }
                }, @{
                  n = 'ProtectedComputer'
                  e = {
                    $_.ProductionServerName
                  }
                }, @{
                  n = 'ProtectionGroup'
                  e = {
                    $_.ProtectionGroup.FriendlyName
                  }
                }, @{
                  n = 'DataSource'
                  e = {
                    $_.Name
                  }
                }, LatestRecoveryPoint, @{
                  n = 'Status'
                  e = {
                    "Recovery point older than $using:OlderThan"
                  }
                }
              }
              else 
              {
                $DPMDatasources |
                Where-Object -FilterScript {
                  $_.CurrentlyProtected
                } |
                Select-Object -Property @{
                  n = 'DPMServer'
                  e = {
                    $env:computername
                  }
                }, @{
                  n = 'ProtectedComputer'
                  e = {
                    $_.ProductionServerName
                  }
                }, @{
                  n = 'ProtectionGroup'
                  e = {
                    $_.ProtectionGroup.FriendlyName
                  }
                }, @{
                  n = 'DataSource'
                  e = {
                    $_.Name
                  }
                }, LatestRecoveryPoint, @{
                  n = 'Status'
                  e = {

                  }
                }
              }

              Write-Verbose -Message 'Finished processing Data Sources, disconnecting from DPM Server'

              Disconnect-DPMServer
            }

            catch 
            {
              Write-Verbose -Message "An error occured: $($_.Exception.Message)"
          
              throw $_.Exception.Message
          
              break
            }
          } -ErrorAction Stop -Verbose | Select-Object -Property DPMServer, ProtectedComputer, ProtectionGroup, DataSource, LatestRecoveryPoint, Status
        }

        catch 
        {
          $DPMDatasources += New-Object -TypeName pscustomobject -Property @{
            'DPMServer'         = $computer
            'DataSource'        = $null
            'ProtectedComputer' = $null
            'ProtectionGroup'   = $null
            'LatestRecoveryPoint' = $null
            'Status'            = "An error occured gathering data: $($_.Exception.Message)"
          }
        }

        Write-Verbose -Message 'Removing PowerShell Remoting session'

        Remove-PSSession -Session $session
      }


      if ($DPMDatasources) 
      {
        $output += $DPMDatasources
      }
      else 
      {
        if ($session) 
        {
          $output += New-Object -TypeName pscustomobject -Property @{
            DPMServer           = $computer
            ProtectedComputer   = $null
            ProtectionGroup     = $null
            DataSource          = $null
            LatestRecoveryPoint = $null
            Status              = "No latest recovery point older than $OlderThan found"
          }
        }
      }
    }

  }

  end {
  
    return $output

  }
}