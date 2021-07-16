Using Module ViewModel

# Initialize concurrentDict over synchronized hashtable. Concurrent Dictionary.AddOrUpdate handles multiple threads better than syncHash
#$syncHash = [HashTable]::Synchronized(@{})
$concurrentDict = [System.Collections.Concurrent.ConcurrentDictionary[String,Object]]::new()

# Read XAML markup
[Xml]$xaml = Get-Content -Path "$PSScriptRoot\GUI.xml"
# can -replace unique source for dictionary resource source path to a relative path
# $xaml -replace "unique id", "$PSScriptRoot\relative\resource\dictionary\path.xml"

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$concurrentDict.GUI = [Windows.Markup.XamlReader]::Load($reader)

# MVVM
$concurrentDict.GUI.DataContext = [ViewModel]::new()
#$concurrentDict.GUI.DataContext.Dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
#$concurrentDict.GUI.DataContext = [ViewModel]::new([System.Windows.Threading.Dispatcher]::CurrentDispatcher)

#===================================================
# Retrieve a list of all GUI elements
#===================================================
foreach ($UIElement in $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")) {
    [void]$concurrentDict.TryAdd($UIElement.Name, $concurrentDict.GUI.FindName($UIElement.Name))
}

#===================================================
# Default actions for custom window in code behind.
# Buttons that only interact with the view stay in the code behind.
#===================================================
$concurrentDict.subMenuFileExit.Add_Click({ $concurrentDict.GUI.Dispatcher.InvokeShutdown() })
$concurrentDict.buttonClose.Add_Click({ $concurrentDict.GUI.Dispatcher.InvokeShutdown() })
$concurrentDict.buttonMinimize.Add_Click({ $concurrentDict.GUI.WindowState = 'Minimized' })
function windowStateTrigger{
    switch ($concurrentDict.GUI.WindowState) {
        'Maximized' {$concurrentDict.GUI.WindowState = 'Normal'}
        'Normal' {$concurrentDict.GUI.WindowState = 'Maximized'}
    }
}
$concurrentDict.buttonRestore.Add_Click({ windowStateTrigger })
$concurrentDict.buttonMaximize.Add_Click({ windowStateTrigger })

$concurrentDict.buttonClear.Add_Click({
    $concurrentDict.listViewLog.UnselectAll()
})

# If the terminal crashes after closing, you dun goofed somewhere.
$concurrentDict.GUI.ShowDialog()
#$concurrentDict.GUI.Dispatcher.InvokeAsync{$concurrentDict.GUI.ShowDialog()}.Wait()
