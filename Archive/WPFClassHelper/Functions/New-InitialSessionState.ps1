function New-InitialSessionState {
    <#
        .SYNOPSIS
            Creates a default session with options to add session functions and variables to be used in a new runspace
        .PARAMETER StartUpScripts
            Runs the provided .ps1 file paths in the runspace on open. Can be used to add class objects from ps1 files that can't be imported by ImportPSModule'
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.InitialSessionState])]
    param(
        [Parameter()]
        [string[]]$FunctionNames,
        [Parameter()]
        [string[]]$VariableNames,
        [Parameter()]
        [string[]]$StartUpScripts,
        [Parameter()]
        [string[]]$ModulePaths
    )

    process {
        # CreateDefault allows default cmdlets to be used without being explicitly added in the runspace
        $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

        if ($PSBoundParameters.ContainsKey('ModulePaths')) {
            $null = $initialSessionState.ImportPSModule($ModulePaths)
        }

        foreach ($functionName in $FunctionNames) {
            $functionDefinition = Get-Content Function:\$functionName -ErrorAction 'Stop'
            $sessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $functionName, $functionDefinition
            $initialSessionState.Commands.Add($sessionStateFunction)
        }

        foreach ($variableName in $VariableNames) {
            $var = Get-Variable $variableName
            $runspaceVariable = New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $var.name, $var.value, $null
            $initialSessionState.Variables.Add($runspaceVariable)
        }

        if ($PSBoundParameters.ContainsKey('StartUpScripts')) {
            $null = $initialSessionState.StartupScripts.Add($StartUpScripts)
        }

        $initialSessionState
    }
}
