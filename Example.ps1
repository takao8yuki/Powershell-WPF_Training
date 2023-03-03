#Remember to add the below two assemblies and dot source this file since powershell parses classes before add-types
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

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

        if ($PSBoundParameters.ContainsKey('ModulePaths')) {
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

        if ($PSBoundParameters.ContainsKey('StartUpScripts')) {
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
        [Parameter()]
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
        $State = if ($PSBoundParameters.ContainsKey('InitialSessionState')) { $InitialSessionState } else { [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault() }
        $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThreadLimit, $State, $Host)
        $runspacePool.ApartmentState = $ApartmentState
        $runspacePool.ThreadOptions = $ThreadOptions
        $runspacePool.CleanupInterval = [timespan]::FromMinutes(2)
        $runspacePool.Open()
        $runspacePool
    }
}

function New-WPFObject {
    <#
        .SYNOPSIS
            Creates a WPF object with given Xaml from a string or file
            Uses the dedicated wpf xaml reader rather than the xmlreader.
    #>
    [CmdletBinding(DefaultParameterSetName = 'HereString')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'HereString' )]
        [string[]]$Xaml,

        [Alias('FullName')]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [ValidateScript({ Test-Path $_ })]
        [string[]]$Path
    )

    process {
        $RawXaml = if ($PSBoundParameters.ContainsKey('Path')) {
            Get-Content -Path $Path
        } else {
            $Xaml
        }

        [System.Windows.Markup.XamlReader]::Parse($RawXaml)
    }
}


# Powershell does not like classes with whitespace or comments in place of whitespace if copied and pasted in the console.
# Since the interface System.Windows.Input.ICommand methods Execute and CanExecute require parameters, we will keep it that way.
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
    # Maybe create delegate instead
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
        [System.Windows.Input.CommandManager]::add_RequerySuggested($value)
    }

    remove_CanExecuteChanged([EventHandler] $value) {
        $this._internalCanExecuteChanged = [Delegate]::Remove($this._internalCanExecuteChanged, $value)
        [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
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
    hidden [ComponentModel.PropertyChangedEventHandler] $_propertyChanged

    [void]add_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $this._propertyChanged = [Delegate]::Combine($this._propertyChanged, $value)
    }

    [void]remove_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $this._propertyChanged = [Delegate]::Remove($this._propertyChanged, $value)
    }

    [void]OnPropertyChanged([string] $propertyName) {
        #$this._propertyChanged.Invoke($this, $propertyName) # Why does this accepting a string also work?
        # There are cases where it is null, which shoots a non terminating error. I forget when I ran into it.
        if ($null -ne $this._PropertyChanged) {
            $this._PropertyChanged.Invoke($this, [System.ComponentModel.PropertyChangedEventArgs]::new($propertyName))
            # Write-Debug "Notified change of property '$propertyName'."
        }

    }
    # End INotifyPropertyChanged Implementation

    [System.Windows.Threading.Dispatcher]$UIDispatcher
    $RunspacePoolDependency

    [void]Init([string] $propertyName) {
        $setter = [ScriptBlock]::Create("
            param(`$value)
            `$this.'_$propertyName' = `$value
            `$this.OnPropertyChanged('_$propertyName')
        ")
        $getter = [ScriptBlock]::Create("`$this.'_$propertyName'")

        $this | Add-Member -MemberType ScriptProperty -Name "$propertyName" -Value $getter -SecondValue $setter
    }

    # Any RunspacePool task must call Dispatcher if it modifies the UI
    hidden [void]BackgroundInvoke ([System.Management.Automation.PSMethod]$Work, [object[]]$WorkParams, [System.Management.Automation.PSMethod]$Callback) {
        if ($null -eq $this.RunspacePoolDependency) {throw "Can't run a background task without a runspace."}

        $workDelegate = $this.GetDelegate($Work)
        $callbackDelegate = $this.GetDelegate($Callback)
        $ps = [powershell]::Create()
        $ps.RunspacePool = $this.RunspacePoolDependency
        $ps.AddScript({
                param($Delegate, $DelegateParams, $Callback)
                $callbackParam = [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke($Delegate, $DelegateParams)
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke($Callback, $callbackParam)
            }
        ).AddParameter('Delegate', $workDelegate).AddParameter('DelegateParams', $WorkParams).AddParameter('Callback', $callbackDelegate)

        # Do we have to dispose? Memory doesn't seem to constantly increase after invokeing multiple times.
        $null = $ps.BeginInvoke()
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
        # Write-Debug "$($Method.Name) converted to: $delegateString"
        return $typeMethod.CreateDelegate(($delegateString -as [type]), $this)
    }

}


class MainWindowViewModel : ViewModelBase {
    [int]$PrimaryInput
    [int]$_Result
    [string]$NoParameterContent = 'No Parameter'
    [string]$ParameterContent = 'Parameter'
    [int]$ExtractedMethodRunCount
    [System.Windows.Input.ICommand]$TestCommand = $this.NewDelegate($this.UpdateTextBlock, $this.CanUpdateTextBlock)
    [System.Windows.Input.ICommand]$TestBackgroundCommand = $this.NewDelegate($this.BackgroundCommand, $this.CanBackgroundCommand)
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
        [MainWindowViewModel]::Init('Result')
        [MainWindowViewModel]::Init('IsBackgroundFree')
    }

    MainWindowViewModel() {
        $this.Start($null)
    }

    MainWindowViewModel($RunspacePool) {
        $this.Start($RunspacePool)
    }

    hidden Start($Pool) {
        $this.UIDispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
        if ($null -ne $Pool) { $this.RunspacePoolDependency = $Pool }
        # $this.Init('Result')
        # $this.Init('IsBackgroundFree')
    }

    [void]ExtractedMethod([int]$i) {
        $this.ExtractedMethodRunCount++
        $this.Result += $i # Allowed since Result is added by Add-Member/Update-TypeData in which the set method raises OnPropertyChanged
    }

    hidden [void]UpdateTextBlock([object]$RelayCommandParameter) {
        if ($null -eq $RelayCommandParameter) {
            $value = $this.PrimaryInput
        } else {
            $value = $RelayCommandParameter
        }

        $this.ExtractedMethod($value)
    }

    # Is this code smell? Takes a parameter but will never use it... See class 'RelayCommand' for "fix"
    [bool]CanUpdateTextBlock([object]$RelayCommandParameter) {
        return ($this.PrimaryInput -ne 0)
    }

    hidden [void]BackgroundCommand([object]$RelayCommandParameter) {
        $this.IsBackgroundFree = $false
        $this.TestBackgroundCommand.RaiseCanExecuteChanged()
        # delegates cannnot unbox PSObject - we've left the realm of powershell magic
        $param1 = $this.PrimaryInput
        $param2 = [int]$this.Result
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
                $this.Result += $NumberToAdd
                $this.IsBackgroundFree = $true
                $this.TestBackgroundCommand.RaiseCanExecuteChanged()
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


class MainWindowViewModelDP : ViewModelBase {
    static [System.Windows.DependencyProperty]$ResultProperty = [System.Windows.DependencyProperty]::Register(
        '_Result', [int], [MainWindowViewModelDP], [System.Windows.PropertyMetadata]::new(0, {
                param([MainWindowViewModelDP]$vm, [System.Windows.DependencyPropertyChangedEventArgs] $e)
                Write-Debug "ResultProperty new value: $($e.NewValue)"
                if ($e.NewValue -eq 10) {
                    Write-Debug 'I do callback if ResultProperty is 10'
                }
            })
    )

    static [System.Windows.DependencyProperty]$PrimaryInputProperty = [System.Windows.DependencyProperty]::Register(
        'PrimaryInput', [int], [MainWindowViewModelDP], [System.Windows.PropertyMetadata]::new(0, {
                param([MainWindowViewModelDP]$vm, [System.Windows.DependencyPropertyChangedEventArgs] $e)
                Write-Debug "PrimaryInputProperty new value: $($e.NewValue)"
                if ($e.NewValue -gt 10000) {
                    Write-Debug 'I do calback if PrimaryInputProperty is greater than 10,000'
                }
                Write-Debug "$($vm.NoParameterContent) I have access to this vm"
            })
    )

    static [System.Windows.DependencyProperty]$IsBackgroundFreeProperty = [System.Windows.DependencyProperty]::Register(
        'IsBackgroundFree', [bool], [MainWindowViewModelDP], [System.Windows.PropertyMetadata]::new($true, {
                param([MainWindowViewModelDP]$vm, [System.Windows.DependencyPropertyChangedEventArgs] $e)
                Write-Debug "IsBackgroundFreeProperty new value: $($e.NewValue)"
                if ($e.NewValue -eq $false) {
                    Write-Debug 'I do callback if IsBackgroundFreeProperty is not true'
                }
            })
    )

    [string]$NoParameterContent = 'No Parameter'
    [string]$ParameterContent = 'Parameter'
    [int]$ExtractedMethodRunCount
    [System.Windows.Input.ICommand]$TestCommand = $this.NewDelegate($this.UpdateTextBlock, $this.CanUpdateTextBlock)
    [System.Windows.Input.ICommand]$TestBackgroundCommand = $this.NewDelegate($this.BackgroundCommand, $this.CanBackgroundCommand)

    MainWindowViewModelDP() {
        $this.Start($null)
    }

    MainWindowViewModelDP($RunspacePool) {
        $this.Start($RunspacePool)
    }

    hidden Start($Pool) {
        $this.UIDispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
        if ($null -ne $Pool) { $this.RunspacePoolDependency = $Pool }
    }

    [void]ExtractedMethod([int]$i) {
        $this.ExtractedMethodRunCount++
        $this.SetValue([MainWindowViewModelDP]::ResultProperty, $this.GetValue([MainWindowViewModelDP]::ResultProperty) + $i)
    }

    hidden [void]UpdateTextBlock([object]$RelayCommandParameter) {
        if ($null -eq $RelayCommandParameter) {
            $value = $this.GetValue([MainWindowViewModelDP]::PrimaryInputProperty)
        } else {
            $value = $RelayCommandParameter
        }

        $this.ExtractedMethod($value)
    }

    [bool]CanUpdateTextBlock([object]$RelayCommandParameter) {
        return ($this.GetValue([MainWindowViewModelDP]::PrimaryInputProperty) -ne 0)
    }

    hidden [void]BackgroundCommand([object]$RelayCommandParameter) {
        $this.SetValue([MainWindowViewModelDP]::IsBackgroundFreeProperty, $false)
        $this.TestBackgroundCommand.RaiseCanExecuteChanged()

        $param1 = $this.GetValue([MainWindowViewModelDP]::PrimaryInputProperty)
        $param2 = $this.GetValue([MainWindowViewModelDP]::ResultProperty)
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
                $this.SetValue([MainWindowViewModelDP]::ResultProperty, $this.GetValue([MainWindowViewModelDP]::ResultProperty) + $NumberToAdd)
                $this.SetValue([MainWindowViewModelDP]::IsBackgroundFreeProperty, $true)
                $this.TestBackgroundCommand.RaiseCanExecuteChanged()
            }
        )
    }

    [bool]CanBackgroundCommand([object]$RelayCommandParameter) {
        return $this.GetValue([MainWindowViewModelDP]::IsBackgroundFreeProperty)
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
            <TextBox x:Name="TextBox1" Text="{Binding PrimaryInput, UpdateSourceTrigger=PropertyChanged}" MinHeight="30" />
            <TextBlock x:Name="TextBlock1" Text="{Binding _Result}" MinHeight="30" />
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
