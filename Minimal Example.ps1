#Remember to dot source since powershell parses classes before add-types
Add-Type -AssemblyName presentationframework, presentationcore

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

    #parameter in viewmodel must use the variable name '$commandParameter' in order to take bound command parameters
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
        $this._propertyChanged = [Delegate]::Combine($this._propertyChanged, $value)
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
}
