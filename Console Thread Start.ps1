Add-Type -AssemblyName presentationframework, presentationcore
$DebugPreference = 'Continue'
. "$PSScriptRoot\Example.ps1"

# https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/
# Might as well since we're in this deep. Interchangable, no unique methods were used.
# [hashtable]::Synchronized(@{})
$script:syncHash = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
$state = New-InitialSessionState -VariableNames @('syncHash') -FunctionNames 'New-WPFWindow'
$pool = New-RunspacePool -InitialSessionState $state
$syncHash.RSPool = $pool

$syncHash.Window = New-WPFWindow -Xaml $Xaml
$syncHash.Window.DataContext = [MainWindowViewModel]::new()
# $application = [System.Windows.Application]::new()
# $application.ShutdownMode = [System.Windows.ShutdownMode]::OnMainWindowClose
# $application.Run($syncHash.Window)
$syncHash.Window.ShowDialog()
$syncHash.Error = $Error
