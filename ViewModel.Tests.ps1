Import-Module Pester
Add-Type -AssemblyName presentationframework, System.Windows.Forms

$DebugPreference = 'Continue'
. "$PSScriptRoot\Example.ps1"

Describe "TextBlockText is updated" {
    BeforeAll {
        $syncHash = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
        $state = New-InitialSessionState -VariableNames @('syncHash')
        $pool = New-RunspacePool -InitialSessionState $state
        $syncHash.RSPool = $pool
        $script:mockObject = [MainWindowViewModel]::new($syncHash.RSPool)
    }

    Context "UpdateTextBlock updates TextBlockText" {
        It "TextBoxText should be 5" {
            $mockObject.TextBoxText = 5
            $mockObject.TextBoxText | Should Be 5
        }

        It "TextBlockText should be 5" {
            $mockObject.UpdateTextBlock($null)
            $mockObject.TextBlockText | Should Be 5
        }

        It "Should add the number entered from above to TextBlockText" {
            $mockObject.UpdateTextBlock($null)
            $mockObject.TextBlockText | Should Be 10
        }
    }

    Context "Reset TextBlockText" {
        It "TextBlockText should be 0" {
            $mockObject.TextBlockText = 0
            $mockObject.TextBlockText | Should Be 0
        }
    }

    Context "Background command internal methods works and updates TextBlockText by wait time and start number" {
        It "Should return the sum of number that were entered" {
            $mockObject.TextBoxText = 1
            $result = $mockObject.DoStuffBackgroundOrNot([int]$mockObject.TextBoxText, [int]$mockObject.TextBlockText)
            $result | Should Be 1
            $mockObject.BackgroundCallback($result)
            $mockObject.TextBlockText | Should Be 2
        }

        It "Should add to TextBlockText after summing" {
            $result = $mockObject.DoStuffBackgroundOrNot($mockObject.TextBoxText, $mockObject.TextBlockText)
            $result | Should Be 3
            $mockObject.BackgroundCallback($result)
             # 2(from above) + 1(from loop from ExtractedMethod) + 3(from here)
            $mockObject.TextBlockText | Should Be 6
        }

        # This doesn't work if $mockObject.TextBlockText is compared where it is invoked.
        # But we can test the methods called to run in the background above.
        # Or test it separately after background is run like so:
        It "Do BackgroundCommand again. Sleep for `$waitSeconds" {
            $waitSeconds = 1
            $script:expectedResult = ($mockObject.TextBlockText + ($waitSeconds * $mockObject.TextBoxText)) + ($mockObject.TextBlockText + ($waitSeconds * $mockObject.TextBoxText))
            $mockObject.TextBoxText = $waitSeconds
            $mockObject.BackgroundCommand($null)
            [System.Windows.Forms.Application]::DoEvents()
        }

        It "BackgroundCommand finished and TextBlockText is updated" {
            [System.Windows.Forms.Application]::DoEvents()
            $mockObject.TextBlockText | Should be $script:expectedResult
        }

        It "Do BackgroundCommand again. Sleep for `$waitSeconds" {
            $waitSeconds = 5
            $script:expectedResult = ($mockObject.TextBlockText + ($waitSeconds * $mockObject.TextBoxText)) * 2
            $mockObject.TextBoxText = $waitSeconds
            $mockObject.BackgroundCommand($null)
            [System.Windows.Forms.Application]::DoEvents()
        }

        It "BackgroundCommand finished and TextBlockText is updated" {
            [System.Windows.Forms.Application]::DoEvents()
            $mockObject.TextBlockText | Should be $script:expectedResult
        }
    }
}
