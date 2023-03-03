Add-Type -AssemblyName presentationframework, presentationcore
$DebugPreference = 'Continue'
. "$PSScriptRoot\Example.ps1"

# https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/
# Might as well since we're in this deep. Interchangable, no unique methods were used.
# [hashtable]::Synchronized(@{})
$script:syncHash = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
$state = New-InitialSessionState -VariableNames @('syncHash') -StartUpScripts "$PSScriptRoot\Example.ps1"
$pool = New-RunspacePool -InitialSessionState $state
$syncHash.RSPool = $pool

$syncHash.PS = [powershell]::Create()
$syncHash.PS.RunspacePool = $syncHash.RSPool
$null = $syncHash.PS.AddScript({
        $syncHash.Window = New-WPFObject -Xaml $Xaml
        $syncHash.Window.DataContext = [MainWindowViewModel]::new($syncHash.RSPool)
        # $syncHash.Window.DataContext = [MainWindowViewModelDP]::new($syncHash.RSPool)
        # $syncHash.application = [System.Windows.Application]::new()
        # $syncHash.application.ShutdownMode = [System.Windows.ShutdownMode]::OnMainWindowClose
        # $syncHash.application.Run($syncHash.Window)
        $syncHash.Window.ShowDialog()
        $syncHash.Window.add_Closing({ $syncHash.Window.Dispatcher.InvokeShutdown() })
        $syncHash.Error = $Error
    }
)

$syncHash.AsyncState = $syncHash.PS.BeginInvoke()
# Remember to dispose when finished
# $syncHash.RSPool.Dispose()
