function Get-DPMCXServerConfiguration {
  [CmdletBinding()]
  param (
    [ValidateNotNullOrEmpty()]
    [PSCredential] $Credential,
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $DpmServerName = 'localhost'
  )

  begin {

    $output  = @()

  }


  process {

    Foreach ($computer in $DpmServerName) 
    {
      Write-Verbose -Message "Processing computer $computer"

      Remove-Variable -Name session -ErrorAction Ignore

      $PSSessionParameters = @{

         ComputerName = $computer
         ErrorAction = 'Stop'

      }

      if ($PSBoundParameters.ContainsKey('Credential')) {

         $PSSessionParameters.Add('Credential',$Credential)

      }

      try 
      {
        $session = New-PSSession @PSSessionParameters
      }

      catch 
      {
        $output += New-Object -TypeName pscustomobject -Property @{
          'DPMServer' = $computer
          'Connection'   = 'Failed'
          'Status' = "Connection error: $($_.Exception.Message)"
          'Active alerts' = $null
          'Shadow Copy snapshots' = $null
          'Volumes' = $null
          'TotalDiskCapacity' = $null
          'UnallocatedDiskCapacity' = $null
          'ProtectedServers'= $null
          'Last DPM DB backup' = $null
          'Version' = $null
          'Page File'= $null
          'Page File Recommended' = $null
          'Total RAM'= $null
          'SQL Max RAM'= $null
          'SQL Max Recommended RAM' = $null
        }
      }


      if ($session) 
      {
        try 
        {
          
          $DPMConfigurationData = Invoke-Command -Session $session -ScriptBlock {
       
            
            try 
            {
              
              Import-Module -Name DataProtectionManager -ErrorAction Stop -Verbose:$false

              $VerbosePreference = $Using:VerbosePreference

              Write-Verbose -Message "Connected via PowerShell remoting as user $($env:username), gathering DPM configuration information..."

              $HostName = [System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName

              $DPMServerConnection = Connect-DPMServer -DPMServerName $HostName -WarningAction SilentlyContinue

#region Data gathering

                $TotalDiskCapacity = 0
                $UnallocatedDiskCapacity = 0

                Write-Verbose -Message "Collecting disk information"

                foreach ($disk in (Get-DPMDisk -DpmServerName $HostName)) {

                $TotalDiskCapacity += $disk.totalcapacity
                $UnallocatedDiskCapacity += $disk.unallocatedspace


                }


                Write-Verbose -Message "Collecting DPM information from DPM SQL Server instance"
                # Disable due to lots of noice from loading SQL commands (such as warnings related to 'Microsoft.WindowsAzure.Commands.SqlDatabase.Types.ps1xml')
                $VerbosePreference = 'SilentlyContinue'
                $WarningPreference = 'SilentlyContinue'

                try {

                $SQLInstance = ($DPMServerConnection.DBConnectionString -split ';')[3] -replace 'server=',''

                if (-not $SQLInstance) {

                $SQLInstance = ($DPMServerConnection.DBConnectionString -split ';')[3] -replace 'server=tcp:',''

                }

                [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

                $SQL = New-Object('Microsoft.SqlServer.Management.Smo.Server') -ArgumentList $SQLInstance

                $lastbackupdate = $SQL.Databases | Where-Object {$_.Name -like "*DPMDB*"} | Select-Object -ExpandProperty lastbackupdate
                }

                catch {

                $lastbackupdate = 'N/A'

                }

                $TotalRAM = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory
                $TotalRAMGB = [math]::Round($TotalRAM/1GB)

                $SQLMaxServerRecommendedMemory = [math]::Round(($TotalRAM * 0.6)/1MB)

                $SQLMaxServerMemory = $SQL.Configuration.MaxServerMemory.ConfigValue


                $DPMPS = Get-DPMProductionServer -DPMServerName $HostName | Where-Object {$_.machinename -eq $env:computername}
                $Version = ($DPMPS.InstalledAgents | Select-Object -ExpandProperty agent | Select-Object -ExpandProperty version).ToString()

                if (Get-PSSnapin -Registered -Name sqlservercmdletsnapin100 -ErrorAction silentlycontinue) {

                Add-PSSnapin -Name sqlservercmdletsnapin100


                }

                # Find out where DPMDB is located
                $DPMDB = $DPMServerConnection.dpmdatabaselogicalpath.substring($DPMServerConnection.DPMDatabaseLogicalPath.LastIndexOf('\') + 1,$DPMServerConnection.DPMDatabaseLogicalPath.Length - $DPMServerConnection.DPMDatabaseLogicalPath.LastIndexOf('\') -1 )
                $DPMSQLInstance   = $DPMServerConnection.dpmdatabaselogicalpath.substring(0,$DPMServerConnection.DPMDatabaseLogicalPath.LastIndexOf('\'))
                $GB    = 1 / 1024 / 1024 / 1024
                $Query = "  declare @total bigint
                            select distinct volume.GuidName,volume.VolumeSize into #test
                            from tbl_SPM_Volume Volume 
                            join tbl_SPM_VolumeSet VolumeSet on VolumeSet.VolumeSetId=Volume.VolumeSetId 
                            join tbl_PRM_LogicalReplica Replica on Replica.PhysicalReplicaId=VolumeSet.VolumeSetId 
                            where Replica.Validity not in (0,4)  -- [Allocated = 0,Invalid = 1,Valid = 2,Missing = 3,Destroyed = 4,ProtectionStopped = 5,Inactive = 6]
                            and volume.usage = 2   -- Replica=1, DiffArea=2
                            select @total = SUM(volumesize) from #test
                            insert into #test values ('=Total RP volume size',@total)
                            select @total = (SUM(volumesize)*.002) from #test
                            where GuidName like '%=Total%'
                            insert into #test values ('Additional pagefile size reqd in BYTES',@total)
                            select @total = (SUM(volumesize)/1024) from #test
                            where GuidName like '%BYTES%'
                            insert into #test values ('Additional pagefile size reqd in MB',@total)
                            select * from #test order by guidname
                            drop table #test" 

                $RPPageFile          = (invoke-sqlcmd -serverinstance $DPMSQLInstance -query $query -MaxCharLength 10000000 -Database $DPMDB)
                $CurrentPageFileSize = 0
                $CurrentPageFiles    = @(Get-WmiObject Win32_pagefileusage)
                foreach ($PageFile in $CurrentPageFiles)
                {
                    $CurrentPageFileSize += $PageFile.AllocatedBaseSize * 1024 * 1024
                }
                $TotalRAM = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory

                $PageFile = "{0:N0} GB" -f ($CurrentPageFileSize * $GB)
                $PageFileRecommended = "{0:N0} GB" -f (($TotalRAM * 1.5 + $RPPageFile[-3].VolumeSize *.002) * $GB)

                $VssShadows = vssadmin list shadows | Select-String 'Shadow Copy ID'

                $ProtectedServers = Get-DPMProductionServer -DpmServerName $HostName | Where-Object {$_.ServerProtectionState -eq 'HasDataSourcesProtected'}

                $Alerts = (Get-DPMAlert -DpmServerName $HostName | Where-Object {$_.Severity -eq 'Error' -or $_.Severity -eq 'Warning'}).Count

                if (-not $Alerts) {

                $Alerts = 0

                }

                $DPMVolumes = Get-DPMVolume -DpmServerName $HostName -AlreadyInUseByDPM

                #endregion

              $VerbosePreference = $Using:VerbosePreference


                New-Object -TypeName pscustomobject -Property @{
                    'DPMServer' = $using:computer
                    'Connection'   = 'Success'
                    'Errors' = $null
                    'ActiveAlerts' = $Alerts
                    'VssSnapshots' = $VssShadows.Count
                    'Volumes' = $DPMVolumes.Count
                    'TotalDiskCapacity' = ("{0:n0}" -f  ($TotalDiskCapacity / 1GB) + " GB")
                    'UnallocatedDiskCapacity' = ("{0:n0}" -f  ($UnallocatedDiskCapacity / 1GB) + " GB")
                    'ProtectedServers'= $ProtectedServers.count
                    'LatestDPMDBBackup' = $lastbackupdate
                    'Version' = $Version
                    'PageFileSize'= $PageFile
                    'PageFileSizeRecommended' = $PageFileRecommended
                    'TotalRAM'= ("{0:N0}" -f $TotalRAMGB + ' GB')
                    'SQLMaxRAM'= ("{0:N0}" -f $SQLMaxServerMemory + ' MB')
                    'SQLMaxRAMRecommended' = ("{0:N0}" -f $SQLMaxServerRecommendedMemory + ' MB')
                }

              Write-Verbose -Message 'Finished processing data gathering, disconnecting from DPM Server'

              Disconnect-DPMServer

            }

            catch 
            {
              Write-Verbose -Message "An error occured: $($_.Exception.Message)"
          
              throw $_.Exception.Message
          
              break
            }
          } -ErrorAction Stop -Verbose | Select-Object -Property DPMServer, Connection, Errors, ActiveAlerts, VssSnapshots, Volumes, TotalDiskCapacity, UnallocatedDiskCapacity, ProtectedServers, LatestDPMDBBackup, Version, PageFileSize, PageFileSizeRecommended, TotalRAM, SQLMaxRAM, SQLMaxRAMRecommended
        }

        catch 
        {
          $DPMConfigurationData += New-Object -TypeName pscustomobject -Property @{
          'DPMServer' = $computer
          'Connection'   = 'Success'
          'Errors' = "An error occured gathering data: $($_.Exception.Message)"
          'ActiveAlerts' = $null
          'VssSnapshots' = $null
          'Volumes' = $null
          'TotalDiskCapacity' = $null
          'UnallocatedDiskCapacity' = $null
          'ProtectedServers'= $null
          'LatestDPMDBBackup' = $null
          'Version' = $null
          'PageFileSize'= $null
          'PageFileSizeRecommended' = $null
          'TotalRAM'= $null
          'SQLMaxRAM'= $null
          'SQLMaxRAMRecommended' = $null
        }
        }

        Write-Verbose -Message 'Removing PowerShell Remoting session'

        Remove-PSSession -Session $session
      }


      if ($DPMConfigurationData) 
      {

if (($DPMConfigurationData).Version) {

    $DPMFriendlyVersion = Get-DPMCXVersion -Version $DPMConfigurationData.Version

    if ($DPMFriendlyVersion.DPMVersionFriendlyName -ne 'Unknown DPM build number') {

        $DPMConfigurationData.Version = $DPMFriendlyVersion.ShortFriendlyName

    }

}

        $output += $DPMConfigurationData

      }

    }

  }

  end {
  
    return $output

  }

}