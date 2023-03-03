Add-Type -AssemblyName presentationframework, presentationcore
$DebugPreference = 'Continue'
. "$PSScriptRoot\Example.ps1"

$Window = New-WPFObject -Xaml $Xaml
# $Window.DataContext = [MainWindowViewModel]::new((New-RunspacePool))
$Window.DataContext = [MainWindowViewModelDP]::new((New-RunspacePool))

# $application = [System.Windows.Application]::new()
# $application.ShutdownMode = [System.Windows.ShutdownMode]::OnMainWindowClose
# $null = $application.Run($syncHash.Window)
$Window.add_Closing({
    if ($Window.DataContext.RunspacePoolDependency) { $Window.DataContext.RunspacePoolDependency.Dispose() }
    $Window.Dispatcher.InvokeShutdown()
})
$null = $Window.ShowDialog()
