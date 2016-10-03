#requires -Version 3.0
function Get-DPMCXMARSAgent
{
  [CmdletBinding()]
  param (
    [ValidateNotNullOrEmpty()]
    [PSCredential] $Credential,
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('__Server','CN')]
    [ValidateNotNullOrEmpty()]
    [string[]] $ComputerName = 'localhost'
  )


Process {

foreach ($Computer in $ComputerName) {

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

    $output  = New-Object -TypeName pscustomobject -Property @{
      ComputerName = $session.ComputerName
      Connection   = 'Success'
      ConnectionError = $null
      IsInstalled  = $null
      Version      = $null
      FriendlyVersionName = $null
      DPMIsInstalled = $null
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
      DPMIsInstalled = $null
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

      Write-Verbose -Message "Connected to $using:Computer via PowerShell remoting as user $($env:username), gathering MARS information..."

      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager'

    }

    $MARSAgentIsInstalled = Invoke-Command -Session $session -ScriptBlock {

      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows Azure Backup\Setup'

    }

  $output.IsInstalled = $MARSAgentIsInstalled
  $output.DPMIsInstalled = $DPMAgentIsInstalled 
  
    if ($MARSAgentIsInstalled) 
    {  

      $MARSVersionInfo     = Invoke-Command -Session $session -ScriptBlock {

        try 
        {
          $Path = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Azure Backup\Setup' -ErrorAction Stop).InstallPath
          Write-Verbose -Message "Microsoft Azure Recovery Services Agent is installed on $($env:ComputerName)"
        }

        catch 
        {
          Write-Verbose -Message "Microsoft Azure Recovery Services Agent not installed on $($env:ComputerName)"
          break
        }

        $CBEnginePath = Join-Path -Path $Path -ChildPath bin\cbengine.exe

        (Get-Item -Path $CBEnginePath).VersionInfo.FileVersion
      }

      if ($MARSVersionInfo) 
      {
        $output.Version = $MARSVersionInfo
        $output.FriendlyVersionName = (Get-DPMCXMARSVersion -Version $MARSVersionInfo).MARSVersionFriendlyName
      }

    }

    Remove-PSSession -Session $session
  }

  $output | Select-Object -Property ComputerName, Connection, ConnectionError, IsInstalled, Version, FriendlyVersionName, DPMIsInstalled
 
  }

 }

}