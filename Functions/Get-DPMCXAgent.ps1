#requires -Version 3.0
function Get-DPMCXAgent
{
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
      Version      = $null
      FriendlyVersionName = $null
      DPMServer    = $null
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
      Version      = $null
      FriendlyVersionName = $null
      DPMServer    = $null
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

      #Todo: Get DPM Server information from ActiveOwner File Paths
      # $output.DPMServer = 

    }

    Remove-PSSession -Session $session
  }

  $output | Select-Object -Property ComputerName, Connection, ConnectionError, IsInstalled, Version, FriendlyVersionName, DPMServer
 
  }

 }

}