function New-RunspacePool {
    <#
        .SYNOPSIS
            Creates a RunspacePool
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.RunspacePool])]
    param(
        [Parameter()]
        [InitialSessionState]$InitialSessionState,
        [Parameter()]
        [int]$ThreadLimit = $([int]$env:NUMBER_OF_PROCESSORS + 1),
        [Parameter(
            HelpMessage = 'Use STA on any thread that creates UI or when working with single thread COM Objects.'
        )]
        [ValidateSet('STA', 'MTA', 'Unknown')]
        [string]$ApartmentState = 'STA',
        [Parameter()]
        [ValidateSet('Default', 'ReuseThread', 'UseCurrentThread', 'UseNewThread')]
        [string]$ThreadOptions = 'ReuseThread'
    )

    process {
        $State = if ($PSBoundParameters.ContainsKey('InitialSessionState')) { $InitialSessionState } else { [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault() }
        $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThreadLimit, $State, $Host)
        $runspacePool.ApartmentState = $ApartmentState
        $runspacePool.ThreadOptions = $ThreadOptions
        $runspacePool.CleanupInterval = [timespan]::FromMinutes(2)
        $runspacePool.Open()
        $runspacePool
    }
}
