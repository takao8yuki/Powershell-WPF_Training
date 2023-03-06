Import-Module Pester
Add-Type -AssemblyName presentationframework

$DebugPreference = 'Continue'
. "$PSScriptRoot\Example.ps1"

Describe '_Result is updated' {
    BeforeAll {
        $syncHash = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
        $state = New-InitialSessionState -VariableNames @('syncHash')
        $pool = New-RunspacePool -InitialSessionState $state
        $syncHash.RSPool = $pool
        $script:mockObject = [MainWindowViewModel]::new($syncHash.RSPool)
        Send-Events
    }

    Context 'UpdateTextBlock updates _Result' {
        It 'PrimaryInput should be 5' {
            $mockObject.PrimaryInput = 5
            $mockObject.PrimaryInput | Should Be 5
        }

        It '_Result should be 5' {
            $mockObject.UpdateTextBlock($null)
            $mockObject._Result | Should Be 5
        }

        It 'Should add the number entered from above to _Result' {
            $mockObject.UpdateTextBlock($null)
            $mockObject._Result | Should Be 10
        }
    }

    Context 'Reset _Result' {
        It '_Result should be 0' {
            $mockObject._Result = 0
            $mockObject._Result | Should Be 0
        }
    }

    Context 'Background command internal methods works and updates _Result by wait time and start number' {
        It 'Should return the sum of number that were entered' {
            $mockObject.PrimaryInput = 1
            $script:result = $mockObject.DoStuffBackgroundOrNot([int]$mockObject.PrimaryInput, [int]$mockObject._Result)
            Send-Events
            $script:result | Should Be 1
        }

        It 'Performs callback' {
            $mockObject.BackgroundCallback($result)
            Send-Events
        }

        It 'Should sum' {
            $mockObject._Result | Should Be 2
        }

        It 'Should return the sum of number that were entered again' {
            $script:result = $mockObject.DoStuffBackgroundOrNot($mockObject.PrimaryInput, $mockObject._Result)
            Send-Events
            $script:result | Should Be 3
        }

        It 'Performs callback again' {
            $mockObject.BackgroundCallback($script:result)
            Send-Events
        }

        It 'Should sum again' {
            $mockObject._Result | Should Be 6
        }
    }

    Context 'Test runspace seperate calls and returns' {
        # This doesn't work if $mockObject._Result is compared where it is invoked.
        # But we can test the methods called to run in the background above.
        # Or test it separately after background command is ran like so:
        It 'Do BackgroundCommand again. Sleep for $waitSeconds' {
            $waitSeconds = 1
            $script:expectedResult = ($mockObject._Result + ($waitSeconds * $mockObject.PrimaryInput)) + ($mockObject._Result + ($waitSeconds * $mockObject.PrimaryInput))
            $mockObject.PrimaryInput = $waitSeconds
            $mockObject.BackgroundCommand($null)
            Send-Events
        }

        It 'BackgroundCommand finished and _Result is updated' {
            Send-Events
            $mockObject.IsBackgroundFree | Should Be $true
            $mockObject._Result | Should Be $script:expectedResult
        }

        It 'Do BackgroundCommand again. Sleep for $waitSeconds' {
            $waitSeconds = 5
            $script:expectedResult = ($mockObject._Result + ($waitSeconds * $mockObject.PrimaryInput)) * 2
            $mockObject.PrimaryInput = $waitSeconds
            $mockObject.BackgroundCommand($null)
            Send-Events
        }

        It 'BackgroundCommand finished and _Result is updated' {
            Send-Events
            $mockObject._Result | Should Be $script:expectedResult
        }
    }
}
