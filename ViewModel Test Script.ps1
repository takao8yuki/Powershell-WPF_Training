Add-Type -AssemblyName presentationframework
$DebugPreference = 'Continue'
. "$PSScriptRoot\Example.ps1"
$script:syncHash = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
$state = New-InitialSessionState -VariableNames @('syncHash')
$pool = New-RunspacePool -InitialSessionState $state
$syncHash.RSPool = $pool

$a = [MainWindowViewModel]::new($syncHash.RSPool)
$a.TextBoxText = 5
$a.UpdateTextBlock($null)

$a.DoStuffBackgroundOrNot(5,0) -eq 5

$a.BackgroundCallback(5)
$a.TextBlockText -eq 15
