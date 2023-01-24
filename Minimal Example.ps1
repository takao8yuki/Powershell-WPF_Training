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

    <# old way with nodes
    [xml]$Xaml = Get-CleanXML -RawInput $Xaml
    $NamedNodes = Get-XamlNamedNodes -Xml $Xaml
    $reader = ([System.Xml.XmlNodeReader]::new($Xaml))
    $form = [Windows.Markup.XamlReader]::Load($reader)

    $wpf = @{}
    $NamedNodes | ForEach-Object { $wpf.Add($_.Name, $form.FindName($_.Name)) }
    $wpf
    #>

}

#Not needed
function Get-CleanXML {
    Param([string]$RawInput)
    $RawInput -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace 'x:Class=".*?"', '' -replace 'd:DesignHeight="\d*?"', '' -replace 'd:DesignWidth="\d*?"', ''
}

#Only used if you need to use the code behind. For example, adding Button1.add_MouseLeftButtonDown()
function Get-XamlNamedNodes {
    Param([xml]$Xml)
    $Xml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
}

# Powershell does not like classes with whitespace or comments in place of whitespace if copied and pasted in the console.
class Relay : System.Windows.Input.ICommand {
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
            $this.command.Invoke($this.vm, $commandParameter)
        } catch {
            Write-Error "Error handling Execute: $_"
        }
    }

    hidden [object]$vm
    hidden [scriptblock]$command
    hidden [scriptblock]$canRunCommand

    # Parameter in viewmodel must use the variable name '$commandParameter' in order to take bound command parameters
    # Are command parameters needed?
    # Button methods should already have access to the viewmodel properties. For example, bound SelectedItems and its model properties.
    # Parameter in viewmodel must use the variable name '$commandParameter' in order to take bound command parameters
    # Are command parameters needed?
    # Button methods should already have access to the viewmodel properties. For example, bound SelectedItems and its model properties.
    Relay($ViewModel, $Execute, $CanExecute) {
        $this.vm = $ViewModel
        $this.command = [scriptblock]::Create("param(`$this, `$commandParameter)`n&{$Execute}")
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
        $this._propertyChanged.Invoke($this, $propertyName)
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
}


class MainWindowViewModel : ViewModelBase {
    hidden [ComponentModel.PropertyChangedEventHandler] $_propertyChanged = {}

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

    [string]$TextBoxText
    [string]$TextBlockText
    [string]$Button1Content = 'test button'
    [System.Windows.Input.ICommand]$TestCommand

    MainWindowViewModel() {
        $this.Init('TextBlockText')
        $this.TestCommand = [Relay]::new(
            $this,
            {
                $result = Show-MessageBox -Message "Command Parameter is '$commandParameter'`nTextBoxText is '$($this.TextBoxText)'`nOk to set TextBoxText with TextBox data`nNo for command parameter data."
                if ($result -eq 'OK') { $this.SetTextBlockText($this.TextBoxText) } else { $this.SetTextBlockText($commandParameter) }
            },
            {}
        )
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
    <Window.DataContext>
        <local:MainWindowViewModel />
    </Window.DataContext>

    <Grid>
        <StackPanel Margin="5">
            <TextBox x:Name="TextBox1" Text="{Binding TextBoxText}" MinHeight="30" />
            <TextBlock x:Name="TextBlock1" Text="{Binding TextBlockText}" MinHeight="30" />
            <Button
                x:Name="Button1"
                Content="{Binding Button1Content}"
                CommandParameter="Test Param"
                Command="{Binding TestCommand}" />
        </StackPanel>
    </Grid>
</Window>
' -creplace 'clr-namespace:;assembly=', "`$0$([MainWindowViewModel].Assembly.FullName)" # BLACK MAGIC. Hard coding the FullName in the xaml does not work.

$window = New-WPFWindow -Xaml $Xaml
# DataContext can be loaded in Xaml
# https://gist.github.com/nikonthethird/4e410ac3c04ea6633043a5cb7be1d717
#$window.DataContext = [MainWindowViewModel]::new()

$async = $window.Dispatcher.InvokeAsync({
        $window.ShowDialog() | Out-Null
    })
$async.Wait() | Out-Null
