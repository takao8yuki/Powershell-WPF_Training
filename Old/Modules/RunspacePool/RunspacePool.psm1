function New-InitialSessionState {
    <#
        .SYNOPSIS
            Creates a default session while also adding user functions and user variables to be used in a new runspace

        .DESCRIPTION
            Creates a session with default Powershell Cmdlets, adding user specified funcions and variables.
            To have runspaces communicate with each other, add a synchronized hash #$syncHash = [HashTable]::Synchronized(@{})
            Or use ConcurrentDictionary, available from .Net 5(cross platform) and .Net Framework 4.8 (if limited to windows)

        .EXAMPLE
            $session = New-InitialSessionState

        .EXAMPLE
            $var = 1
            $varMore = 'more vars'
            function printX {
                param($x)
                Write-Output "$x $var $varMore"
            }
            $session = New-InitialSessionState -FunctionNames 'printX' -VariableNames 'var, varMore'
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.InitialSessionState])]
    param(
        [Parameter()]
        [System.Collections.Generic.List[String]]$FunctionNames,
        [Parameter()]
        [System.Collections.Generic.List[String]]$VariableNames
    )

    process{

        # Create an initial session state object required for runspaces
        # CreateDefault allows default cmdlets to be used without being explicitly added in the runspace
        $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

        # Add custom functions to the Session State to be added into a runspace
        foreach( $functionName in $FunctionNames ) {
            $functionDefinition = Get-Content Function:\$functionName -ErrorAction 'Stop'
            $sessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $functionName, $functionDefinition
            $initialSessionState.Commands.Add($sessionStateFunction)
        }

        # Add variables to the Session State to be added into a runspace
        foreach( $variableName in $VariableNames ) {
            $var = Get-Variable $variableName
            $runspaceVariable = New-object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $var.name, $var.value, $Null
            $initialSessionState.Variables.Add($runspaceVariable)
        }

        $initialSessionState
    }
}

function New-RunspacePool {
    <#
        .SYNOPSIS
            Creates a RunspacePool

        .EXAMPLE
            $session = New-InitialSessionState
            New-RunspacePool -InitialSessionState $session

        .EXAMPLE
            $session = New-InitialSessionState
            $RSPool = New-RunspacePool -InitialSessionState $session -ThreadLimit 6 -ApartmentState "STA" -ThreadOptions "ReuseThread"
            $RSPool.Dispose()
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.RunspacePool])]
    param(
        [Parameter(Mandatory = $true)]
        [InitialSessionState]$InitialSessionState,
        [Parameter()]
        [Int]$ThreadLimit = $([Int]$env:NUMBER_OF_PROCESSORS + 1),
        [Parameter(
            HelpMessage = 'Use STA on any thread that creates UI or when working with single thread COM Objects.'
        )]
        [ValidateSet("STA", "MTA", "Unknown")]
        [String]$ApartmentState = "STA",
        [Parameter()]
        [ValidateSet("Default", "ReuseThread", "UseCurrentThread", "UseNewThread")]
        [String]$ThreadOptions = "ReuseThread"
    )

    process {
        $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThreadLimit, $InitialSessionState, $Host)
        $runspacePool.ApartmentState = $ApartmentState
        $runspacePool.ThreadOptions = $ThreadOptions
        $runspacePool.Open()
        $runspacePool
    }
}
