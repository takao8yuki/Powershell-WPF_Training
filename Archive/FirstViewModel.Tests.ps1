using module '.\Classes\WPFClassHelper\WPFClassHelper.psd1'
using module '.\SampleWPF.psm1'

# DispatcherPriority should be less than the enumeration used in the tested methods
$DispatcherPriority = [System.Windows.Threading.DispatcherPriority]::SystemIdle

Describe 'Testing FirstViewModel' {
    BeforeAll {
        $script:testClass = [FirstViewModel]::new()
    }

    BeforeEach {
        Send-Events -DispatcherPriority $DispatcherPriority
    }

    Context 'UpdateResult updates Result' {
        It 'PrimaryInput should be 5' {
            $testClass.SetValue([FirstViewModel]::PrimaryInputProperty, 5)
            $testClass.GetValue([FirstViewModel]::PrimaryInputProperty) | Should Be 5
        }

        It 'Result should be 5' {
            $testClass.UpdateResult($null)
            $testClass.GetValue([FirstViewModel]::ResultProperty) | Should Be 5
        }

        It 'Should add the number entered from above to Result' {
            $testClass.UpdateResult($null)
            $testClass.GetValue([FirstViewModel]::ResultProperty) | Should Be 10
        }
    }

    Context 'Reset Result' {
        It 'Result should be 0' {
            $testClass.SetValue([FirstViewModel]::ResultProperty, 0)
            $testClass.GetValue([FirstViewModel]::ResultProperty) | Should Be 0
        }
    }

    Context 'Background command internal methods works and updates Result by wait time and start number' {
        It 'Should return the sum of number that were entered' {
            $testClass.SetValue([FirstViewModel]::PrimaryInputProperty, 1)
            $script:result = $testClass.DoStuffBackgroundOrNot($testClass.GetValue([FirstViewModel]::PrimaryInputProperty), $testClass.GetValue([FirstViewModel]::ResultProperty))
            $script:result | Should Be 1
        }

        It 'Performs callback' {
            $testClass.BackgroundCallback($script:result)
        }

        It 'Should sum' {
            $testClass.GetValue([FirstViewModel]::ResultProperty) | Should Be 2
        }

        It 'Should return the sum of number that were entered again' {
            $script:result = $testClass.DoStuffBackgroundOrNot($testClass.GetValue([FirstViewModel]::PrimaryInputProperty), $testClass.GetValue([FirstViewModel]::ResultProperty))
            $script:result | Should Be 3
        }

        It 'Performs callback again' {
            $testClass.BackgroundCallback($script:result)
        }

        It 'Should sum again' {
            $testClass.GetValue([FirstViewModel]::ResultProperty) | Should Be 6
        }
    }

    Context 'Background command runs in the runspacepool' {
        It 'Do BackgroundCommand again. Sleep for $waitSeconds' {
            $waitSeconds = 1
            $script:expectedResult = ($testClass.GetValue([FirstViewModel]::ResultProperty) + ($waitSeconds * $testClass.GetValue([FirstViewModel]::PrimaryInputProperty))) + ($testClass.GetValue([FirstViewModel]::ResultProperty) + ($waitSeconds * $testClass.GetValue([FirstViewModel]::PrimaryInputProperty)))
            $testClass.SetValue([FirstViewModel]::PrimaryInputProperty, $waitSeconds)
            $handle = $testClass.BackgroundCommand($null)
            while (-not $handle.IsCompleted) { [System.Threading.Thread]::Sleep(100) }
        }

        It 'BackgroundCommand finished and Result is updated' {
            $testClass.GetValue([FirstViewModel]::ResultProperty) | Should Be $script:expectedResult
            $testClass.GetValue([FirstViewModel]::IsBackgroundFreeProperty) | Should Be $true
        }

        It 'Do BackgroundCommand again. Sleep for $waitSeconds' {
            $waitSeconds = 5
            $script:expectedResult = ($testClass.GetValue([FirstViewModel]::ResultProperty) + ($waitSeconds * $testClass.GetValue([FirstViewModel]::PrimaryInputProperty))) * 2
            $testClass.SetValue([FirstViewModel]::PrimaryInputProperty, $waitSeconds)
            $handle = $testClass.BackgroundCommand($null)
            while (-not $handle.IsCompleted) { [System.Threading.Thread]::Sleep(100) }
        }

        It 'BackgroundCommand finished and Result is updated again' {
            $testClass.GetValue([FirstViewModel]::ResultProperty) | Should Be $script:expectedResult
            $testClass.GetValue([FirstViewModel]::IsBackgroundFreeProperty) | Should Be $true
        }
    }
}
