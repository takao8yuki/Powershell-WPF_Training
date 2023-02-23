#Remember to add the below two assemblies and dot source this file since powershell parses classes before add-types
Add-Type -AssemblyName presentationframework, presentationcore

function New-InitialSessionState {
    <#
        .SYNOPSIS
            Creates a default session with options to add session functions and variables to be used in a new runspace
        .PARAMETER StartUpScripts
            Runs the provided .ps1 file paths in the runspace on open. Can be used to add class objects from ps1 files that can't be imported by ImportPSModule'
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.InitialSessionState])]
    param(
        [Parameter()]
        [string[]]$FunctionNames,
        [Parameter()]
        [string[]]$VariableNames,
        [Parameter()]
        [string[]]$StartUpScripts,
        [Parameter()]
        [string[]]$ModulePaths
    )

    process {
        # CreateDefault allows default cmdlets to be used without being explicitly added in the runspace
        $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

        if ($PSBoundParameters['ModulePaths']) {
            $null = $initialSessionState.ImportPSModule($ModulePaths)
        }

        foreach ($functionName in $FunctionNames) {
            $functionDefinition = Get-Content Function:\$functionName -ErrorAction 'Stop'
            $sessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $functionName, $functionDefinition
            $initialSessionState.Commands.Add($sessionStateFunction)
        }

        foreach ($variableName in $VariableNames) {
            $var = Get-Variable $variableName
            $runspaceVariable = New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $var.name, $var.value, $null
            $initialSessionState.Variables.Add($runspaceVariable)
        }

        if ($PSBoundParameters['StartUpScripts']) {
            $null = $initialSessionState.StartupScripts.Add($StartUpScripts)
        }

        $initialSessionState
    }
}

function New-RunspacePool {
    <#
        .SYNOPSIS
            Creates a RunspacePool
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.RunspacePool])]
    param(
        [Parameter(Mandatory)]
        [InitialSessionState]$InitialSessionState,
        [Parameter()]
        [int]$ThreadLimit = $([Int]$env:NUMBER_OF_PROCESSORS + 1),
        [Parameter(
            HelpMessage = 'Use STA on any thread that creates UI or when working with single thread COM Objects.'
        )]
        [ValidateSet('STA', 'MTA', 'Unknown')]
        [string]$ApartmentState = 'STA',
        [Parameter()]
        [ValidateSet('Default', 'ReuseThread', 'UseCurrentThread', 'UseNewThread')]
        [string]$ThreadOptions = 'ReuseThread'
    )

    process {
        $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThreadLimit, $InitialSessionState, $Host)
        $runspacePool.ApartmentState = $ApartmentState
        $runspacePool.ThreadOptions = $ThreadOptions
        $runspacePool.CleanupInterval = [timespan]::FromMinutes(2)
        $runspacePool.Open()
        $runspacePool
    }
}

function New-WPFWindow {
    <#
        .SYNOPSIS
            Creates a WPF Window with given Xaml from a string or file
    #>
    [CmdletBinding(DefaultParameterSetName = 'HereString')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'HereString' )]
        [string]$Xaml,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateScript({ Test-Path $_ })]
        [System.IO.FileSystemInfo]$Path
    )

    if ($PSBoundParameters['Path']) {
        $Xaml = Get-Content -Path $Path
    }

    #Use the dedicated wpf xaml reader rather than the xmlreader.
    $window = [System.Windows.Markup.XamlReader]::Parse($Xaml)
    $window
}


# Powershell does not like classes with whitespace or comments in place of whitespace if copied and pasted in the console.
# Since the interface System.Windows.Input.ICommand methods Execute and CanExecute require parameters, we will keep it that way.
class RelayCommandBase : System.Windows.Input.ICommand {
    add_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::add_RequerySuggested($value)
        Write-Debug "$value added"
    }

    remove_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
        Write-Debug "$value removed"
    }

    # Invoke does not take a $null parameter so we wrap $null in an array for all cases
    # Providing the original method with $null will work, invoking with $null will not because invoke() provides arguments not parameters.
    # Arguments cannot be explicitly $null since they're optional
    # Maybe create delegate instead
    [bool]CanExecute([object]$commandParameter) {
        Write-Debug 'RelayCommandBase.CanExecute ran'
        if ($null -eq $this._canExecute) { return $true }
        return $this._canExecute.Invoke(@($commandParameter))
    }

    [void]Execute([object]$commandParameter) {
        try {
            $this._execute.Invoke(@($commandParameter))
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
        Write-Debug -Message $this._execute.ToString()

        $this._canExecute = $CanExecute
        if ($null -ne $this._canExecute) {
            Write-Debug -Message $this._canExecute.ToString()
        }
    }
}


# Support for parameterless PSMethods
# Doesn't seem clean
class RelayCommand : RelayCommandBase {
    [bool]CanExecute([object]$commandParameter) {
        if ($null -eq $this._canExecute) { return $true }
        # CanExecute is inefficient.
        # Write-Debug 'RelayCommand.CanExecute ran'
        if ($this._canExecuteCount -eq 1) { return $this._canExecute.Invoke($commandParameter) }
        else { return $this._canExecute.Invoke() }
    }

    [void]Execute([object]$commandParameter) {
        try {
            if ($this._executeCount -eq 1) { $this._execute.Invoke($commandParameter) }
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
        Write-Debug -Message $this._execute.ToString()

        $this._canExecute = $CanExecute
        if ($null -ne $this._canExecute) {
            $this._canExecuteCount = $this.GetParameterCount($CanExecute)
            Write-Debug -Message $this._canExecute.ToString()
        }
    }

    hidden [int]GetParameterCount([System.Management.Automation.PSMethod]$Method) {
        # Alternatively pass the viewmodel into RelayCommand
        # $ViewModel.GetType().GetMethod($PSMethod.Name).GetParameters().Count
        $param = $Method.OverloadDefinitions[0].Split('(').Split(')')[1]
        if ([string]::IsNullOrWhiteSpace($param)) { return 0 }

        $paramCount = $param.Split(',').Count
        Write-Debug "$($Method.OverloadDefinitions[0].Split('(').Split(')')[1].Split(',')) relaycommand param count"
        if ($paramCount -gt 1) { throw "RelayCommand expected parameter count 0 or 1. Found PSMethod with count $paramCount" }
        return $paramCount
    }
}


class DelegateCommand : System.Windows.Input.ICommand {
    # ICommand Implementation
    add_CanExecuteChanged([EventHandler] $value) {
        $this._internalCanExecuteChanged = [Delegate]::Combine($this._internalCanExecuteChanged, $value)
        [System.Windows.Input.CommandManager]::add_RequerySuggested($value)
        Write-Debug "$value added"
    }

    remove_CanExecuteChanged([EventHandler] $value) {
        $this._internalCanExecuteChanged = [Delegate]::Remove($this._internalCanExecuteChanged, $value)
        [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
        Write-Debug "$value removed"
    }

    # Delegate takes $null unlike invoking the PSMethod where it passes as arguments
    [bool]CanExecute([object]$commandParameter) {
        #Write-Debug 'DelegateCommand.CanExecute ran'
        if ($null -eq $this._canExecute) { return $true }
        return $this._canExecute.Invoke($commandParameter)
    }

    [void]Execute([object]$commandParameter) {
        try {
            $this._execute.Invoke($commandParameter)
        } catch {
            Write-Error "Error handling DelegateCommand.Execute: $_"
        }
    }
    # End ICommand Implementation

    [System.EventHandler]$_internalCanExecuteChanged

    [void] RaiseCanExecuteChanged() {
        if ($null -ne $this._canExecute) {
            $this.OnCanExecuteChanged()
        }
    }

    [void] OnCanExecuteChanged() {
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
        # Write-Debug -Message $this._execute.ToString()

        $this._canExecute = $CanExecute
        # if ($null -ne $this._canExecute) {
        #     Write-Debug -Message $this._canExecute.ToString()
        # }
    }
}


class ViewModelBase : ComponentModel.INotifyPropertyChanged {
    hidden [ComponentModel.PropertyChangedEventHandler] $_propertyChanged

    [void]add_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $this._propertyChanged = [Delegate]::Combine($this._propertyChanged, $value)
    }

    [void]remove_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $this._propertyChanged = [Delegate]::Remove($this._propertyChanged, $value)
    }

    [void]OnPropertyChanged([string] $propertyName) {
        Write-Debug "Notified change of property '$propertyName'."
        #$this._propertyChanged.Invoke($this, $propertyName) # Why does this accepting a string also work?
        #$this._PropertyChanged.Invoke($this, (New-Object PropertyChangedEventArgs $propertyName))
        # There are cases where it is null, which shoots a non terminating error. I forget when I ran into it.
        if ($null -ne $this._PropertyChanged) {
            $this._PropertyChanged.Invoke($this, [System.ComponentModel.PropertyChangedEventArgs]::new($propertyName))
        }

    }


    # static $ViewModelDispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher


    [void]Init([string] $propertyName) {
        $setter = [ScriptBlock]::Create("
            param(`$value)
            `$this.'_$propertyName' = `$value
            `$this.OnPropertyChanged('_$propertyName')
        ")
        $getter = [ScriptBlock]::Create("`$this.'_$propertyName'")

        $this | Add-Member -MemberType ScriptProperty -Name "$propertyName" -Value $getter -SecondValue $setter
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
        $returnType = $typeMethod.ReturnType.Name
        if ($returnType -eq 'Void') {
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
            $paramString += "$($p.ParameterType.Name),"
        }

        if ($paramString.Length -gt 0) {
            $paramString = $paramString.Substring(0, $paramString.Length - 1)
        } else {
            $delegateReturnParam = "[$returnType]"
            if ($returnType -eq 'Void') { $delegateReturnParam = '' }
        }

        $paramString += "$delegateReturnParam"
        $delegateString += "$paramString"
        Write-Debug "$($Method.Name) converted to: $delegateString"
        return $typeMethod.CreateDelegate(($delegateString -as [type]), $this)
    }

}


class MainWindowViewModel : ViewModelBase {
    [System.Windows.Threading.Dispatcher]$UIDispatcher
    $RunspacePoolDependency

    [int]$TextBoxText
    [int]$_TextBlockText
    [string]$NoParameterContent = 'No Parameter'
    [string]$ParameterContent = 'Parameter'
    [int]$ExtractedMethodRunCount
    [System.Windows.Input.ICommand]$TestCommand
    [System.Windows.Input.ICommand]$TestBackgroundCommand
    [bool]$_IsBackgroundFree = $true

    # Turn into cmdlet instead?
    # ScriptProperties cannot be bound to the xaml
    # Does not persist across runspaces - Add-Member does however
    # It is shared between runspaces if initialized in a runspace pool
    hidden static [void]Init([string] $propertyName) {
        $setter = [ScriptBlock]::Create("
            param(`$value)
            `$this.'_$propertyName' = `$value
            `$this.OnPropertyChanged('_$propertyName')
        ")
        $getter = [ScriptBlock]::Create("return `$this.'_$propertyName'")

        Update-TypeData -TypeName 'MainWindowViewModel' -MemberName $propertyName -MemberType ScriptProperty -Value $getter -SecondValue $setter
    }

    # This runs once and updates future types of this class in this scope will have the property. Other runspaces will need to load the class and initialize it.
    # Don't need to do it this way since we're only going to need one viewmodel. Useful if you need to create many.
    # For curosity / my first actual static method + constructor / demo purposes
    static MainWindowViewModel() {
        [MainWindowViewModel]::Init('TextBlockText')
        [MainWindowViewModel]::Init('IsBackgroundFree')
    }

    MainWindowViewModel($RunspacePool) {
        $this.UIDispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
        $this.RunspacePoolDependency = $RunspacePool

        $this.TestCommand = $this.NewDelegate(
            $this.UpdateTextBlock,
            $this.CanUpdateTextBlock
        )
        $this.TestBackgroundCommand = $this.NewDelegate(
            $this.BackgroundCommand,
            $this.CanBackgroundCommand
        )
        # $this.Init('TextBlockText')
        # $this.Init('IsBackgroundFree')
    }

    [void]ExtractedMethod([int]$i) {
        $this.ExtractedMethodRunCount++
        $this.TextBlockText += $i # Allowed since TextBlockText is added by Add-Member/Update-TypeData in which the set method raises OnPropertyChanged
        Write-Debug "$($this.TextBlockText)"
    }

    hidden [void]UpdateTextBlock([object]$RelayCommandParameter) {
        if ($null -eq $RelayCommandParameter) {
            $value = $this.TextBoxText
        } else {
            $value = $RelayCommandParameter
        }

        $this.ExtractedMethod($value)
    }

    # Is this code smell? Takes a parameter but will never use it... See class 'RelayCommand' for "fix"
    [bool]CanUpdateTextBlock([object]$RelayCommandParameter) {
        return (-not [string]::IsNullOrWhiteSpace($this.TextBoxText))
    }

    # Todo - move to ViewModelBase
    # Any RunspacePool task must call Dispatcher if it modifies the UI
    hidden [void]BackgroundInvoke ([System.Management.Automation.PSMethod]$Work, [object[]]$WorkParams, [System.Management.Automation.PSMethod]$Callback) {
        $workDelegate = $this.GetDelegate($Work)
        $callbackDelegate = $this.GetDelegate($Callback)
        $ps = [powershell]::Create()
        $ps.RunspacePool = $this.RunspacePoolDependency
        $ps.AddScript({
                param($delegate, $delegateParams, $callback)
                $callbackParam = [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke($delegate, $delegateParams)
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke($callback, $callbackParam)
            }
        ).AddParameter('delegate', $workDelegate).AddParameter('delegateParams', $WorkParams).AddParameter('callback', $callbackDelegate)

        $ps.BeginInvoke() # remember to add dispose with another thread
    }

    hidden [void]BackgroundCommand([object]$RelayCommandParameter) {
        $this.IsBackgroundFree = $false
        $this.TestBackgroundCommand.RaiseCanExecuteChanged()
        # delegates cannnot unbox PSObject - we've left the realm of powershell magic
        $param1 = $this.TextBoxText
        $param2 = [int]$this.TextBlockText
        $this.BackgroundInvoke($this.DoStuffBackgroundOrNot, ($param1, $param2), $this.BackgroundCallback)
    }

    [int]DoStuffBackgroundOrNot ([int]$WaitSeconds, [int]$StartNumber) {
        $increment = 1
        if ($WaitSeconds -lt 0) {
            $increment = -1
            $WaitSeconds *= $increment
        }

        $endNumber = $StartNumber
        for ($o = 1; $o -le $WaitSeconds; $o++) {
            Start-Sleep -Seconds 1
            $this.UIDispatcher.Invoke({ $this.ExtractedMethod($increment) })
        }
        $endNumber += ($WaitSeconds * $increment)
        return $endNumber
    }

    [void]BackgroundCallback($NumberToAdd) {
        $this.UIDispatcher.Invoke({
                $this.TextBlockText += $NumberToAdd
                $this.IsBackgroundFree = $true
                $this.TestBackgroundCommand.RaiseCanExecuteChanged()
                Write-Debug "$($this.TextBlockText)" # This crashes the ui if outside the dispatcher.invoke()
            }
        )
    }

    [bool]CanBackgroundCommand([object]$RelayCommandParameter) {
        return $this._IsBackgroundFree
    }

    # Slow
    [void]RefreshAllButtons() {
        $this.UIDispatcher.Invoke({ [System.Windows.Input.CommandManager]::InvalidateRequerySuggested() })
    }
}

# Alternative to [System.Windows.Forms.Application]::DoEvents() from Add-Type -AssemblyName System.Windows.Forms
class DispatcherUtil {
    [void]DoEvents($ExitFrameDelegate) {
        $frame = [System.Windows.Threading.DispatcherFrame]::new()
        $callback = [System.Windows.Threading.DispatcherOperationCallback]::Combine($ExitFrameDelegate)
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            $callback,
            $frame)
        [System.Windows.Threading.Dispatcher]::PushFrame($frame)
    }
    DispatcherUtil () {}
    [object]ExitFrame([object]$frame) {
        $frame.Continue = $false
        return $null
    }
}

function Send-Events {
    $utility = [DispatcherUtil]::new()
    $delgate = [DispatcherUtil].GetMethod('ExitFrame').CreateDelegate('func[object,object]' -as [type], $utility)
    $utility.DoEvents($delgate)
}

function Show-MessageBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Title = 'Test',
        [ValidateSet('OK', 'OKCancel', 'AbortRetryIgnore', 'YesNoCancel', 'YesNo', 'RetryCancel')]
        [string]$Button = 'OkCancel',
        [ValidateSet('None', 'Hand', 'Error', 'Stop', 'Question', 'Exclamation', 'Warning', 'Asterisk', 'Information')]
        [string]$Icon = 'Information'
    )
    [System.Windows.MessageBox]::Show("$Message", $Title, $Button, $Icon)
}


$Xaml = '<Window x:Class="System.Windows.Window"
x:Name="MainWindow"
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
xmlns:local="clr-namespace:;assembly="
mc:Ignorable="d"
Title="Minimal Example" Width="300" Height="250"
WindowStartupLocation="CenterScreen">
<!--
    <Window.DataContext>
        <local:MainWindowViewModel />
    </Window.DataContext>
-->
    <Grid>
        <StackPanel Margin="5">
            <!-- TextBox bound property does not update until textbox focus is lost. Use UpdateSourceTrigger=PropertyChanged to update as typed -->
            <TextBox x:Name="TextBox1" Text="{Binding TextBoxText, UpdateSourceTrigger=PropertyChanged}" MinHeight="30" />
            <TextBlock x:Name="TextBlock1" Text="{Binding _TextBlockText}" MinHeight="30" />
            <Button
                Content="{Binding NoParameterContent}"
                Command="{Binding TestCommand}" />
            <Button
                Content="{Binding ParameterContent}"
                Command="{Binding TestCommand}"
                CommandParameter="100" />
            <TextBlock Text="Current Background Tasks" MinHeight="30" />
            <TextBlock Text="{Binding CurrentBackgroundCount}" MinHeight="30" />
            <Button
                Content="Background Command"
                Command="{Binding TestBackgroundCommand}" />
        </StackPanel>
    </Grid>
</Window>
' #-creplace 'clr-namespace:;assembly=', "`$0$([MainWindowViewModel].Assembly.FullName)"
# BLACK MAGIC. Hard coding the FullName in the xaml does not work even after loading the ps1 file.
# If any edits, the console must be reset because the class/assembly stays loaded with the old viewmodel
# DataContext can be loaded in Xaml
# https://gist.github.com/nikonthethird/4e410ac3c04ea6633043a5cb7be1d717
