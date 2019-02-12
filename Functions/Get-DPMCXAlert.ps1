#requires -Version 2.0
function Get-DPMCXAlert {
    [CmdletBinding()]
    param (    
        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential,
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $DpmServerName = 'localhost',
        [string[]]$Severity = @('Error','Warning')
    )

    begin {

        $output = @()

    }


    process {

        Foreach ($computer in $DpmServerName) {
            Write-Verbose -Message "Processing computer $computer"

            Remove-Variable -Name session -ErrorAction Ignore

            $PSSessionParameters = @{

                ComputerName = $computer
                ErrorAction  = 'Stop'

            }

            if ($PSBoundParameters.ContainsKey('Credential')) {

                $PSSessionParameters.Add('Credential', $Credential)

            }

            try {
                $session = New-PSSession @PSSessionParameters
            }

            catch {

              Write-Warning "An error occured gathering data from $Computer : $($_.Exception.Message)"

            }


            if ($session) {
                try {
          
                    $DPMAlerts = Invoke-Command -Session $session -ScriptBlock {

                        Write-Verbose -Message "Connected via PowerShell remoting as user $($env:username), gathering alerts"

                        try {
              
                            Import-Module -Name DataProtectionManager -ErrorAction Stop -Verbose:$false

                            $VerbosePreference = $Using:VerbosePreference
                            $Severity = $Using:Severity

                            $HostName = [System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName

                            $DPMServerConnection = Connect-DPMServer -DPMServerName $HostName -WarningAction SilentlyContinue

                            Get-DPMAlert -DPMServerName $HostName | 
                            Where-Object {$_.Severity -Contains $Severity} |
                            Select-Object @{n='DPMServer';e={$HostName}},OccurredSince, @{n='Severity';e={$_.Severity.ToString()}}, @{n='Type';e={$_.Type.ToString()}}, @{n='DataSource';e={if ($_.DataSource){$_.DataSource.Name + ' on ' + $_.DataSource.Computer}else{$null}}},@{n='Message';e={($_.ErrorInfo.Problem -split '\n') -join ' '}}
              
                            Write-Verbose -Message 'Finished processing alerts, disconnecting from DPM Server'

                            Disconnect-DPMServer
                        }

                        catch {
                            Write-Verbose -Message "An error occured: $($_.Exception.Message)"
          
                            throw $_.Exception.Message
          
                            break
                        }
                    } -ErrorAction Stop -Verbose | Select-Object -Property DPMServer,OccurredSince, Severity, Type, DataSource, Message
                }

                catch {

                    Write-Warning "An error occured gathering data from $Computer : $($_.Exception.Message)"

                }

                Write-Verbose -Message 'Removing PowerShell Remoting session'

                Remove-PSSession -Session $session
            }


            if ($DPMAlerts) {
                $output += $DPMAlerts
            }
        }

    }

    end {
  
        return $output

    }
}