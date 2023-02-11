Add-Type -AssemblyName presentationframework, presentationcore
$DebugPreference = 'Continue'
. "$PSScriptRoot\Example.ps1"

# https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/
# Might as well since we're in this deep. Interchangable, no unique methods were used.
# [hashtable]::Synchronized(@{})
$script:syncHash = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
# $projectPath = $PSScriptRoot
$state = New-InitialSessionState -VariableNames @('syncHash') -StartUpScripts "$PSScriptRoot\Example.ps1"
$pool = New-RunspacePool -InitialSessionState $state
$syncHash.RSPool = $pool

$ps = [powershell]::Create()
$ps.RunspacePool = $syncHash.RSPool
$null = $ps.AddScript({
    # . "$projectPath\Example.ps1"
    $syncHash.Window = New-WPFWindow -Xaml $Xaml
    $syncHash.Window.DataContext = [MainWindowViewModel]::new($syncHash.RSPool) # Window.DataContext is null for some reason if newed up here
    # $syncHash.application = [System.Windows.Application]::new()
    # $syncHash.application.ShutdownMode = [System.Windows.ShutdownMode]::OnMainWindowClose
    # $syncHash.application.Run($syncHash.Window)
    $syncHash.Window.ShowDialog()
    $syncHash.Window.add_Closing($syncHash.Window.Dispatcher.InvokeShutdown())
    $syncHash.Error = $Error
})
$syncHash.PS = $ps
$asyncState = $syncHash.PS.BeginInvoke()
$asyncState
