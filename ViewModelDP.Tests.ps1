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
        $script:mockObject = [MainWindowViewModelDP]::new($syncHash.RSPool)
    }

    Context 'UpdateTextBlock updates _Result' {
        It 'PrimaryInput should be 5' {
            $mockObject.SetValue([MainWindowViewModelDP]::PrimaryInputProperty, 5)
            $mockObject.GetValue([MainWindowViewModelDP]::PrimaryInputProperty) | Should Be 5
        }

        It '_Result should be 5' {
            $mockObject.UpdateTextBlock($null)
            $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) | Should Be 5
        }

        It 'Should add the number entered from above to _Result' {
            $mockObject.UpdateTextBlock($null)
            $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) | Should Be 10
        }
    }

    Context 'Reset _Result' {
        It '_Result should be 0' {
            $mockObject.SetValue([MainWindowViewModelDP]::ResultProperty, 0)
            $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) | Should Be 0
        }
    }

    Context 'Background command internal methods works and updates _Result by wait time and start number' {
        It 'Should return the sum of number that were entered' {
            $mockObject.SetValue([MainWindowViewModelDP]::PrimaryInputProperty, 1)
            $result = $mockObject.DoStuffBackgroundOrNot($mockObject.GetValue([MainWindowViewModelDP]::PrimaryInputProperty), $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty))
            $result | Should Be 1
            $mockObject.BackgroundCallback($result)
            $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) | Should Be 2
        }

        It 'Should add to _Result after summing' {
            $result = $mockObject.DoStuffBackgroundOrNot($mockObject.GetValue([MainWindowViewModelDP]::PrimaryInputProperty), $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty))
            $result | Should Be 3
            $mockObject.BackgroundCallback($result)
            # 2(from above) + 1(from loop from ExtractedMethod) + 3(from here)
            $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) | Should Be 6
        }

        # This doesn't work if $mockObject._Result is compared where it is invoked.
        # But we can test the methods called to run in the background above.
        # Or test it separately after background is run like so:
        It 'Do BackgroundCommand again. Sleep for $waitSeconds' {
            $waitSeconds = 1
            $script:expectedResult = ($mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) + ($waitSeconds * $mockObject.GetValue([MainWindowViewModelDP]::PrimaryInputProperty))) + ($mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) + ($waitSeconds * $mockObject.GetValue([MainWindowViewModelDP]::PrimaryInputProperty)))
            $mockObject.SetValue([MainWindowViewModelDP]::PrimaryInputProperty, $waitSeconds)
            $mockObject.BackgroundCommand($null)
            Send-Events
        }

        It 'BackgroundCommand finished and _Result is updated' {
            $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) | Should Be $script:expectedResult
        }

        It 'Do BackgroundCommand again. Sleep for $waitSeconds' {
            $waitSeconds = 5
            $script:expectedResult = ($mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) + ($waitSeconds * $mockObject.GetValue([MainWindowViewModelDP]::PrimaryInputProperty))) * 2
            $mockObject.SetValue([MainWindowViewModelDP]::PrimaryInputProperty, $waitSeconds)
            $mockObject.BackgroundCommand($null)
            Send-Events
        }

        It 'BackgroundCommand finished and _Result is updated' {
            $mockObject.GetValue([MainWindowViewModelDP]::ResultProperty) | Should Be $script:expectedResult
        }
    }
}
