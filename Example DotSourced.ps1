Add-Type -AssemblyName presentationframework, presentationcore
$DebugPreference = 'Continue'
. "$PSScriptRoot\Example.ps1"

# https://learn.microsoft.com/en-us/dotnet/standard/collections/thread-safe/
# Todo - swap to recommended classes in System.Collections.Concurrent
$script:syncHash = [hashtable]::Synchronized(@{})
$projectPath = $PSScriptRoot
$state = New-InitialSessionState -VariableNames @('syncHash', 'Xaml', 'projectPath') -FunctionNames 'New-WPFWindow'
$pool = New-RunspacePool -InitialSessionState $state
$syncHash.Add('RSPool', $pool)

$ps = [powershell]::Create()
$ps.RunspacePool = $syncHash.RSPool
$null = $ps.AddScript({
    . "$projectPath\Example.ps1"
    $syncHash.Window = New-WPFWindow -Xaml $Xaml
    $syncHash.This = [MainWindowViewModel]::new() # Window.DataContext is null for some reason so we initialize it here instead to be able to call localDispatcher to do work
    $syncHash.Window.DataContext = $syncHash.This
    $syncHash.Window.ShowDialog()
    $syncHash.Error = $Error
})
$syncHash.Add('PS', $ps)
$asyncState = $syncHash.PS.BeginInvoke()
$asyncState

# able to do this in the freed up console that loaded this
#$syncHash.This.localDispatcher.Invoke({$syncHash.This.UpdateTextBlock(10)})
# or this. Since this script instance/console doesn't know the viewmodel updated typedata until new'ed because we made it static. Add-Member does not have this problem
#[MainWindowViewModel]::new() #must be loaded from this script not in console then you can use the below anywhere
##$syncHash.This.TextBlockText += 10
