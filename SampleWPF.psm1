using module '.\Classes\WPFClassHelper\WPFClassHelper.psd1'
using namespace System.Windows
using namespace System.Collections.Generic

enum ViewModelNames {
    First
    Second
}

class WindowViewModel : ViewModelBase {
    $Content
    $WPFStates = [Dictionary[string, object]]::new()
    [Input.ICommand]$SwitchViewCommand = $this.NewDelegate($this.SwitchView)

    WindowViewModel() {}

    WindowViewModel([ViewModelNames]$Name, $ViewModel) {
        $this.AddView($Name, $ViewModel)
    }

    SwitchView([ViewModelNames]$Name) {
        $this.Content = $this.WPFStates[$Name]
        $this.OnPropertyChanged('Content')
    }

    AddView([ViewModelNames]$Name, $ViewModel) {
        $this.WPFStates.Add($Name, $ViewModel)
        if ($this.WPFStates.Count -eq 1) { $this.SwitchView($Name) }
    }
}

class FirstViewModel : ViewModelBase {
    static [DependencyProperty]$ResultProperty = [DependencyProperty]::Register(
        'Result', [int], [FirstViewModel], [PropertyMetadata]::new(0)
    )

    static [DependencyProperty]$PrimaryInputProperty = [DependencyProperty]::Register(
        'PrimaryInput', [int], [FirstViewModel], [PropertyMetadata]::new(0)
    )

    static [DependencyProperty]$IsBackgroundFreeProperty = [DependencyProperty]::Register(
        'IsBackgroundFree', [bool], [FirstViewModel], [PropertyMetadata]::new($true, {
                param([FirstViewModel]$vm, [DependencyPropertyChangedEventArgs]$e)
                $vm.TestBackgroundCommand.RaiseCanExecuteChanged()
            })
    )

    [string]$NoParameterContent = 'No Parameter'
    [string]$ParameterContent = 'Command Parameter'
    [int]$UpdateResultRunCount
    [Input.ICommand]$UpdateResultCommand = $this.NewDelegate($this.UpdateResult, $this.CanUpdateResult)
    [Input.ICommand]$TestBackgroundCommand = $this.NewDelegate($this.BackgroundCommand, $this.CanRunBackgroundCommand)

    FirstViewModel() {
        $this.Start()
        $this.Initialize()
    }

    FirstViewModel($RunspacePool) {
        $this.Start()
        $this.Initialize($RunspacePool)
    }

    hidden Start() {
        $this.UIDispatcher = [Threading.Dispatcher]::CurrentDispatcher
    }

    [void]UpdateResult([int]$i) {
        if ($i -eq 0) { $i = $this.GetValue([FirstViewModel]::PrimaryInputProperty) }
        $this.UpdateResultRunCount++
        $this.SetValue([FirstViewModel]::ResultProperty, $this.GetValue([FirstViewModel]::ResultProperty) + $i)
    }

    [bool]CanUpdateResult([object]$RelayCommandParameter) {
        return ($this.GetValue([FirstViewModel]::PrimaryInputProperty) -ne 0)
    }

    [void]BackgroundCommand([object]$RelayCommandParameter) {
        $this.SetValue([FirstViewModel]::IsBackgroundFreeProperty, $false)
        $param1 = $this.GetValue([FirstViewModel]::PrimaryInputProperty)
        $param2 = $this.GetValue([FirstViewModel]::ResultProperty)
        $this.BackgroundInvoke($this.DoStuffBackgroundOrNot, ($param1, $param2), $this.BackgroundCallback, $true)
    }

    [int]DoStuffBackgroundOrNot([int]$WaitSeconds, [int]$StartNumber) {
        $increment = 1
        if ($WaitSeconds -lt 0) {
            $increment = -1
            $WaitSeconds *= $increment
        }

        $endNumber = $StartNumber
        for ($o = 1; $o -le $WaitSeconds; $o++) {
            [System.Threading.Thread]::Sleep(1000)
            $this.UIDispatcher.BeginInvoke(4, [action[object, int]]{
                param($this, $NumberToAdd)
                $this.UpdateResult($NumberToAdd)
            }, $this, 1)
        }
        $endNumber += ($WaitSeconds * $increment)
        return $endNumber
    }

    [void]BackgroundCallback($NumberToAdd) {
        $this.UIDispatcher.BeginInvoke(4, [action[object, int]]{
            param($this, $NumberToAdd)
            $this.SetValue([FirstViewModel]::ResultProperty, $this.GetValue([FirstViewModel]::ResultProperty) + $NumberToAdd)
            $this.SetValue([FirstViewModel]::IsBackgroundFreeProperty, $true)
        }, $this, $NumberToAdd)
    }

    [bool]CanRunBackgroundCommand([object]$RelayCommandParameter) {
        return $this.GetValue([FirstViewModel]::IsBackgroundFreeProperty)
    }
}

class SecondViewModel : ViewModelBase {
    $TextToDisplay = 'No need to specify two way binding or raise OnPropertyChanged'
    [Input.ICommand]$PrintPasswordCommand = $this.NewDelegate($this.PrintPassword)
    [Input.ICommand]$ShowMessageBoxCommand = $this.NewDelegate($this.ShowMessageBox)

    SecondViewModel() {}

    [void]PrintPassword($CommandParameter) {
        Write-Verbose "This is in the password box: $($CommandParameter.Password)" -Verbose
    }

    [void]ShowMessageBox($CommandParameter) {
        Show-WPFMessageBox -Message $this.TextToDisplay
    }
}
