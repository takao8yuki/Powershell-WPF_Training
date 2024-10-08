Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop
function New-WPFObject {
    <#
        .SYNOPSIS
            文字列またはファイルから指定されたXamlを使用してWPFオブジェクトを作成します。
            xmlreaderではなく専用のWPF Xamlリーダーを使用します。
        .PARAMETER BaseUri
            xamlファイルのルートフォルダへのパス。フォルダを指す場合は必ずバックスラッシュ '\' で終了する必要があります。
            または、file.Xamlへのパス。
            未テストのアイデア - zipファイルを指す？
            xaml内で相対ソースを許可します。例えば、<ResourceDictionary Source="Common.Xaml" /> のようにCommon.Xamlを許可し、C:\folder\Common.Xamlのフルパスをハードコーディングする代わりに使用できます。
        .EXAMPLE
            -BaseUri "$PSScriptRoot\"
            -BaseUri "C:\Test\Folder\"
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        # 'HereString' と 'HereStringDynamic' のパラメータセットで使用されるパラメータ
        # パイプラインから直接XAMLの文字列を受け取ります
        # 関数に渡される最初の引数として位置0に配置
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'HereString')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'HereStringDynamic')]
        [string[]]$Xaml,

        # 'Path' と 'PathDynamic' のパラメータセットで使用されるパラメータ
        # ファイルのパスをパイプラインから受け取ります
        # 'FullName' というエイリアスを持ちます
        # パイプラインからプロパティ名で値を受け取ることができ、位置0に配置
        # 指定されたパスが存在するかを検証するスクリプトを使用
        [Alias('FullName')]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'Path')]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'PathDynamic')]
        [ValidateScript({ Test-Path $_ })]
        [string[]]$Path,

        # 'HereStringDynamic' と 'PathDynamic' のパラメータセットで使用されるパラメータ
        # XAMLフイルの基底URIを指定します
        [Parameter(Mandatory, ParameterSetName = 'HereStringDynamic')]
        [Parameter(Mandatory, ParameterSetName = 'PathDynamic')]
        [string]$BaseUri
    )

    begin {
        # WPFに必要なアセンブリを読み込みます
        # エラーが発生した場合は即座に停止します
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop

        # BaseUriが指定されている場合、そのパスが存在するかチェックします
        # 存在しない場合は、DirectoryNotFoundExceptionをスローします
        if (!(Test-Path $BaseUri)) {
            [System.IO.DirectoryNotFoundException]::new("$($BaseUri) は無効なパスです")
        }

        # BaseUriがバックスラッシュで終わっていない場合、末尾にバックスラッシュを追加します
        # これにより、相対パスの解決が正しく行われるようになります
        if (!$BaseUri.EndsWith('\')) { 
            $BaseUri = "$BaseUri\"
        }
    }

    process {
        # 現在使用中のパラメータセット名をデバッグ出力します
        Write-Debug $PSCmdlet.ParameterSetName

        # XAMLコンテンツを取得します
        # 'Path'パラメータが指定されている場合はファイルから読み込み、そうでない場合は直接$Xamlを使用します
        $RawXaml = if ($PSBoundParameters.ContainsKey('Path')) { 
            Get-Content -Path $Path 
        } else { 
            $Xaml 
        }

        # 'PathDynamic'または'HereStringDynamic'パラメータセットが使用されている場合
        if ($PSCmdlet.ParameterSetName -in @('PathDynamic', 'HereStringDynamic')) {
            # ParserContextを作成し、BaseUriを設定します
            # これにより、XAMLファイル内の相対パスを正しく解決できます
            $ParserContext = [System.Windows.Markup.ParserContext]::new()
            $ParserContext.BaseUri = [System.Uri]::new($BaseUri, [System.UriKind]::Absolute)

            # ParserContextを使用してXAMLを解析し、WPFオブジェクトを作成します
            [System.Windows.Markup.XamlReader]::Parse($RawXaml, $ParserContext)
        } else {
            # 通常のパラメータセットの場合、ParserContextなしでXAMLを解析します
            [System.Windows.Markup.XamlReader]::Parse($RawXaml)
        }
    }
}

function ConvertTo-Delegate {
    <#
    .SYNOPSIS
    PowerShellのメソッドオブジェクトを.NETのデリゲートに変換します。

    .DESCRIPTION
    この関数は、PowerShellのPSMethodオブジェクトを受け取り、それを.NETのデリゲートに変換します。
    これは、PowerShellのメソッドを.NETのイベントハンドラーやコールバックとして使用する際に特に有用です。

    .PARAMETER PSMethod
    変換したいPowerShellのメソッドオブジェクト。このパラメータはパイプラインからの入力を受け付けます。

    .PARAMETER Target
    デリゲートのターゲットとなるオブジェクト。このオブジェクトが、変換されるメソッドを持っています。

    .PARAMETER IsPSObject
    ターゲットオブジェクトがPSObject（PowerShellのカスタムオブジェクト）であることを示すスイッチパラメータ。

    .EXAMPLE
    $button.add_Click | ConvertTo-Delegate -Target $this
    この例では、ボタンのClickイベントハンドラーを現在のオブジェクト($this)のメソッドに変換しています。

    .EXAMPLE
    ConvertTo-Delegate -PSMethod $obj.SomeMethod -Target $obj -IsPSObject
    この例では、PSObjectの特定のメソッドをデリゲートに変換しています。

    .NOTES
    この関数は、WPFやその他の.NETベースのGUIフレームワークとPowerShellを統合する際に特に有用です。

    .LINK
    https://docs.microsoft.com/en-us/dotnet/api/system.delegate

    #>
    [CmdletBinding()]
    param (
        # PowerShellのメソッドオブジェクトを受け取ります
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [System.Management.Automation.PSMethod[]]$PSMethod,

        # デリゲートのターゲットとなるオブジェクトを指定します
        [Parameter(Mandatory)]
        [object]$Target,

        # ターゲットがPSObjectかどうかを示すスイッチパラメータ
        [switch]
        $IsPSObject
    )

    process {
        # ターゲットオブジェクトの種類に応じてリフレクションメソッドを取得
        if ($IsPSObject) {
            # PSObjectの場合、psobjectプロパティを経由してメソッドを取得
            $ReflectionMethod = $Target.psobject.GetType().GetMethod($PSMethod.Name)
        } else {
            # 通常のオブジェクトの場合、直接GetTypeからメソッドを取得
            $ReflectionMethod = $Target.GetType().GetMethod($PSMethod.Name)
        }

        # メソッドのパラメータタイプを取得
        $ParameterTypes = [System.Linq.Enumerable]::Select($ReflectionMethod.GetParameters(), [func[object,object]]{ $args[0].ParameterType })
        # パラメータタイプと戻り値の型を結合
        $ConcatMethodTypes = $ParameterTypes + $ReflectionMethod.ReturnType

        # メソッドが戻り値を持たない（void）かどうかを判定
        $IsAction = $ReflectionMethod.ReturnType -eq [void]
        if ($IsAction) {
            # voidの場合はActionデリゲートタイプを取得
            $DelegateType = [System.Linq.Expressions.Expression]::GetActionType($ParameterTypes)
        } else {
            # 戻り値がある場合はFuncデリゲートタイプを取得
            $DelegateType = [System.Linq.Expressions.Expression]::GetFuncType($ConcatMethodTypes)
        }

        # 最終的にデリゲートを作成して返す
        [delegate]::CreateDelegate($DelegateType, $Target, $ReflectionMethod.Name)
    }
}

<#
.SYNOPSIS
WPFアプリケーションのViewModelの基本クラスを提供します。

.DESCRIPTION
ViewModelBaseクラスは、WPFアプリケーションでMVVMパターンを実装する際の基礎となるクラスです。
このクラスはINotifyPropertyChangedインターフェースを実装しており、UIとのデータバインディングを容易にします。

.NOTES
このクラスを継承して、具体的なViewModelクラスを作成することができます。

.EXAMPLE
class MyViewModel : ViewModelBase {
    [string]$Name

    MyViewModel() {
        $this | Add-Member -Name Name -MemberType ScriptProperty -Value {
            return $this.psobject.Name
        } -SecondValue {
            param($value)
            $this.psobject.Name = $value
            $this.RaisePropertyChanged('Name')
        }
    }
}

$vm = [MyViewModel]::new()
$vm.Name = "John"  # これによりPropertyChangedイベントが発火します

.LINK
https://docs.microsoft.com/en-us/dotnet/api/system.componentmodel.inotifypropertychanged
#>

class ViewModelBase : PSCustomObject, System.ComponentModel.INotifyPropertyChanged {
    # INotifyPropertyChanged の実装
    # このイベントは、プロパティの値が変更されたときに通知を受けるために使用されます。
    [ComponentModel.PropertyChangedEventHandler]$PropertyChanged
    # 以下は、コメントアウトされた例です。必要に応じて使用してください。
    # [System.Collections.Generic.List[object]]$PropertyChanged = [System.Collections.Generic.List[object]]::new()

    # PropertyChanged イベントにハンドラーを追加するメソッド
    add_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
        # 既存のデリゲートに新しいハンドラーを結合します。
        $this.psobject.PropertyChanged = [Delegate]::Combine($this.psobject.PropertyChanged, $handler)
        # 以下は、別の方法でハンドラーを追加する例です。必要に応じて使用してください。
        # $this.psobject.PropertyChanged.Add($handler)
    }

    # PropertyChanged イベントからハンドラーを削除するメソッド
    remove_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
        # 既存のデリゲートから指定されたハンドラーを削除します。
        $this.psobject.PropertyChanged = [Delegate]::Remove($this.psobject.PropertyChanged, $handler)
        # 以下は、別の方法でハンドラーを削除する例です。必要に応じて使用してください。
        # $this.psobject.PropertyChanged.Remove($handler)
    }

    # 指定されたプロパティ名の変更を通知するメソッド
    RaisePropertyChanged([string]$propname) {
        # PropertyChanged イベントに登録されたハンドラーが存在する場合
        if ($this.psobject.PropertyChanged) {
            # プロパティ変更イベントの引数を作成します
            $evargs = [System.ComponentModel.PropertyChangedEventArgs]::new($propname)
            # すべての登録されたハンドラーを呼び出します
            $this.psobject.PropertyChanged.Invoke($this, $evargs) # 全てのメンバーを呼び出します
            # 以下は、デバッグ用の出力例です。必要に応じて有効にしてください。
            # Write-Verbose "RaisePropertyChanged $propname" -Verbose
        }
    }
    # INotifyPropertyChanged の実装終了
}

<#
.SYNOPSIS
WPFアプリケーションでボタンクリックなどのユーザーアクションを処理するためのクラスです。

.DESCRIPTION
ActionCommandクラスは、ボタンクリックなどのユーザーアクションを処理するために使用されます。
このクラスは、以下の主要な機能を提供します：
1. アクションの実行：ボタンがクリックされたときに特定の処理を実行します。
2. 実行可能状態の管理：ボタンを押せる状態かどうかを制御します。
3. 非同期処理：UIがフリーズしないように、長時間の処理を別スレッドで実行します。
4. スロットリング：同時に実行できる処理の数を制限します。

.NOTES
このクラスは、WPFアプリケーションのMVVM（Model-View-ViewModel）パターンで
よく使用されます。ViewModelの中でこのクラスのインスタンスを作成し、
XAMLのButtonのCommandプロパティにバインドして使用します。

.EXAMPLE
# ViewModelクラスでの使用例
class MyViewModel : ViewModelBase {
    MyViewModel() {
        $this | Add-Member -Name MyCommand -MemberType ScriptProperty -Value {
            if (-not $this.psobject.MyCommand) {
                $this.psobject.MyCommand = [ActionCommand]::new({ 
                    # ここにボタンクリック時の処理を書きます
                    Write-Host "ボタンがクリックされました" 
                })
            }
            return $this.psobject.MyCommand
        }
    }
}

# XAMLでの使用例:
# <Button Content="クリックしてね" Command="{Binding MyCommand}" />

.LINK
https://docs.microsoft.com/ja-jp/dotnet/desktop/wpf/data/how-to-implement-icommand?view=netframeworkdesktop-4.8
#>
class ActionCommand : ViewModelBase, System.Windows.Input.ICommand {
    # ICommandインターフェースの実装
    # このイベントは、コマンドの実行可能状態が変更されたときに発生します
    [System.EventHandler]$InternalCanExecuteChanged

    # CanExecuteChangedイベントにハンドラーを追加するメソッド
    add_CanExecuteChanged([EventHandler] $value) {
        $this.psobject.InternalCanExecuteChanged = [Delegate]::Combine($this.psobject.InternalCanExecuteChanged, $value)
    }

    # CanExecuteChangedイベントからハンドラーを削除するメソッド
    remove_CanExecuteChanged([EventHandler] $value) {
        $this.psobject.InternalCanExecuteChanged = [Delegate]::Remove($this.psobject.InternalCanExecuteChanged, $value)
    }

    # コマンドが実行可能かどうかを判断するメソッド
    [bool]CanExecute([object]$CommandParameter) {
        # スロットリングが設定されている場合、現在の実行数がスロットリング値未満なら実行可能
        if ($this.psobject.Throttle -gt 0) { return ($this.psobject.Workers -lt $this.psobject.Throttle) }
        # CanExecuteActionが設定されている場合はそれを呼び出す
        if ($this.psobject.CanExecuteAction) { return $this.psobject.CanExecuteAction.Invoke() }
        # それ以外の場合は常に実行可能
        return $true
    }

    # コマンドを実行するメソッド
    [void]Execute([object]$CommandParameter) {
        try {
            if ($this.psobject.Action) {
                if ($this.psobject.ThreadManager) {
                    # ThreadManagerが設定されている場合は非同期で実行
                    $null = $this.psobject.ThreadManager.Async($this.psobject.Action, $this.psobject.InvokeCanExecuteChangedDelegate)
                    $this.Workers++
                } else {
                    # ThreadManagerが設定されていない場合は同期的に実行
                    $this.psobject.Action.Invoke()
                }
            } else {
                # ActionObjectが設定されている場合の処理（現在は実装されていません）
                if ($this.psobject.ThreadManager) {
                    throw '実装されていません'
                    $this.Workers++
                } else {
                    $this.psobject.ActionObject.Invoke($CommandParameter)
                }
            }
        } catch {
            Write-Error "ActionCommand.Executeの処理中にエラーが発生しました: $_"
        }
    }

    # コンストラクタ（省略）

    # CanExecuteChangedイベントを発生させるメソッド
    [void]RaiseCanExecuteChanged() {
        $eCanExecuteChanged = $this.psobject.InternalCanExecuteChanged
        if ($eCanExecuteChanged) {
            if ($this.psobject.CanExecuteAction -or ($this.psobject.Throttle -gt 0)) {
                $eCanExecuteChanged.Invoke($this, [System.EventArgs]::Empty)
            }
        }
    }

    # 非同期処理完了後にWorkers数を減らし、CanExecuteChangedを呼び出すメソッド
    [void]InvokeCanExecuteChanged() {
        $ActionCommand = $this
        $this.psobject.Dispatcher.Invoke(9,[Action[object]]{
            param($ActionCommand)
            $ActionCommand.Workers--
        }, $ActionCommand)
    }

    # その他のプロパティとメソッド（省略）
}


<#
.SYNOPSIS
複数の非同期処理を管理するためのクラスです。

.DESCRIPTION
ThreadManagerクラスは、複数の非同期処理（バックグラウンドタスク）を
効率的に管理するために使用されます。このクラスの主な機能は：
1. 複数の非同期処理を同時に実行する
2. 処理の完了を待つ
3. 処理の結果を取得する
4. 使用していないリソースを適切に解放する

.NOTES
このクラスは、UIの応答性を維持しながら長時間の処理を行う必要がある
WPFアプリケーションで特に有用です。

.EXAMPLE
# ThreadManagerの作成
$threadManager = [ThreadManager]::new()

# 非同期処理の実行
$task = $threadManager.Async({ 
    # ここに長時間の処理を書きます
    Start-Sleep -Seconds 5
    return "処理が完了しました"
})

# 処理の完了を待ち、結果を取得
$result = $task.Result
Write-Host $result

# 使用終了後にリソースを解放
$threadManager.Dispose()

.LINK
https://docs.microsoft.com/ja-jp/dotnet/api/system.threading.tasks.task?view=net-5.0
#>
class ThreadManager : System.IDisposable {
    # IDisposableインターフェースの実装
    # リソースを解放するメソッド
    Dispose() {
        $this.RunspacePool.Dispose()
    }

    # 共有変数を格納するための辞書
    $SharedPoolVars = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
    
    # タスク完了時に呼び出されるデリゲート
    $DisposeTaskDelegate = $this.CreateDelegate($this.DisposeTask)

    # PowerShellインスタンスを実行するためのRunspacePool
    $RunspacePool

    # コンストラクタ（省略）

    # 非同期処理を開始するメソッド
    [object]Async([scriptblock]$scriptblock) {
        # PowerShellインスタンスの作成
        $Powershell = [powershell]::Create()
        $EndInvokeDelegate = $this.CreateDelegate($Powershell.EndInvoke, $Powershell)
        $Powershell.RunspacePool = $this.RunspacePool

        # スクリプトブロックの追加と実行開始
        $null = $Powershell.AddScript($scriptblock)
        $Handle = $Powershell.BeginInvoke()

        # タスクの作成
        $TaskFactory = [System.Threading.Tasks.TaskFactory]::new([System.Threading.Tasks.TaskScheduler]::Default)
        $Task = $TaskFactory.FromAsync($Handle, $EndInvokeDelegate)
        $null = $Task.ContinueWith($this.DisposeTaskDelegate, $Powershell)

        return $Task
    }

    # デリゲートを非同期で実行するメソッド（オーバーロード）
    [object]Async([Delegate]$MethodToRunAsync) {
        return $this.Async($MethodToRunAsync, $null)
    }

    # デリゲートとコールバックを非同期で実行するメソッド
    [object]Async([Delegate]$MethodToRunAsync, [Delegate]$Callback) {
        # PowerShellインスタンスの作成
        $Powershell = [powershell]::Create()
        $EndInvokeDelegate = $this.CreateDelegate($Powershell.EndInvoke, $Powershell)
        $Powershell.RunspacePool = $this.RunspacePool

        # 実行するアクションの定義
        if ($Callback) {
            $Action = {
                param($MethodToRunAsync, $Callback)
                $MethodToRunAsync.Invoke()
                $Callback.Invoke()
            }
        } else {
            $Action = {
                param($MethodToRunAsync)
                $MethodToRunAsync.Invoke()
            }
        }
        $NoContext = [scriptblock]::create($Action.ToString())

        # PowerShellインスタンスにスクリプトとパラメータを追加
        $null = $Powershell.AddScript($NoContext)
        $null = $Powershell.AddParameter('MethodToRunAsync', $MethodToRunAsync)
        if ($Callback) { $null = $Powershell.AddParameter('Callback', $Callback) }
        $Handle = $Powershell.BeginInvoke()

        # タスクの作成
        $TaskFactory = [System.Threading.Tasks.TaskFactory]::new([System.Threading.Tasks.TaskScheduler]::Default)
        $Task = $TaskFactory.FromAsync($Handle, $EndInvokeDelegate)
        $null = $Task.ContinueWith($this.DisposeTaskDelegate, $Powershell)

        return $Task
    }

    # タスク完了時にPowerShellインスタンスを破棄するメソッド
    DisposeTask([System.Threading.Tasks.Task]$Task, [object]$Powershell) {
        $Powershell.Dispose()
    }

    # その他のヘルパーメソッド（省略）
}