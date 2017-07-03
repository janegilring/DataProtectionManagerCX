#requires -Version 3.0
function Get-DPMCXAgent
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
      AzureRecoveryServicesAgentIsInstalled = $null
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
      AzureRecoveryServicesAgentIsInstalled = $null
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

      Write-Verbose -Message "Connected to $using:Computer via PowerShell remoting as user $($env:username), gathering DPM information..."

      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager'

    }

    $MARSAgentIsInstalled = Invoke-Command -Session $session -ScriptBlock {

      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows Azure Backup\Setup'

    }

  $output.IsInstalled = $DPMAgentIsInstalled
  $output.AzureRecoveryServicesAgentIsInstalled = $MARSAgentIsInstalled 
      
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

      $output.DPMServer = (((Get-DPMCXAgentOwner -ComputerName $ComputerName).DPMServerName | Sort-Object -Unique ) -join ',' )

    }

    Remove-PSSession -Session $session
  }

  $output | Select-Object -Property ComputerName, Connection, ConnectionError, IsInstalled, Version, FriendlyVersionName, DPMServer, AzureRecoveryServicesAgentIsInstalled
 
  }

 }

}