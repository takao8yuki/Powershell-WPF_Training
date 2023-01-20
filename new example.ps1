using namespace System.Windows
using namespace System.Collections.ObjectModel

Add-Type -AssemblyName presentationframework, presentationcore
#Add-Type -AssemblyName System.Windows
#Add-Type -AssemblyName System.Collections


function New-WPFObject {
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

    [xml]$Xaml = Get-CleanXML -RawInput $Xaml
    $NamedNodes = Get-XamlNamedNodes -Xml $Xaml
    $reader = ([System.Xml.XmlNodeReader]::new($Xaml))
    $form = [Windows.Markup.XamlReader]::Load($reader)

    $wpf = @{}
    $NamedNodes | ForEach-Object { $wpf.Add($_.Name, $form.FindName($_.Name)) }
    $wpf
}


function Get-CleanXML {
    Param([string]$RawInput)
    $RawInput -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace 'x:Class=".*?"', '' -replace 'd:DesignHeight="\d*?"', '' -replace 'd:DesignWidth="\d*?"', ''
}


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


class MainWindowVM : ComponentModel.INotifyPropertyChanged {
    hidden [ComponentModel.PropertyChangedEventHandler] $_propertyChanged = {}
    [void] add_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $p = $this._propertyChanged
        $this._propertyChanged = [Delegate]::Combine($p, $value)
    }
    [void] remove_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $this._propertyChanged = [Delegate]::Remove($this._propertyChanged, $value)
    }
    [void] OnPropertyChanged([string] $propertyName) {
        Write-Host "Notified change of property '$propertyName'."
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
    hidden [System.Windows.Threading.DispatcherTimer] $_timer
    [string]$Title = "test"
    [string]$UserPath = 'E:\Testing Folder'
    [string]$buttonContent = "Click!"
    [string]$buttonContent2 = "Find"
    [string]$buttonContent3 = "Create"
    [string]$buttonContent4 = "Reset"
    [int]$Item = 1
    [int]$Item2
    [System.Windows.Input.ICommand]$ShowCommand
    [bool]$BtnBool = $true
    [System.Windows.Input.ICommand]$CreateFolderCommand
    [ObservableCollection[object]]$TestDataGrid
    [System.Windows.Input.ICommand]$GenerateGridCommand
    [System.Windows.Input.ICommand]$CheckAllGenerateCommand
    [System.Windows.Input.ICommand]$CheckGenerateCommand
    [System.Windows.Input.ICommand]$ResetGridCommand
    [bool]$IsGenerateChecked
    MainWindowVM() {
        $this.Init('Title')
        $this.Init('Item')
        $this.Init('Item2')
        $this.Init('IsGenerateChecked')
        $this.SetIsGenerateChecked($false)
        $this.TestDataGrid = [ObservableCollection[object]]::new()
        $this.ShowCommand = [Relay]::new($this, {
                $this.BtnBool = $false
                $this.SetItem($this.Item + $this.Title)
                $this.SetItem2($this.Title)
                Show-MessageBox "commandParameter: $($commandParameter) vmItem: $($this.Item) vmTitle: $($this.Title)"
            },
            { $this.BtnBool })
        $this.GenerateGridCommand = [Relay]::new($this, {
                if (-not $this.Title) { Show-MessageBox 'Name cannot be empty' ; return }
                $nameList = $this.Title.Split("`n")
                $nameList | ForEach-Object { if (-not [string]::IsNullOrWhiteSpace($_)) {
                        $row = [UserFileChoiceModel]::new($_.Trim(), 'Typical', $true, $null) #can't be created inside .Add() - it won't notify
                        $this.TestDataGrid.Add($row)
                    } }
                $this.SetTitle($null)
                $check = $true
                foreach ($item in $this.TestDataGrid) {
                    if (-not $item.Generate) {
                        $check = $false
                        break
                    }
                }
                $this.SetIsGenerateChecked($check)
                Write-Debug -Message "generated grid"
            }, {
                if ([string]::IsNullOrWhiteSpace($this.UserPath)) { return $false }
                if ($null -eq $this.Title) { return $false }
                Test-Path -Path $this.UserPath
            })
        $this.CreateFolderCommand = [Relay]::new($this, {
                $this.TestDataGrid | ForEach-Object {
                    if ($_.Generate) {
                        $item = New-Item -Path $this.UserPath -Name $($_.Name) -ItemType Directory
                        if ($item) {
                            $_.SetGenerate($false)
                            $_.SetFullName($item.FullName)
                            $_.SetLName('Whale')
                        } else {
                            $_.SetGenerate($false)
                            $_.SetFullName('Could not be created')
                        }
                    }
                }
            },
            {})
        $this.CheckAllGenerateCommand = [Relay]::new($this, {
                $check = $this.IsGenerateChecked
                foreach ($item in $this.TestDataGrid) {
                    $item.SetGenerate($check)
                }
            },
            {})
        $this.CheckGenerateCommand = [Relay]::new($this, {
                $SetGenerateAtEnd = $true
                foreach ($item in $this.TestDataGrid) {
                    if ($item.Generate -eq $false) {
                        $SetGenerateAtEnd = $false
                        break
                    }
                }
                if ($this.IsGenerateChecked -ne $SetGenerateAtEnd) {
                    $this.SetIsGenerateChecked($SetGenerateAtEnd)
                }
            },
            {})
        $this.ResetGridCommand = [Relay]::new($this, {
                for ($i = $this.TestDataGrid.Count-1; $i -ge 0 ;$i--) {
                    Write-Debug "$i"
                    $this.TestDataGrid.RemoveAt($i)
                }
                $this.SetIsGenerateChecked($false)
            },
            {})
    }
}

function Show-MessageBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Title = "Warning",
        [string]$Button = "Ok",
        [string]$Icon = "Warning")
    [System.Windows.MessageBox]::Show("$Message", $Title, $Button, $Icon)
}


class UserFileChoiceModel : ComponentModel.INotifyPropertyChanged {
    hidden [ComponentModel.PropertyChangedEventHandler] $_propertyChanged = {}
    [void] add_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $p = $this._propertyChanged
        $this._propertyChanged = [Delegate]::Combine($p, $value)
    }
    [void] remove_PropertyChanged([ComponentModel.PropertyChangedEventHandler] $value) {
        $this._propertyChanged = [Delegate]::Remove($this._propertyChanged, $value)
    }
    [void]OnPropertyChanged([string] $propertyName) {
        Write-Host "Notified change of property '$propertyName'."
        $this._propertyChanged.Invoke($this, $propertyName)
    }
    [void] Init([string] $propertyName) {
        $setter = [ScriptBlock]::Create("
            param(`$value)
            `$this.'$PropertyName' = `$value
            `$this.OnPropertyChanged('$PropertyName')
        ")

        $getter = [ScriptBlock]::Create("`$this.'$propertyName'")

        $this | Add-Member -MemberType ScriptMethod -Name "Set$propertyName" -Value $setter
        $this | Add-Member -MemberType ScriptMethod -Name "Get$PropertyName" -Value $getter
    }
    [string]$Name
    [string]$LName
    [bool]$Generate
    [string]$FullName
    UserFileChoiceModel ($Name, $LName, $Generate, $FullName) {
        $this.Init('Name')
        $this.Init('LName')
        $this.Init('Generate')
        $this.Init('FullName')
        $this.SetName($Name)
        $this.SetLName($LName)
        $this.SetGenerate($Generate)
        $this.SetFullName($FullName)
    }
}


$Xaml = '<Window x:Class="WpfApp1.MainWindow"
x:Name="MainWindow"
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
xmlns:local="clr-namespace:WpfApp1"
mc:Ignorable="d"
Title="MainWindow" Height="450" Width="800">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="Gray" />
            <Setter Property="Foreground" Value="DarkGray"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="100"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="30"/>
            <RowDefinition Height="30"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBox x:Name="Title" Text="{Binding Title}" Height="100" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Grid.Row="0" Grid.Column="0" />
        <TextBlock x:Name="zItem1" Text="{Binding Item}" Grid.Row="1" Grid.Column="0" />
        <TextBlock x:Name="zItem2" Text="{Binding Item2}" Grid.Row="2" Grid.Column="0" />
        <Button x:Name="button1" Content="{Binding buttonContent}" Command="{Binding ShowCommand}" Grid.Row="3" Grid.Column="0" />
        <TextBox x:Name="Path" Text="{Binding UserPath}" Grid.Row="4" Grid.Column="0" />
        <Button x:Name="button2" Content="{Binding buttonContent2}" Command="{Binding GenerateGridCommand}" Grid.Row="5" Grid.Column="0" />

        <!-- https://stackoverflow.com/questions/60258979/checkbox-header-to-check-all-in-mvvm-datagrid
        IsChecked binding needs to be {Binding DataContext.ViewModelProperty} not {Binding ViewModelProperty}
        -->

        <DataGrid x:Name="DataGrid1" Grid.Row="6" Grid.Column="0" ItemsSource="{Binding TestDataGrid}" AutoGenerateColumns="false">
            <DataGrid.Columns>
                <DataGridTemplateColumn>
                    <DataGridTemplateColumn.Header>
                        <CheckBox IsChecked="{Binding DataContext.IsGenerateChecked, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged, RelativeSource={RelativeSource FindAncestor, AncestorType={x:Type Window}}}" Command="{Binding Path=DataContext.CheckAllGenerateCommand, RelativeSource={RelativeSource FindAncestor, AncestorType={x:Type Window}}}" />
                    </DataGridTemplateColumn.Header>
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <CheckBox IsChecked="{Binding Generate, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" Command="{Binding Path=DataContext.CheckGenerateCommand, RelativeSource={RelativeSource FindAncestor, AncestorType={x:Type Window}}}" />
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>

                <DataGridTextColumn Header="Name" MinWidth="50" Width="*" Binding="{Binding Name}" />
                <DataGridTextColumn Header="LName" MinWidth="10" Width="*" Binding="{Binding LName, UpdateSourceTrigger=PropertyChanged}" />
                <DataGridTextColumn Header="Path" MinWidth="10" Width="2*" Binding="{Binding FullName, UpdateSourceTrigger=PropertyChanged}" />
            </DataGrid.Columns>
        </DataGrid>
        <Button x:Name="button3" Content="{Binding buttonContent3}" Command="{Binding CreateFolderCommand}" Grid.Row="7" Grid.Column="0" />
        <Button x:Name="button4" Content="{Binding buttonContent4}" Command="{Binding ResetGridCommand}" Grid.Row="8" Grid.Column="0" />
    </Grid>
</Window>
'
#Define events functions
#region Load, Draw (render) and closing form events
#Things to load when the WPF form is loaded aka in memory
$wpf = New-WPFObject -Xaml $Xaml -ErrorAction Stop

$wpf.MainWindow.DataContext = [MainWindowVM]::new()

$wpf.button1.Add_Click({
        #$wpf.MainWindow.Close()
    });

$wpf.MainWindow.Add_Loaded({
        #Update-Cmd
    })
#Things to load when the WPF form is rendered aka drawn on screen
$wpf.MainWindow.Add_ContentRendered({
        #Update-Cmd
    })
$wpf.MainWindow.add_Closing({
        $msg = "bye bye !"
        write-host $msg
    })

#endregion Load, Draw and closing form events
#End of load, draw and closing form events

#HINT: to update progress bar and/or label during WPF Form treatment, add the following:
# ... to re-draw the form and then show updated controls in realtime ...
$wpf.MainWindow.Dispatcher.Invoke("Render", [action][scriptblock] {})


# Load the form:
# Older way >>>>> $wpf.MyFormName.ShowDialog() | Out-Null >>>>> generates crash if run multiple times
# Newer way >>>>> avoiding crashes after a couple of launches in PowerShell...
# USing method from https://gist.github.com/altrive/6227237 to avoid crashing Powershell after we re-run the script after some inactivity time or if we run it several times consecutively...
$async = $wpf.MainWindow.Dispatcher.InvokeAsync({
        $wpf.MainWindow.ShowDialog() | Out-Null
    })
$async.Wait() | Out-Null
