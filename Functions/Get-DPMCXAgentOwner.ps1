#requires -Version 3.0
function Get-DPMCXAgentOwner
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

       }


      catch 
      {

        Write-Verbose -Message "Failed to connect to $Computer via PowerShell remoting..."

        Write-Verbose $_.Exception

        # Todo: Output object here?

          if ($session) 
              {
                Remove-Variable -Name session
              }

      }

  if ($session) 
  {
    $DPMAgentIsInstalled = Invoke-Command -Session $session -ScriptBlock {

      $VerbosePreference = $using:VerbosePreference

      Write-Verbose -Message "Connected to $Computer via PowerShell remoting as user $($env:username), gathering DPM information..."

      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager'

          }

    if ($DPMAgentIsInstalled) 
    {
      
      Write-Verbose -Message "DPM is installed on $Computer, finding Active Owner files..."

      $ActiveOwnerInfo    = Invoke-Command -Session $session -ScriptBlock {

        try 
        {
          $Path = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup' -ErrorAction Stop).InstallPath
        }

        catch 
        {
          Write-Verbose -Message "DPM not installed on $($env:ComputerName)"
          break
        }

    


        $ActiveOwnerFilePaths = Get-ChildItem -Path "$Path\ActiveOwner" | Select-Object -ExpandProperty FullName

        foreach ($thisPath in $ActiveOwnerFilePaths) 
        {

           Write-Verbose -Message "Processing ActiveOwner file $thisPath"

          # Todo: Read binary file contents

        }

      }

      
      return $ActiveOwnerInfo



    }

    Remove-PSSession -Session $session

    }
 
  }

 }

}