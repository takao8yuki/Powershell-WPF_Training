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
            $result = $mockObject.DoStuffBackgroundOrNot([int]$mockObject.PrimaryInput, [int]$mockObject._Result)
            $result | Should Be 1
            $mockObject.BackgroundCallback($result)
            $mockObject._Result | Should Be 2
        }

        It 'Should add to _Result after summing' {
            $result = $mockObject.DoStuffBackgroundOrNot($mockObject.PrimaryInput, $mockObject._Result)
            $result | Should Be 3
            $mockObject.BackgroundCallback($result)
            # 2(from above) + 1(from loop from ExtractedMethod) + 3(from here)
            $mockObject._Result | Should Be 6
        }

        # This doesn't work if $mockObject._Result is compared where it is invoked.
        # But we can test the methods called to run in the background above.
        # Or test it separately after background is run like so:
        It 'Do BackgroundCommand again. Sleep for $waitSeconds' {
            $waitSeconds = 1
            $script:expectedResult = ($mockObject._Result + ($waitSeconds * $mockObject.PrimaryInput)) + ($mockObject._Result + ($waitSeconds * $mockObject.PrimaryInput))
            $mockObject.PrimaryInput = $waitSeconds
            $mockObject.BackgroundCommand($null)
            Send-Events
        }

        It 'BackgroundCommand finished and _Result is updated' {
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
            $mockObject._Result | Should Be $script:expectedResult
        }
    }
}
