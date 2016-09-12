#requires -Version 3.0
function Get-DPMAgent
{
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
      IsInstalled  = $null
      Version      = $null
      FriendlyVersionName = $null
      DPMServer    = $null
    }
  }

  catch 
  {
    $output = New-Object -TypeName pscustomobject -Property @{
      ComputerName = $env:ComputerName
      Connection   = 'Success'
      IsInstalled  = $null
      Version      = $null
      FriendlyVersionName = $null
      DPMServer    = $null
    }
  }

  if ($session) 
  {
    $DPMAgentIsInstalled = Invoke-Command -Session $session -ScriptBlock {
      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager'
    }

  $output.IsInstalled = $DPMAgentIsInstalled

    if ($DPMAgentIsInstalled) 
    {  

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
        $output.FriendlyVersionName = (Get-DPMVersion -Version $DPMVersionInfo).DPMVersionFriendlyName
      }

      #Todo: Get DPM Server information from ActiveOwner File Paths
      # $output.DPMServer = 

    }

    Remove-PSSession -Session $session
  }

  $output | Select-Object -Property ComputerName, Connection, IsInstalled, Version, FriendlyVersionName, DPMServer

}