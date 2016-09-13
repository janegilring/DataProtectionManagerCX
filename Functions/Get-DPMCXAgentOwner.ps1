#requires -Version 3.0
function Get-DPMCXAgentOwner
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


  }

  catch 
  {

    Write-Warning $_.Exception

  }

  if ($session) 
  {
    $DPMAgentIsInstalled = Invoke-Command -Session $session -ScriptBlock {
      Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager'
    }

    if ($DPMAgentIsInstalled) 
    {
      
      Write-Verbose -Message 'DPM is installed, finding Active Owner files...'

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

          # Todo: Read binary file contents

        }

      }

      
      return $ActiveOwnerInfo



    }

    Remove-PSSession -Session $session
  }

}