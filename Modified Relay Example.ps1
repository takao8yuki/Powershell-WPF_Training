#Remember to add the below two assemblies and dot source this file since powershell parses classes before add-types
Add-Type -AssemblyName presentationframework, presentationcore


function New-WPFWindow {
    [CmdletBinding(DefaultParameterSetName = 'HereString')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'HereString' )]
        [string]$Xaml,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateScript({ Test-Path $_ })]
        [System.IO.FileSystemInfo]$Path
    )

    if ($Path) {
        $Xaml = Get-Content -Path $Path
    }

    #Use the dedicated wpf xaml reader rather than the xmlreader. This allows skipping Get-CleanXML.
    $window = [System.Windows.Markup.XamlReader]::Parse($Xaml)
    $window
}

#Not needed
function Get-CleanXML {
    Param([string]$RawInput)
    $RawInput -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace 'x:Class=".*?"', '' -replace 'd:DesignHeight="\d*?"', '' -replace 'd:DesignWidth="\d*?"', ''
}

#Not needed - use $mainWindow.FindName('Name Of Xaml Object')
function Get-XamlNamedNodes {
    Param([xml]$Xml)
    $Xml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
}

# Powershell does not like classes with whitespace or comments in place of whitespace if copied and pasted in the console.
class RelayCommand : System.Windows.Input.ICommand {
    add_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::add_RequerySuggested($value)
        Write-Debug $value
    }

    remove_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
        Write-Debug $value
    }

    [bool]CanExecute([object]$arg) {
        if ($null -eq $this.canRunCommand) { return $true }
        return $this.canRunCommand.Invoke($this.vm, $arg)
    }

    [void]Execute([object]$commandParameter) {
        try {
            $this.action.invoke($commandParameter)
        } catch {
            Write-Error "Error handling Execute: $_"
        }
    }

    hidden [object]$vm
    hidden [string]$methodName
    hidden [scriptblock]$canRunCommand
    hidden [scriptblock]$action

    RelayCommand($ViewModel, $MethodName, $CanExecute) {
        $this.vm = $ViewModel
        $this.methodName = $MethodName
        Write-Debug -Message $this.methodName.ToString()
        $methodParameterCount = $this.vm.GetType().GetMethod($this.methodName).GetParameters().Count

        if ($methodParameterCount -eq 1) {
            $this.action = {$this.vm.($this.methodName)($commandParameter)}
        } elseif ($methodParameterCount -gt 1) {
            throw "$($this.methodName) has too many parameters. Refer to the viewmodel's internal properties instead."
        }
        else {
            #this looks stupid but it works. It allows passing the method by name similar to C# relay command examples
            $this.action = {$this.vm.($this.methodName)()}
        }

        if ([string]::IsNullOrWhiteSpace(($CanExecute.ToString().Trim()))) {
            $this.canRunCommand = $null
        } else {
            $this.canRunCommand = [scriptblock]::Create("param(`$this, `$arg)`n&{$CanExecute}")
            Write-Debug -Message $this.canRunCommand.ToString()
        }
    }
}


class ViewModelBase : ComponentModel.INotifyPropertyChanged {
    hidden [ComponentModel.PropertyChangedEventHandler] $_propertyChanged

    [void] add_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $this._propertyChanged = [Delegate]::Combine($this._propertyChanged, $value)
    }

    [void] remove_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $this._propertyChanged = [Delegate]::Remove($this._propertyChanged, $value)
    }

    [void] OnPropertyChanged([string] $propertyName) {
        Write-Debug "Notified change of property '$propertyName'."
        #$this._propertyChanged.Invoke($this, $propertyName) # Why does this accepting a string also work?
        #$this._PropertyChanged.Invoke($this, (New-Object PropertyChangedEventArgs $propertyName))
        $this._PropertyChanged.Invoke($this, [System.ComponentModel.PropertyChangedEventArgs]::new($propertyName))
    }

    [void]Init([string] $propertyName) {
        $setter = [ScriptBlock]::Create("
            param(`$value)
            `$this.'$propertyName' = `$value
            `$this.OnPropertyChanged('$propertyName')
        ")

        $getter = [ScriptBlock]::Create("`$this.'$propertyName'")

        $this | Add-Member -MemberType ScriptMethod -Name "Set$propertyName" -Value $setter
        $this | Add-Member -MemberType ScriptMethod -Name "Get$PropertyName" -Value $getter
    }

    [Windows.Input.ICommand]NewCommand(
        [string]$MethodName,
        [ScriptBlock]$CanExecute
    ) {
        if ($null -eq ($this | Get-Member -Name $MethodName)) { throw "$MethodName is not a methood in $($this.GetType().Name)" }
        return [RelayCommand]::new($this, $MethodName, $CanExecute)
    }
}


class MainWindowViewModel : ViewModelBase {
    [string]$TextBoxText
    [string]$TextBlockText
    [string]$Button1Content = 'TestCommand'
    [string]$Button2Content = 'TestCommand2'
    [System.Windows.Input.ICommand]$TestCommand
    [System.Windows.Input.ICommand]$TestCommand2

    MainWindowViewModel() {
        $this.Init('TextBlockText')

        $this.TestCommand = $this.NewCommand(
            'TestMethod',
            {}
        )

        $this.TestCommand2 = $this.NewCommand(
            'TestTwo',
            {}
        )
    }

    [int]$i
    [void] TestMethod($CommandParameter) {
        $result = Show-MessageBox -Message "TextBoxText is '$($this.TextBoxText)'`nCommand Parameter is '$CommandParameter'`nOk to add TextBoxText with TextBox data`nNo to add command parameter data."

        if ($result -eq 'OK') {
            $value = $this.TextBoxText
        } else {
            $value = $CommandParameter
        }

        $this.i += $value
        $this.SetTextBlockText($this.i)
        Write-Debug $this.i
    }

    [void]TestTwo() {
        $result = Show-MessageBox -Message "Ok to add 10`nNo to add 1"
        if ($result -eq 'OK') {
            $value = 10
        } else {
            $value = 1
        }

        $this.i += $value
        $this.SetTextBlockText($this.i)
        Write-Debug $this.i
    }
}

function Show-MessageBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Title = "Test",
        [string]$Button = "OkCancel",
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
Title="Minimal Example" Width="300" Height="150">
<!--
    <Window.DataContext>
        <local:MainWindowViewModel />
    </Window.DataContext>
-->
    <Grid>
        <StackPanel Margin="5">
            <TextBox x:Name="TextBox1" Text="{Binding TextBoxText}" MinHeight="30" />
            <TextBlock x:Name="TextBlock1" Text="{Binding TextBlockText}" MinHeight="30" />
            <Button
                x:Name="Button1"
                Content="{Binding Button1Content}"
                CommandParameter="3"
                Command="{Binding TestCommand}" />
            <Button
                x:Name="Button2"
                Content="{Binding Button2Content}"
                Command="{Binding TestCommand2}" />
        </StackPanel>
    </Grid>
</Window>
' #-creplace 'clr-namespace:;assembly=', "`$0$([MainWindowViewModel].Assembly.FullName)"    # BLACK MAGIC. Hard coding the FullName in the xaml does not work.
# If any edits, the console must be reset because the assembly stays loaded with the old viewmodel?
$window = New-WPFWindow -Xaml $Xaml
# DataContext can be loaded in Xaml
# https://gist.github.com/nikonthethird/4e410ac3c04ea6633043a5cb7be1d717
$window.DataContext = [MainWindowViewModel]::new()

$async = $window.Dispatcher.InvokeAsync({
    $null = $window.ShowDialog()
})
$null = $async.Wait()
