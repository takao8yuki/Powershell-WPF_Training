# Called with nested helper module
#Using Assembly PresentationCore
#Using Assembly PresentationFramework

# Create own runspace pool with custom functions in module folder
$Script:RSsession = New-InitialSessionState
$Script:RSPool = New-RunspacePool -InitialSessionState $RSsession


class RelayCommand : Windows.Input.ICommand {
    # canExecute runs automatically on click. Doesn't run when background task is finished.
    # requery with [System.Windows.Input.CommandManager]::InvalidateRequerySuggested() on ui thread dispatcher

    # on open, these add a requery event to each button and on close, remove the event
    add_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::add_RequerySuggested($value)
    }

    remove_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
    }

    hidden [ScriptBlock] $_execute
    hidden [ScriptBlock] $_canExecute
    hidden [Object] $_self

    #constructor
    RelayCommand(
        [object] $self,
        # [object] $self, [object] $commandParameter -> [void]
        [ScriptBlock] $execute,
        # [object] $this, $commandParameter -> [bool]
        [ScriptBlock] $canExecute) {
        if ($null -eq $self) {
            throw "The reference to the parent was not set, please provide it by passing `$this to the `$self parameter."
        }
        $this._self = $self

        $e = $execute.ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($e))
        {
            throw "Execute script is `$null or whitespace, please provide a valid ScriptBlock."
        }
        $this._execute = [ScriptBlock]::Create("param(`$this, `$parameter)`n&{`n$e`n} `$this `$parameter")
        # Write-Verbose -Message "param(`$this)&{$e}" -Verbose
        # Backtick(`) prevents $this from evaluating to 'RelayCommand' in the scriptblock creation

        Write-Debug -Message "Execute script $($this._execute)"
        $ce = $canExecute.ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($ce))
        {
            Write-Debug -Message "Can execute script is empty"
            $this._canExecute = $null
        }
        else {
            $this._canExecute = [ScriptBlock]::Create("param(`$this, `$parameter)`n&{`n$ce`n} `$this `$parameter")
        }
    }

    [bool] CanExecute([object] $parameter) {
        if ($null -eq $this._canExecute) {
            Write-Debug -Message "Can execute script is empty so it can execute"
            return $true
        } else {
            [bool] $result = $this._canExecute.Invoke($this._self, $parameter)
            if ($result) {
                Write-Debug -Message "Can execute script was run and can execute"
                #Write-Verbose -Message "Can execute script was run and can execute" -Verbose
            }else {
                Write-Debug -Message "Can execute script was run and cannot execute"
                #Write-Verbose -Message "Can execute script was run and cannot execute" -Verbose
            }
            return $result
        }
    }

    [void] Execute([object] $parameter) {
        Write-Debug "Executing script on RelayCommand against $($this._self)"
        try {
            $this._execute.Invoke($this._self, $parameter)
            Write-Debug "Script on RelayCommand executed"
            #Write-Verbose "$($this._execute)" -Verbose
        }catch
        {
            Write-Error "Error handling execute: $_"
        }
        #if ($parameter){Write-Verbose $parameter -Verbose}
        #$_execute must have '$parameter' inorder for commandparameter binding to be passed and executed
    }
}


Class ViewModel : System.ComponentModel.INotifyPropertyChanged {
    Hidden [System.ComponentModel.PropertyChangedEventHandler] $PropertyChanged

    [Void] add_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler] $value) {
        $this.PropertyChanged = [Delegate]::Combine($this.PropertyChanged, $value)
    }

    [Void] remove_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler] $value) {
        $this.PropertyChanged = [Delegate]::Remove($this.PropertyChanged, $value)
    }

    Hidden [Void] NotifyPropertyChanged([String] $propertyName) {
        #If ($null -cne $this.PropertyChanged) {
            #$this.PropertyChanged.Invoke($this, (New-Object PropertyChangedEventArgs $propertyName))
            $this.PropertyChanged.Invoke($this, $propertyName)
        #}
    }

    #####
    [System.Windows.Threading.Dispatcher]$Dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher

<# If we need to return a background task. Todo: add concurrentqueue/bag
    $JobCleanUpScriptBlock = {}
    Hidden [System.Windows.Threading.DispatcherTimer] $_timer
    StartTimerThread() {
        $this._timer = [System.Windows.Threading.DispatcherTimer]::new('Normal')
        $this._timer.Interval = [TimeSpan]::FromMilliseconds(1000)
        $this._timer.add_Tick({ $Dispatcher.Invoke($JobCleanUpScriptBlock, 'Background') })
        $this._timer.Start()
    }
 #>
    # GUI Display Bindings
    [Int]$Progress
    [String]$HistoryTextBox
    [String]$TwoWayTextBox
    [String]$WelcomeMessage = "
Hello $env:USERNAME!
The layout could use some work.
"

    [Boolean]$CanExecuteTaskUsingProgressBar = $true

    [Object]$ActionList = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
    #[Object]$SelectedAction #Could bind to selecteditem and call to set this.selectedaction = $null to deselect
    # End GUI Display Bindings

    [Void]Dispatch([ScriptBlock]$sb) {
        $this.Dispatcher.Invoke(
            [Action]$sb
        )
    }

    [Void]SetProgress([Int]$progress) {
        $this.Progress = $progress
        $this.NotifyPropertyChanged('Progress')
    }

    [Void]ResetProgress() {
        $this.Progress = 0
        $this.NotifyPropertyChanged('Progress')
        [System.Windows.Input.CommandManager]::InvalidateRequerySuggested()
    }

    [Void]AddHistory($value) {
        $this.HistoryTextBox += "$value"
        $this.NotifyPropertyChanged('HistoryTextBox')
    }

    [Void]AddActionToList([String]$logTime, [String]$logDescription) {
        $this.ActionList.Add([PSCustomObject]@{
            LogTime = $logTime
            LogDescription = $logDescription
        })
    }

    [System.Windows.Input.ICommand]NewCommand(
        [String]$commandName,
        [ScriptBlock]$execute,
        [ScriptBlock]$canExecute
    ) {
        # Create new RelayCommand only if it doesn't exist, not a new one each time a button is clicked.
        if (-not (Test-Path variable:\$commandName)) {
            Set-Variable -Name $commandName -Value ([RelayCommand]::new($this, $execute, $canExecute))
        }
        return Get-Variable -Name $commandName -ValueOnly
    }


    [System.Windows.Input.ICommand]$GoButton = $this.NewCommand(
        'GoButton',
        {
            $this.AddHistory('*')
            $this.AddActionToList("$(Get-Date)", "Added Star")
        },
        {}
    )


    [System.Windows.Input.ICommand]$listCopy = $this.NewCommand(
        'listCopy',
        {
            $tmpCopy = [System.Collections.Generic.List[String]]::new()
            $tmpCopy.Add("LogTime`tLogDescription")
            $parameter | ForEach-Object{
                $tmpCopy.Add("$($_.LogTime)`t$($_.LogDescription)")
            }
            Set-Clipboard -Value $tmpCopy
            $tmpCopy = $null
        },
        {}
    )


    [System.Windows.Input.ICommand]$listRemove = $this.NewCommand(
        'listRemove',
        {
            $tmpSelected = [System.Collections.Generic.List[Object]]::new()
            $parameter | ForEach-Object{
                $tmpSelected.Add($_)
            }
            $tmpSelected | ForEach-Object{
                $this.ActionList.Remove($_)
            }
            $tmpSelected = $null
        },
        {}
    )

    Hidden $doProgress = {
        $progress = $this.Progress + $(Get-Random -Minimum 1 -Maximum 50)
        if ($progress -gt 100) {
            $progress = 100
        }
        $this.SetProgress($progress)
    }

    Hidden $doResetProgress = {
        $this.ResetProgress()
    }

    Hidden $doAddActionToList = {
        $this.AddActionToList("$(Get-Date)", "End doProgressRunspace")
    }

    # Example - does not need endinvoke because it doesnt return anything. Also don't put comments in the script block
    # Need to add param because it's a scriptblock in a scriptblock. Or however $Using:this works.
    Hidden $doProgressRunspace = {
        $psCmd = [powershell]::Create().AddScript({
            param($that)
            while ($that.Progress -lt 100) {
                $that.Dispatch($that.doProgress)
                Start-Sleep -Milliseconds 500
            }
            $that.CanExecuteTaskUsingProgressBar = $true
            $that.Dispatch($that.doResetProgress)
            $that.Dispatch($that.doAddActionToList)
        }).AddParameter('that', $this)
        $psCmd.RunspacePool = $RSPool
        $psCmd.BeginInvoke()
        $this.CanExecuteTaskUsingProgressBar = $false
        $this.AddActionToList("$(Get-Date)", "Start doProgressRunspace")
    }


    [System.Windows.Input.ICommand]$SimulateButton = $this.NewCommand(
        'SimulateButton',
        $this.doProgressRunspace,
        {$this.CanExecuteTaskUsingProgressBar}
    )


    $doSendToHistory = {
        if ($this.TwoWayTextBox) {
            $this.AddHistory($this.TwoWayTextBox)
            $this.AddHistory("`n")
            $this.TwoWayTextBox = $null
            $this.AddActionToList("$(Get-Date)", "Sent to history")
            $this.NotifyPropertyChanged('HistoryTextBox')
            $this.NotifyPropertyChanged('TwoWayTextBox')
        }
    }


    [System.Windows.Input.ICommand]$SendButton = $this.NewCommand(
        'SendButton',
        $this.doSendToHistory,
        {}
    )


    $doClear = {
        if ($this.TwoWayTextBox) {$this.TwoWayTextBox = $null; $this.NotifyPropertyChanged('TwoWayTextBox')}
        if ($this.HistoryTextBox) {$this.HistoryTextBox = $null; $this.NotifyPropertyChanged('HistoryTextBox')}
        if ($this.ActionList) {$this.ActionList = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new(); $this.NotifyPropertyChanged('ActionList')}
    }


    [System.Windows.Input.ICommand]$ClearButton = $this.NewCommand(
        'ClearButton',
        $this.doClear,
        {}
    )



<# ViewModel should start it's own dispatcher
    ViewModel(
        [System.Windows.Threading.Dispatcher]$currentDispatcher
    ) {
        $this.Dispatcher = $currentDispatcher
    }
#>


}

