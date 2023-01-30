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
class RelayCommand : System.Windows.Input.ICommand {
    add_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::add_RequerySuggested($value)
        Write-Debug "$value added"
    }

    remove_CanExecuteChanged([EventHandler] $value) {
        [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
        Write-Debug "$value removed"
    }

    [bool]CanExecute([object]$commandParameter) {
        if ($null -eq $this._canExecute) { return $true }

        if ($this._canExecuteCount -eq 1) { return $this._canExecute.Invoke($commandParameter) }
        else { return $this._canExecute.Invoke() }
    }

    [void]Execute([object]$commandParameter) {
        try {
            if ($this._executeCount -eq 1) { $this._execute.Invoke($commandParameter) }
            else { $this._execute.Invoke() }
        } catch {
            Write-Error "Error handling Execute: $_"
        }
    }

    hidden [System.Management.Automation.PSMethod]$_execute
    hidden [int]$_executeCount
    hidden [System.Management.Automation.PSMethod]$_canExecute
    hidden [int]$_canExecuteCount

    RelayCommand($Execute, $CanExecute) {
        $this.Init($Execute, $CanExecute)
    }

    RelayCommand($Execute) {
        $this.Init($Execute, $null)
    }

    hidden Init($Execute, $CanExecute){
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
        $param = $Method.OverloadDefinitions[0].Split("(").Split(")")[1]
        if ([string]::IsNullOrWhiteSpace($param)){return 0}

        $paramCount = $param.Split(",").Count
        Write-Debug "$($Method.OverloadDefinitions[0].Split("(").Split(")")[1].Split(","))"
        if ($paramCount -gt 1) { throw "RelayCommand expected parameter count 0 or 1. Found PSMethod with count $paramCount" }
        return $paramCount
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
        [System.Management.Automation.PSMethod]$Execute,
        [System.Management.Automation.PSMethod]$CanExecute
    ) {
        return [RelayCommand]::new($Execute, $CanExecute)
    }

    [Windows.Input.ICommand]NewCommand(
        [System.Management.Automation.PSMethod]$Execute
    ) {
        return [RelayCommand]::new($Execute)
    }
}


class MainWindowViewModel : ViewModelBase {
    [string]$TextBoxText
    [string]$TextBlockText
    [string]$Button1Content = 'test button'
    [System.Windows.Input.ICommand]$TestCommand

    MainWindowViewModel() {
        $this.Init('TextBlockText')

        $this.TestCommand = $this.NewCommand(
            $this.UpdateTextBlock,
            $this.CanUpdateTextBlock
        )
    }

    [int]$i
    [void]ExtractedMethod([int]$i) {
        $this.i += $i
        $this.SetTextBlockText($this.i)
        Write-Debug $i
    }

    [void]UpdateTextBlock([object]$RelayCommandParameter) {
        $message = "TextBoxText is $($this.TextBoxText)`nCommand Parameter is $RelayCommandParameter`nOK To add TextBoxText`nNo to add RelayCommandParameter"
        $result = Show-MessageBox -Message $message

        if ($result -eq 'OK') {
            $value = $this.TextBoxText
        } else {
            $value = $RelayCommandParameter
        }

        $this.ExtractedMethod($value)
    }

    [bool]CanUpdateTextBlock() {
        return $true
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
        </StackPanel>
    </Grid>
</Window>
' #-creplace 'clr-namespace:;assembly=', "`$0$([MainWindowViewModel].Assembly.FullName)"
# BLACK MAGIC. Hard coding the FullName in the xaml does not work.
# If any edits, the console must be reset because the assembly stays loaded with the old viewmodel?
# DataContext can be loaded in Xaml
# https://gist.github.com/nikonthethird/4e410ac3c04ea6633043a5cb7be1d717

$window = New-WPFWindow -Xaml $Xaml
$window.DataContext = [MainWindowViewModel]::new()

$async = $window.Dispatcher.InvokeAsync(
    { $null = $window.ShowDialog() }
)
$null = $async.Wait()
