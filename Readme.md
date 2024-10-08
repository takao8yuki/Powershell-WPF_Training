# PowerShell WPF

### 課題:
1. PowerShell 5.1と.NET Frameworkを使用してGUIを作成すること。
2. `Add-Type`を通じてカスタムC#クラスを書かないこと。
3. Windows 10/11にネイティブに付属するリソースのみに制限すること。

### 結果:
**非同期**PowerShell UI！ ViewModelとCommandBindingsによってサポートされています。テスト不可能なスクリプトブロックにすべてを書く必要はもうありません。代わりに、ネイティブのPowerShellクラスメソッドを呼び出すだけです！

`SampleGUI.ps1` を右クリックしてPowerShellで実行するか、ドットソースするか、VSCodeでデバッガーを実行してサンプルを確認してください。

https://github.com/Exathi/Powershell-WPF/assets/87538502/c401887d-5f56-4dab-ab72-196e894e486b

## XAMLカスタム名前空間
XAMLに `xmlns:local="clr-namespace:;assembly=PowerShell Class Assembly"` を追加することで、ローカルのPowerShellクラスを使用できます。これにより、C#に近い機能が可能になります。以下は `XamlReader` によって解析されたときにPartialWindowクラスを作成します。

```xml
<local:PartialWindow
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:local="clr-namespace:;assembly=PowerShell Class Assembly">
    <StackPanel>
        <TextBlock Text="XAMLからのカスタムWPFオブジェクト！" />
    </StackPanel>
</local:PartialWindow>
```

```PowerShell
class PartialWindow : System.Windows.Window {
    PartialWindow() {
        Write-Verbose 'PartialWindowが作成されました！' -Verbose
    }
}
```

## PowerShellとタスク並列ライブラリ
スクリプトブロックを実行するランスペースがないため、`[System.Threading.Tasks.Task]::Run([action]$Scriptblock)` を呼び出すことはできません。しかし、`Factory.FromAsync()`を使用し、ContinueWithを連鎖させることができます。これにより、永続的なスリープループを持つランスペースを専用にすることなく、ランスペースを*自動的に*クリーンアップできます。

```PowerShell
class DelegateClass {
    DelegateClass() {}

    $MagicDelegate = $this.CreateDelegate($this.AutoMagicallyCallEndInvoke, $this)

    [Delegate]CreateDelegate([System.Management.Automation.PSMethod]$Method, $Target) {
        $ReflectionMethod = $Target.GetType().GetMethod($Method.Name)
        $ParameterTypes = [System.Linq.Enumerable]::Select($ReflectionMethod.GetParameters(), [func[object,object]]{$args[0].parametertype})
        $ConcatMethodTypes = $ParameterTypes + $ReflectionMethod.ReturnType
        $DelegateType = [System.Linq.Expressions.Expression]::GetDelegateType($ConcatMethodTypes)
        $Delegate = [delegate]::CreateDelegate($DelegateType, $Target, $ReflectionMethod.Name)
        return $Delegate
    }

    [object]AutoMagicallyCallEndInvoke([System.Threading.Tasks.Task]$Task, [object]$Powershell) {
        $Powershell.Dispose()
        return "$($Task.Result) ContinueWith"
    }
}

$Class = [DelegateClass]::new()
$Powershell = [powershell]::Create()

# PSMethodのEndInvokeをデリゲートに変換
$EndInvokeDelegate = $Class.CreateDelegate($Powershell.EndInvoke, $Powershell)

$Scriptblock = {'タスク結果！'}
$null = $Powershell.AddScript($Scriptblock)
$Handle = $Powershell.BeginInvoke()

$TaskFactory = [System.Threading.Tasks.TaskFactory]::new([System.Threading.Tasks.TaskScheduler]::Default)
$Task = $TaskFactory.FromAsync($Handle, $EndInvokeDelegate)
$ContinueWithTask = $Task.ContinueWith($Class.MagicDelegate, $Powershell)
$Task.Result
$ContinueWithTask.Result

```

BeginInvokeが終了する前に`$Task.Result`や`$Task`を呼び出すと、コンソール/スレッドが停止します。フリーズせずに`$Task.Status`や`$Task.IsCompleted`でステータスを確認できます。

`[System.Threading.Tasks.Task]::Run($Class.CreateDelegate(Class.Method))`を呼び出すことはできますが、現在のランスペースで実行されます。

## 並行性
Pwsh 7には`[NoRunspaceAffinity()]`属性がありますが、PowerShell 5.1にはありません。[こちら](https://github.com/PowerShell/PowerShell/issues/3651#issuecomment-306968528)の親切な方が方法を提供してくれています。ランスペースでクラスを定義し、すぐに`(Get-Runspace -Id x).Close()`を呼び出せば、同じ結果を得られるでしょう。

## ネイティブINotifyPropertyChanged実装を持つViewModel
PowerShellクラスは`INotifyPropertyChanged`を実装できます。PowerShellクラスにはゲッターとセッターがありませんが、PSCustomObjectを継承することでそれを模倣できます。これにより、メンバーは`$ViewModel.psobject.Property`の背後に隠れます。そして、コンストラクタで`Add-Member`を介して`$ViewModel.ScriptProperty`で表示されるプロパティのゲッターとセッターを設定できます。ボーナスとして、コンソールでは`$ViewModel.psobject.Property`を介してのみ表示されるプロパティでも、XAMLで`"{Binding Property}"`を使用できます。

```PowerShell
class ViewModelBase : PSCustomObject, System.ComponentModel.INotifyPropertyChanged {
    [ComponentModel.PropertyChangedEventHandler]$PropertyChanged

	add_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
            $this.psobject.PropertyChanged = [Delegate]::Combine($this.psobject.PropertyChanged, $handler)
	}

	remove_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
	    $this.psobject.PropertyChanged = [Delegate]::Remove($this.psobject.PropertyChanged, $handler)
	}

	RaisePropertyChanged([string]$propname) {
	    if ($this.psobject.PropertyChanged) {
            	$evargs = [System.ComponentModel.PropertyChangedEventArgs]::new($propname)
            	$this.psobject.PropertyChanged.Invoke($this, $evargs)
	    }
	}
}

class MyViewModel : ViewModelBase {
    $SharedResource
    MyViewModel() {
        $this | Add-Member -Name SharedResource -MemberType ScriptProperty -Value {
	    return $this.psobject.SharedResource
	} -SecondValue {
		param($value)
		$this.psobject.SharedResource = $value
		$this.psobject.RaisePropertyChanged('SharedResource')
            	Write-Verbose "SharedResourceが$valueに設定されました" -Verbose
	}
    }
}
```

## コマンド
最後に、コマンドバインディングについて。"コードビハインド"でハンドラーを設定できます。
```PowerShell
$Window.FindName('Button').add_Click({$Class.Method()})
```

しかし、WPFにここまで深く入り込んでいるので、独自のDelegateCommandクラスを実装することもできます。これは相互作用を処理し、メソッドを**非同期**で実行する責任も持つことができます。これにより、ViewModelのメソッドに対してのみテストを実行する必要があります。ViewModelは単に機能します。
```PowerShell
class DelegateCommand : ViewModelBase, System.Windows.Input.ICommand  {
    [System.EventHandler]$InternalCanExecuteChanged

    add_CanExecuteChanged([EventHandler]$value) {
        $this.psobject.InternalCanExecuteChanged = [Delegate]::Combine($this.psobject.InternalCanExecuteChanged, $value)
    }

    remove_CanExecuteChanged([EventHandler]$value) {
        $this.psobject.InternalCanExecuteChanged = [Delegate]::Remove($this.psobject.InternalCanExecuteChanged, $value)
    }

    [bool]CanExecute([object]$CommandParameter) {
        if ($this.psobject.CanExecuteAction) { return $this.psobject.CanExecuteAction.Invoke() }
        return $true
    }

    [void]Execute([object]$CommandParameter) {
        if ($this.psobject.Action) {
            $this.psobject.Action.Invoke()
        } else {
            $this.psobject.ActionObject.Invoke()
        }
    }

    DelegateCommand([Action]$Action) {
        $this.psobject.Action = $Action
    }

    DelegateCommand([Action[object]]$Action) {
        $this.psobject.ActionObject = $Action
    }

    [void]RaiseCanExecuteChanged() {
        $eCanExecuteChanged = $this.psobject.InternalCanExecuteChanged
        if ($eCanExecuteChanged) {
            if ($this.psobject.CanExecuteAction) {
                $eCanExecuteChanged.Invoke($this, [System.EventArgs]::Empty)
            }
        }
    }

    $Action
    $ActionObject
    $CanExecuteAction
}
```
### New-WPFObject
`[System.Windows.Markup.XamlReader]`のラッパーです。`[System.Windows.Markup.ParserContext]`を使用して、WPFオブジェクトが自身のXAML内で完全パスを提供せずにリソースディクショナリ.xamlファイルなどの他のファイルを指すためのURIを追加できます。これにより、XAML内で相対パスが可能になります。
```