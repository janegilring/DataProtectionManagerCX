function Test-DPMCXComputer {

  [CmdletBinding()]
  param (
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $ComputerName = 'localhost'
  )

  try 
  {
    $session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop

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
    $output = New-Object -TypeName pscustomobject -Property @{
      ComputerName = $session.ComputerName
      Connection   = 'Failed'
      ConnectionError = $null
      IsInstalled  = $null
      IsDPMServer    = $null
      FriendlyVersionName = $null
      Version      = $null
    }
  }

  if ($session) 
  {
    $DPMAgentIsInstalled = Invoke-Command -Session $session -ScriptBlock {
      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager'
    }

    if ($DPMAgentIsInstalled) 
    {
      $output.IsInstalled = $DPMAgentIsInstalled

      
      $DPMVersionInfo     = Invoke-Command -Session $session -ScriptBlock {

        try 
        {
          $Path = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup' -ErrorAction Stop).InstallPath
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

        if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup' -Name DatabasePath -ErrorAction Ignore) {
          
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