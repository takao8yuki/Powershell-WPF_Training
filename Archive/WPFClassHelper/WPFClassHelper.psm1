# using assembly PresentationFramework
# using assembly PresentationCore
# using assembly WindowsBase

class RelayCommandBase : System.Windows.Input.ICommand {
    add_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::add_RequerySuggested($value)
    }

    remove_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
    }

    # Invoke does not take a $null parameter so we wrap $null in an array for all cases
    # Providing the original method with $null will work, invoking with $null will not because invoke() provides arguments not parameters.
    # Arguments cannot be explicitly $null since they're optional
    [bool]CanExecute([object]$CommandParameter) {
        if ($null -eq $this._canExecute) { return $true }
        return $this._canExecute.Invoke(@($CommandParameter))
    }

    [void]Execute([object]$CommandParameter) {
        try {
            $this._execute.Invoke(@($CommandParameter))
        } catch {
            Write-Error "Error handling RelayCommandBase.Execute: $_"
        }
    }

    hidden [System.Management.Automation.PSMethod]$_execute
    hidden [System.Management.Automation.PSMethod]$_canExecute

    RelayCommandBase($Execute, $CanExecute) {
        $this.Init($Execute, $CanExecute)
    }

    RelayCommandBase($Execute) {
        $this.Init($Execute, $null)
    }

    RelayCommandBase() {}

    hidden Init($Execute, $CanExecute) {
        if ($null -eq $Execute) { throw 'RelayCommandBase.Execute is null. Supply a valid method.' }
        $this._execute = $Execute
        $this._canExecute = $CanExecute
    }
}


# Support for parameterless PSMethods
# Doesn't seem clean
class RelayCommand : RelayCommandBase {
    [bool]CanExecute([object]$CommandParameter) {
        if ($null -eq $this._canExecute) { return $true }
        if ($this._canExecuteCount -eq 1) { return $this._canExecute.Invoke($CommandParameter) }
        else { return $this._canExecute.Invoke() }
    }

    [void]Execute([object]$CommandParameter) {
        try {
            if ($this._executeCount -eq 1) { $this._execute.Invoke($CommandParameter) }
            else { $this._execute.Invoke() }
        } catch {
            Write-Error "Error handling RelayCommand.Execute: $_"
        }
    }

    hidden [int]$_executeCount
    hidden [int]$_canExecuteCount

    #RelayCommand($Execute, $CanExecute) : base($Execute, $CanExecute) { # use default parameterless constructor to avoid calls to Init in this and the base class
    RelayCommand($Execute, $CanExecute) {
        $this.Init($Execute, $CanExecute)
    }

    RelayCommand($Execute) {
        $this.Init($Execute, $null)
    }

    hidden Init($Execute, $CanExecute) {
        if ($null -eq $Execute) { throw 'RelayCommand.Execute is null. Supply a valid method.' }
        $this._executeCount = $this.GetParameterCount($Execute)
        $this._execute = $Execute

        $this._canExecute = $CanExecute
        if ($null -ne $this._canExecute) {
            $this._canExecuteCount = $this.GetParameterCount($CanExecute)
        }
    }

    hidden [int]GetParameterCount([System.Management.Automation.PSMethod]$Method) {
        # Alternatively pass the viewmodel into RelayCommand
        # $ViewModel.GetType().GetMethod($PSMethod.Name).GetParameters().Count
        $param = $Method.OverloadDefinitions[0].Split('(').Split(')')[1]
        if ([string]::IsNullOrWhiteSpace($param)) { return 0 }

        $paramCount = $param.Split(',').Count
        # Write-Debug "$($Method.OverloadDefinitions[0].Split('(').Split(')')[1].Split(',')) relaycommand param count"
        if ($paramCount -gt 1) { throw "RelayCommand expected parameter count 0 or 1. Found PSMethod with count $paramCount" }
        return $paramCount
    }
}


class DelegateCommand : System.Windows.Input.ICommand {
    # ICommand Implementation
    add_CanExecuteChanged([EventHandler] $value) {
        $this._internalCanExecuteChanged = [Delegate]::Combine($this._internalCanExecuteChanged, $value)
        # [System.Windows.Input.CommandManager]::add_RequerySuggested($value)
    }

    remove_CanExecuteChanged([EventHandler] $value) {
        $this._internalCanExecuteChanged = [Delegate]::Remove($this._internalCanExecuteChanged, $value)
        # [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
    }

    # Delegate takes $null unlike invoking the PSMethod where it passes as arguments
    [bool]CanExecute([object]$CommandParameter) {
        if ($null -eq $this._canExecute) { return $true }
        return $this._canExecute.Invoke($CommandParameter)
    }

    [void]Execute([object]$CommandParameter) {
        try {
            $this._execute.Invoke($CommandParameter)
        } catch {
            Write-Error "Error handling DelegateCommand.Execute: $_"
        }
    }
    # End ICommand Implementation

    [System.EventHandler]$_internalCanExecuteChanged

    [void]RaiseCanExecuteChanged() {
        if ($null -ne $this._canExecute) {
            $this.OnCanExecuteChanged()
        }
    }

    [void]OnCanExecuteChanged() {
        [EventHandler]$eCanExecuteChanged = $this._internalCanExecuteChanged
        if ($null -ne $eCanExecuteChanged) {
            $eCanExecuteChanged.Invoke($this, [System.EventArgs]::Empty)
        }
    }

    hidden [System.Delegate]$_execute
    hidden [System.Delegate]$_canExecute

    DelegateCommand($Execute, $CanExecute) {
        $this.Init($Execute, $CanExecute)
    }

    DelegateCommand($Execute) {
        $this.Init($Execute, $null)
    }

    DelegateCommand() {}

    hidden Init($Execute, $CanExecute) {
        if ($null -eq $Execute) { throw 'DelegateCommand.Execute is null. Supply a valid method.' }
        $this._execute = $Execute
        $this._canExecute = $CanExecute
    }
}

class ViewModelBase : System.Windows.DependencyObject, System.ComponentModel.INotifyPropertyChanged {
    # INotifyPropertyChanged Implementation
    hidden [ComponentModel.PropertyChangedEventHandler]$_propertyChanged

    [void]add_PropertyChanged([ComponentModel.PropertyChangedEventHandler]$value) {
        $this._propertyChanged = [Delegate]::Combine($this._propertyChanged, $value)
    }

    [void]remove_PropertyChanged([ComponentModel.PropertyChangedEventHandler]$value) {
        $this._propertyChanged = [Delegate]::Remove($this._propertyChanged, $value)
    }

    [void]OnPropertyChanged([string]$propertyName) {
        if ($null -ne $this._PropertyChanged) {
            $this._PropertyChanged.Invoke($this, [System.ComponentModel.PropertyChangedEventArgs]::new($propertyName))
        }

    }
    # End INotifyPropertyChanged Implementation

    [System.Management.Automation.Runspaces.RunspacePool]$DefaultRunspacePool

    # Any RunspacePool task must call Dispatcher if it modifies the UI
    [System.IAsyncResult]BackgroundInvoke([System.Management.Automation.PSMethod]$Work, [object[]]$WorkParams, [System.Management.Automation.PSMethod]$Callback, [bool]$UseWorkAsCallbackParam) {
        if ($null -eq $this.DefaultRunspacePool) { throw "Can't run a background task without a runspace." }
        if ($this.DefaultRunspacePool.IsDisposed) { throw 'Runspacepool is disposed.' }

        # $workDelegate = $this.GetDelegate($Work)
        # $callbackDelegate = $this.GetDelegate($Callback)
        $ps = [powershell]::Create()
        $ps.RunspacePool = $this.DefaultRunspacePool
        $ps.AddScript({
                param($Delegate, $DelegateParams, $Callback, $UseWorkReturn)
                try {
                    # $callbackParam = [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke($Delegate, $DelegateParams)
                    $callbackParam = $Delegate.Invoke($DelegateParams)
                    if ($UseWorkReturn) {
                        # [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke($Callback, $callbackParam)
                        $Callback.Invoke($callbackParam)
                    } else {
                        # [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke($Callback)
                        $Callback.Invoke()
                    }
                } catch {
                    # Add-Content -Path "$PSScriptRoot\BackgroundInvokeErrors.log" -Value $Error
                }
            }
        ).AddParameter('Delegate', $Work).AddParameter('DelegateParams', $WorkParams).AddParameter('Callback', $Callback).AddParameter('UseWorkReturn', $UseWorkAsCallbackParam)

        $handle = $ps.BeginInvoke()
        return $handle
    }

    hidden Initialize () {
        $this.DefaultRunspacePool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
        $this.DefaultRunspacePool.CleanupInterval = [timespan]::FromMinutes(2)
        $this.DefaultRunspacePool.Open()
    }

    hidden Initialize ($Pool) {
        $this.DefaultRunspacePool = $Pool
    }

    [System.Windows.Input.ICommand]NewCommand(
        [System.Management.Automation.PSMethod]$Execute,
        [System.Management.Automation.PSMethod]$CanExecute
    ) {
        return [RelayCommandBase]::new($Execute, $CanExecute)
    }

    [System.Windows.Input.ICommand]NewCommand(
        [System.Management.Automation.PSMethod]$Execute
    ) {
        return [RelayCommandBase]::new($Execute)
    }

    # Experimental - Probably not needed in PowerShell 7.2+
    [System.Windows.Input.ICommand]NewDelegate(
        [System.Management.Automation.PSMethod]$Execute,
        [System.Management.Automation.PSMethod]$CanExecute
    ) {
        #$delegateExecute = $this.GetType().GetMethod($Execute.Name).CreateDelegate([action[object]], $this)
        #$delegateCanExecute = $this.GetType().GetMethod($CanExecute.Name).CreateDelegate([func[object,bool]], $this)
        $e = $this.GetDelegate($Execute)
        $ce = $this.GetDelegate($CanExecute)
        return [DelegateCommand]::new($e, $ce)
    }

    [System.Windows.Input.ICommand]NewDelegate(
        [System.Management.Automation.PSMethod]$Execute
    ) {
        $e = $this.GetDelegate($Execute)
        return [DelegateCommand]::new($e)
    }

    hidden [System.Delegate]GetDelegate([System.Management.Automation.PSMethod]$Method) {
        $typeMethod = $this.GetType().GetMethod($Method.Name)
        $returnType = $typeMethod.ReturnType.ToString()

        if ($returnType -eq 'System.Void') {
            $delegateString = 'Action'
            $delegateReturnParam = ']'
        } else {
            $delegateString = 'Func'
            $delegateReturnParam = ",$returnType]"
        }

        $delegateParameters = $this.GetType().GetMethod($typeMethod.Name).GetParameters()
        if ($delegateParameters.Count -ge 1) {
            $delegateString += '['
        }

        $paramString = ''
        foreach ($p in $delegateParameters) {
            $paramString += "$($p.ParameterType.ToString()),"
        }

        if ($paramString.Length -gt 0) {
            # Get rid of comma
            $paramString = $paramString.Substring(0, $paramString.Length - 1)
        } else {
            $delegateReturnParam = "[$returnType]"
            if ($returnType -eq 'System.Void') { $delegateReturnParam = '' }
        }

        $paramString += "$delegateReturnParam"
        $delegateString += "$paramString"
        # Write-Debug "$($Method.Name) converted to: $delegateString"
        return $typeMethod.CreateDelegate(($delegateString -as [type]), $this)
    }
}

# Alternative to [System.Windows.Forms.Application]::DoEvents() from Add-Type -AssemblyName System.Windows.Forms
function Send-Events ([System.Windows.Threading.DispatcherPriority]$DispatcherPriority) {
    $frame = [System.Windows.Threading.DispatcherFrame]::new()
    $callback = [System.Windows.Threading.DispatcherOperationCallback] { param($frame) $frame.Continue = $false }
    # $operation = [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke($DispatcherPriority,
    #     $callback,
    #     $frame)
    # while (-not $operation.GetAwaiter().IsCompleted) {
    #     [System.Threading.Thread]::Sleep(1000)
    # }
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke($DispatcherPriority, # for testing, dispatcher priority might need to be less than all other used priorities
        $callback,
        $frame)
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
    # Don't think ExitAllFrames does anything here.
    # [System.Windows.Threading.Dispatcher]::ExitAllFrames()
}
