function Test-DPMCXComputer {

  [CmdletBinding()]
  param (
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('__Server','CN')]
    [ValidateNotNullOrEmpty()]
    [string[]] $ComputerName = 'localhost'
  )


Process {

foreach ($Computer in $ComputerName) {

  try 
  {
    $session = New-PSSession -ComputerName $Computer -ErrorAction Stop

    Write-Verbose -Message "Connected to $Computer via PowerShell remoting, gathering DPM information..."

    $output  = New-Object -TypeName pscustomobject -Property @{
      ComputerName = $session.ComputerName
      Connection   = 'Success'
      ConnectionError = $null
      IsInstalled  = $null
      IsDPMServer    = $null
      FriendlyVersionName = $null
      Version      = $null
    }
  }

  catch 
  {

    Write-Verbose -Message "Failed to connect to $Computer via PowerShell remoting..."

    $output = New-Object -TypeName pscustomobject -Property @{
      ComputerName = $Computer
      Connection   = 'Failed'
      ConnectionError = $_.Exception
      IsInstalled  = $null
      IsDPMServer    = $null
      FriendlyVersionName = $null
      Version      = $null
    }

      if ($session) 
          {
            Remove-Variable -Name session
          }

  }

  if ($session) 
  {
    $DPMAgentIsInstalled = Invoke-Command -Session $session -ScriptBlock {

      $VerbosePreference = $using:VerbosePreference

      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager'
    }

    $output.IsInstalled = $DPMAgentIsInstalled


    if ($DPMAgentIsInstalled) 
    {
      
      
      $DPMVersionInfo     = Invoke-Command -Session $session -ScriptBlock {

        try 
        {
          
          $Path = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup' -ErrorAction Stop).InstallPath

          Write-Verbose -Message "DPM is installed on $($env:ComputerName)"

        }

        catch 
        {
          Write-Verbose -Message "DPM not installed on $($env:ComputerName)"
          break
        }

        $DPMRAPath = Join-Path -Path $Path -ChildPath bin\DPMRA.exe

        (Get-Item -Path $DPMRAPath).VersionInfo.FileVersion
      }

      if ($DPMVersionInfo) 
      {
        $output.Version = $DPMVersionInfo
        $output.FriendlyVersionName = (Get-DPMCXVersion -Version $DPMVersionInfo).DPMVersionFriendlyName
      }
    }

        $DPMServerIsInstalled = Invoke-Command -Session $session -ScriptBlock {
      
      if (Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup') {

        if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup' -Name DatabasePath -ErrorAction SilentlyContinue) {
          
            $true

        }

        else {

            $false

        }

      } else {

          $false

      }

    }


        $output.ISDPMServer = $DPMServerIsInstalled
      

    Remove-PSSession -Session $session
    }

    $output | Select-Object -Property ComputerName, Connection, IsInstalled, IsDPMServer, Version, FriendlyVersionName, ConnectionError

  }

 }

}