function Get-DPMCXSizingBaseline
{

    [pscustomobject]@{
        'Maximum Protected Servers' = 'Data sources are typically spread across approximately 75 servers and 150 client computers.'
        'Maximum Shadow Copy snapshots' = 'A DPM server can store up to 9,000 disk-based snapshots, including those retained when you stop protection of a data source. The snapshot limit applies to express full backups and file recovery points, but not to incremental synchronizations.'
        'Maximum Volumes' = '600 volumes, of which 300 are replica volumes and 300 are recovery point volumes'
        'Maximum Disk Capacity' = '120 TB per DPM server, with 80 TB replica size with a maximum recovery point size of 40 TB'
        'Page File Recommended Size' = '0.2 percent of the combined size of all recovery point volumes, in addition to the minimum requirement size (1.5 times the amount of RAM on the computer)'
        'SQL Max Recommended RAM' = '50-60 percent of the amount of RAM on the computer'
    }

}