using module .\WPFClassHelpers.psm1
using Assembly PresentationFramework
using Assembly PresentationCore
using Assembly WindowsBase

<#
.SYNOPSIS
WPFアプリケーションのデータと動作を管理するViewModelクラス

.DESCRIPTION
このMyViewModelクラスは、WPFアプリケーションのMVVM（Model-View-ViewModel）パターンにおける
ViewModelの役割を果たします。主な機能は以下の通りです：

1. UIに表示するデータの管理
2. ユーザーの操作（ボタンクリックなど）に対する処理の実行
3. 複数のスレッドを使用した非同期処理の管理
4. UIとのデータバインディング（表示の自動更新）の実現

.NOTES
このクラスを使用する際の注意点：
- PowerShell 5.1では、New-UnboundClassInstanceを使用してインスタンス化する必要があります。
  これは、複数のスレッドで同時に処理を行うために必要です。
- PowerShell 7以降では、代わりにNoRunspaceAffinity属性を使用できます。

.EXAMPLE
# ViewModelのインスタンス化（PowerShell 5.1の場合）
$viewModel = New-UnboundClassInstance -Type ([MyViewModel])

# ボタンの作成（スレッド管理オブジェクトを渡す）
$viewModel.CreateButtons($threadManager)

# プロパティの値を取得
$currentValue = $viewModel.SharedResource

.LINK
MVVM パターンについての詳細：
https://docs.microsoft.com/ja-jp/archive/msdn-magazine/2009/february/patterns-wpf-apps-with-the-model-view-viewmodel-design-pattern
#>
class MyViewModel : ViewModelBase {
    # UIスレッドで使用するオブジェクト
    # 共有リソース（複数のスレッドからアクセスされる値）
    # $Dispatcher# = [System.Windows.Threading.Dispatcher]::CurrentDispatcher # New-UnboundClassInstanceによって作成された場合、そのスレッドはランスペースがなくなったため停止します。
    $SharedResource = 0
    # 共有リソースへのアクセスを制御するためのロックオブジェクト
    hidden $SharedResourceLock = [object]::new()
    # 実行中のジョブ（処理）のリスト
    $Jobs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
    # ジョブリストへのアクセスを制御するためのロックオブジェクト
    hidden $JobsLock = [object]::new()

    # 計算サービス（時間のかかる処理をシミュレートするためのクラス）
    $CalculationService = [CalculationService]::new() # また、そのメソッドへの複数の呼び出しを可能にするために、バインドされていないクラスとして作成された。

    # ViewModelクラスのプロパティ定義

    # デリゲート：メソッドを表すオブジェクト
    # これらは、メソッドを変数として扱い、後で実行できるようにするために使用されます

    # AddTenSlowlyメソッドに対応するデリゲート
    # このデリゲートは、数値を10ずつゆっくりと増加させるメソッドを表します
    $AddTenSlowlyDelegate

    # ExternalMethodメソッドに対応するデリゲート
    # このデリゲートは、外部で定義されたメソッドを表します
    $ExternalMethodDelegate

    # CmdletInMethodメソッドに対応するデリゲート
    # このデリゲートは、PowerShellのCmdletを内部で使用するメソッドを表します
    $CmdletInMethodDelegate

    # コマンド：ユーザーインターフェイスのアクション（例：ボタンクリック）と関連付けるためのオブジェクト
    # これらは、WPFのICommandインターフェースを実装しており、UIとViewModelを結びつけます

    # AddTenSlowlyメソッドに対応するコマンド
    # このコマンドがトリガーされると、AddTenSlowlyメソッドが実行されます
    $AddTenSlowlyCommand

    # ExternalMethodメソッドに対応するコマンド
    # このコマンドがトリガーされると、ExternalMethodが実行されます
    $ExternalMethodCommand

    # CmdletInMethodメソッドに対応するコマンド
    # このコマンドがトリガーされると、CmdletInMethodが実行されます
    $CmdletInMethodCommand

    # コンストラクタ（クラスのインスタンスが作成されるときに呼び出されるメソッド）
    MyViewModel() {
        # SharedResourceプロパティの定義
        # このプロパティが変更されたときに、自動的にUIの表示を更新するための設定
        $this | Add-Member -Name SharedResource -MemberType ScriptProperty -Value {
			return $this.psobject.SharedResource
		} -SecondValue {
			param($value)
			$this.psobject.SharedResource = $value
			# プロパティが変更されたことをUIに通知
			$this.psobject.RaisePropertyChanged('SharedResource')
            Write-Verbose "SharedResourceが$valueに設定されました" -Verbose
		}
    }

    # ボタンを作成するメソッド
    CreateButtons([ThreadManager]$ThreadManager) {
        # ボタンは、別のランスペースからRaiseCanExecuteChangedを呼び出すためにディスパッチャーが必要です。
        # ボタンはNew-UnboundClassInstanceを使用してコンストラクタで作成することはできません。関連するスレッドがシャットダウンされ、ディスパッチャーが機能しないためです。
        # MyViewModelはボタンに依存していません。それはビューの問題です。そのメソッドはボタンなしで呼び出すことができます！
        # $this.psobject.Dispatcher = $Dispatcher

        # 各メソッドに対応するデリゲートとコマンドを作成
        $this.psobject.AddTenSlowlyDelegate = $this.psobject.CreateDelegate($this.psobject.AddTenSlowly)
        $this.psobject.AddTenSlowlyCommand = [ActionCommand]::new($this.psobject.AddTenSlowlyDelegate, $ThreadManager)
        # 同時に実行できる処理の数を3に制限
        $this.psobject.AddTenSlowlyCommand.psobject.Throttle = 3

        $this.psobject.ExternalMethodDelegate = $this.psobject.CreateDelegate($this.psobject.ExternalMethod)
        $this.psobject.ExternalMethodCommand = [ActionCommand]::new($this.psobject.ExternalMethodDelegate, $ThreadManager)
        $this.psobject.ExternalMethodCommand.psobject.Throttle = 6

        $this.psobject.CmdletInMethodDelegate = $this.psobject.CreateDelegate($this.psobject.Cmdlet)
        $this.psobject.CmdletInMethodCommand = [ActionCommand]::new($this.psobject.CmdletInMethodDelegate, $ThreadManager)
        $this.psobject.CmdletInMethodCommand.psobject.Throttle = 6
    }

    # pwsh 7+では不要
    [Delegate]CreateDelegate([System.Management.Automation.PSMethod]$Method) {
        $reflectionMethod = $this.psobject.GetType().GetMethod($Method.Name)
        $parameterTypes = [System.Linq.Enumerable]::Select($reflectionMethod.GetParameters(), [func[object,object]]{$args[0].parametertype})
        $concatMethodTypes = $parameterTypes + $reflectionMethod.ReturnType
        $delegateType = [System.Linq.Expressions.Expression]::GetDelegateType($concatMethodTypes)
        $delegate = [delegate]::CreateDelegate($delegateType, $this, $reflectionMethod.Name)
        return $delegate
    }

    AddTenSlowly() {
        $DataRow = [PSCustomObject]@{Id = [runspace]::DefaultRunspace.Id; Type = 'Start'; Time = Get-Date; Snapshot = $this.psobject.SharedResource; Method = 'AddTenSlowly'}
        $this.psobject.Jobs.Add($DataRow) # UIスレッドで以下を有効にすることで可能になります！: [System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($MyViewModel.psobject.Jobs, $MyViewModel.psobject.JobsLock)=

        [System.Threading.Monitor]::Enter($this.psobject.SharedResourceLock)
        try {
            Write-Verbose "ロックを取得しました $(Get-Date)" -Verbose
            # この時点で複数のスレッドをシミュレートします。10個すべてが追加されることを保証するためにロックが必要です。
            1..10 | ForEach-Object {
                $this.SharedResource++
                Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 400)
            }
        } catch {
            Write-Verbose "エラー: $($Error)" -Verbose
        } finally {
            [System.Threading.Monitor]::Exit($this.psobject.SharedResourceLock)
            Write-Verbose "ロックを解放しました $(Get-Date)" -Verbose
        }

        $DataRow = [PSCustomObject]@{Id = [runspace]::DefaultRunspace.Id; Type = 'End'; Time = Get-Date; Snapshot = $this.psobject.SharedResource; Method = 'AddTenSlowly'}
        $this.psobject.Jobs.Add($DataRow)
    }

    ExternalMethod() {
        $DataRow = [PSCustomObject]@{Id = [runspace]::DefaultRunspace.Id; Type = 'Start'; Time = Get-Date; Snapshot = $this.psobject.SharedResource; Method = 'ExternalMethod'}
        $this.psobject.Jobs.Add($DataRow)

        $NewNumber = $this.psobject.CalculationService.GetThousandDelegate.Invoke($this.SharedResource)

        [System.Threading.Monitor]::Enter($this.psobject.SharedResourceLock)
        try {
            Write-Verbose "ロックを取得しました $(Get-Date)" -Verbose
            $this.SharedResource += $NewNumber
        } catch {
            Write-Verbose "エラー: $($Error)" -Verbose
        } finally {
            [System.Threading.Monitor]::Exit($this.psobject.SharedResourceLock)
            Write-Verbose "ロックを解放しました $(Get-Date)" -Verbose
        }

        $DataRow = [PSCustomObject]@{Id = [runspace]::DefaultRunspace.Id; Type = 'End'; Time = Get-Date; Snapshot = $this.psobject.SharedResource; Method = 'ExternalMethod'}
        $this.psobject.Jobs.Add($DataRow)
    }

    Cmdlet() {
        $DataRow = [PSCustomObject]@{Id = [runspace]::DefaultRunspace.Id; Type = 'Start'; Time = Get-Date; Snapshot = $this.psobject.SharedResource; Method = 'Cmdlet'}
        $this.psobject.Jobs.Add($DataRow)

        $NewNumber = Get-Million -Seed $this.SharedResource

        [System.Threading.Monitor]::Enter($this.psobject.SharedResourceLock)
        try {
            Write-Verbose "ロックを取得しました $(Get-Date)" -Verbose
            $this.SharedResource += $NewNumber
        } catch {
            Write-Verbose "エラー: $($Error)" -Verbose
        } finally {
            [System.Threading.Monitor]::Exit($this.psobject.SharedResourceLock)
            Write-Verbose "ロックを解放しました $(Get-Date)" -Verbose
        }

        $DataRow = [PSCustomObject]@{Id = [runspace]::DefaultRunspace.Id; Type = 'End'; Time = Get-Date; Snapshot = $this.psobject.SharedResource; Method = 'Cmdlet'}
        $this.psobject.Jobs.Add($DataRow)
    }
}

<#
.SYNOPSIS
計算サービスを提供するクラス

.DESCRIPTION
このクラスは、時間のかかる計算処理をシミュレートします。
非同期処理のテストに使用されます。

.EXAMPLE
$calculationService = [CalculationService]::new()
$result = $calculationService.GetThousandDelegate.Invoke(10)

.NOTES
このクラスもアンバウンドクラスとして使用することを想定しています。
#>
class CalculationService {
    $GetThousandDelegate = $this.CreateDelegate($this.GetThousand)
    CalculationService() {}

    [int]GetThousand($Seed) {
        # クラスがアンバウンドでない場合、非同期ボタンで呼び出された場合にパイプラインの使用は不可能です
        # UIスレッドでキューに入れられ、非同期で呼び出されます
        # アンバウンドでない場合はデリゲートを呼び出す必要があります

        # 1..10 | ForEach-Object {
        #     Start-Sleep -Milliseconds (Get-Random -SetSeed $Seed -Minimum 50 -Maximum 400)
        # }
        foreach ($i in 1..10) {
            Start-Sleep -Milliseconds (Get-Random -SetSeed $Seed -Minimum 50 -Maximum 400)
        }

        # return (Get-Random -SetSeed $Seed) * (Get-Random -InputObject (-1, 1))
        return 1000
    }

    [Delegate]CreateDelegate([System.Management.Automation.PSMethod]$Method) {
        $reflectionMethod = $this.GetType().GetMethod($Method.Name)
        $parameterTypes = [System.Linq.Enumerable]::Select($reflectionMethod.GetParameters(), [func[object,object]]{$args[0].parametertype})
        $concatMethodTypes = $parameterTypes + $reflectionMethod.ReturnType
        $delegateType = [System.Linq.Expressions.Expression]::GetDelegateType($concatMethodTypes)
        $delegate = [delegate]::CreateDelegate($delegateType, $this, $reflectionMethod.Name)
        return $delegate
    }
}

<#
.SYNOPSIS
100万を返す関数

.DESCRIPTION
この関数は、指定されたシード値を使用してランダムな遅延を発生させた後、
100万を返します。非同期処理のテストに使用されます。

.PARAMETER Seed
ランダムな遅延を生成するためのシード値

.EXAMPLE
$result = Get-Million -Seed 42

.NOTES
この関数は、非同期処理のシミュレーションに使用されます。
#>
function Get-Million {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$Seed
    )

    process {
        foreach ($i in 1..10) {
            Start-Sleep -Milliseconds (Get-Random -SetSeed $Seed -Minimum 50 -Maximum 400)
        }
        return 1000000
    }
}

<#
.SYNOPSIS
WPFで右マージンを動的に設定するための値コンバーター

.DESCRIPTION
このRightMarginConverterクラスは、WPF（Windows Presentation Foundation）アプリケーションで
使用される特殊なクラスです。主な役割は、数値を受け取り、その値を使って
UIエレメントの右側のマージン（余白）を設定することです。

このクラスの主な特徴：
1. System.Windows.Data.IValueConverterインターフェースを実装しています。
   これは、WPFのデータバインディングシステムがこのクラスを使用できるようにするためです。
2. 数値を受け取り、それをSystem.Windows.Thicknessオブジェクトに変換します。
   Thicknessは、WPFでUIエレメントの余白を表すために使用されるオブジェクトです。
3. 入力が正の数値の場合、その値を右マージンとして設定します。
4. それ以外の場合は、すべてのマージンを0に設定します。

.EXAMPLE
# XAMLでの使用例：
<TextBlock Text="サンプルテキスト">
    <TextBlock.Margin>
        <Binding Path="SomeValue" Converter="{StaticResource RightMarginConverter}"/>
    </TextBlock.Margin>
</TextBlock>

# この例では、'SomeValue'というプロパティの値が、
# RightMarginConverterを通じてTextBlockの右マージンに設定されます。

.NOTES
このクラスを使用するには、まずXAMLでリソースとして定義する必要があります。
例：
<Window.Resources>
    <local:RightMarginConverter x:Key="RightMarginConverter"/>
</Window.Resources>

その後、上記の.EXAMPLEセクションのように、Bindingで使用できます。
#>
class RightMarginConverter : System.Windows.Data.IValueConverter {
    # コンストラクタ：このクラスのインスタンスが作成されるときに呼び出されるメソッド
    # 今回は特に何も行わないので空のままです
    RightMarginConverter() {}

    # Convert メソッド：値を変換するための主要なメソッド
    # WPFのバインディングシステムがソース（例：ViewModel）からターゲット（例：UI要素）に
    # 値を渡す際に、この方法が呼び出されます
    [object]Convert([object]$value, [Type]$targetType, [object]$parameter, [CultureInfo]$culture) {
        # 入力値が数値（double型）で、かつ0より大きい場合
        if ($value -is [double] -and $value -gt 0) {
            # 入力値をログに出力（デバッグ用）
            Write-Verbose $value -Verbose
            # 新しいThicknessオブジェクトを作成
            # 引数は (左, 上, 右, 下) のマージンを表します
            # ここでは右マージンのみに入力値を設定し、他は0にしています
            return [System.Windows.Thickness]::new(0, 0, $value, 0)
        }
        # 入力値が数値でないか、0以下の場合
        Write-Verbose 'デフォルト 0,0,0,0 を返します' -Verbose
        # すべてのマージンを0に設定したThicknessオブジェクトを返します
        return [System.Windows.Thickness]::new(0, 0, 0, 0)
    }

    # ConvertBack メソッド：逆方向の変換を行うためのメソッド
    # 通常、UIからViewModelに値を戻す際に使用されますが、
    # この場合は実装されていないので例外をスローします
    [object]ConvertBack([object]$value, [Type]$targetType, [object]$parameter, [CultureInfo] $culture) {
        throw '逆方向の変換（UIからViewModelへ）は実装されていません'
    }
}

<#
.SYNOPSIS
カスタム機能を持つWPFウィンドウクラス

.DESCRIPTION
このPartialWindowクラスは、標準のWPFウィンドウ（System.Windows.Window）を拡張し、
ウィンドウの基本的な操作（最小化、最大化、閉じるなど）をカスタマイズします。
これにより、独自のデザインや動作を持つウィンドウを作成することができます。

主な特徴：
1. システムメニューの表示
2. ウィンドウの最小化
3. ウィンドウの最大化
4. ウィンドウの元のサイズへの復元
5. ウィンドウを閉じる

これらの操作は、通常のウィンドウの標準的な動作をエミュレートしていますが、
カスタムデザインのウィンドウでも正しく機能するように実装されています。

.EXAMPLE
# PartialWindowクラスのインスタンスを作成
$window = [PartialWindow]::new()

# ウィンドウを表示
$window.Show()

.NOTES
このクラスは、通常、カスタムデザインのXAMLテンプレートと組み合わせて使用します。
テンプレートでは、これらのコマンドを呼び出すボタンやその他のコントロールを定義します。
#>
class PartialWindow : System.Windows.Window {
    # コンストラクタ：クラスのインスタンスが作成されるときに呼び出されるメソッド
    PartialWindow() {
        # システムメニューを表示するコマンドのバインディングを追加
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            # システムメニューを表示するコマンド
            [System.Windows.SystemCommands]::ShowSystemMenuCommand, 
            # コマンドが実行されたときの処理
            {
                param($CommandParameter)
                # マウスの現在位置を取得し、スクリーン座標に変換
                $Point = $CommandParameter.PointToScreen([System.Windows.Input.Mouse]::GetPosition($CommandParameter))
                # システムメニューを表示
                [System.Windows.SystemCommands]::ShowSystemMenu($CommandParameter,$Point)
            }
        ))

        # ウィンドウを最小化するコマンドのバインディングを追加
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            [System.Windows.SystemCommands]::MinimizeWindowCommand, 
            {
                param($CommandParameter)
                [System.Windows.SystemCommands]::MinimizeWindow($CommandParameter)
            }
        ))

        # ウィンドウを最大化するコマンドのバインディングを追加
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            [System.Windows.SystemCommands]::MaximizeWindowCommand, 
            {
                param($CommandParameter)
                [System.Windows.SystemCommands]::MaximizeWindow($CommandParameter)
            }
        ))

        # ウィンドウを元のサイズに戻すコマンドのバインディングを追加
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            [System.Windows.SystemCommands]::RestoreWindowCommand, 
            {
                param($CommandParameter)
                [System.Windows.SystemCommands]::RestoreWindow($CommandParameter)
            }
        ))

        # ウィンドウを閉じるコマンドのバインディングを追加
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            [System.Windows.SystemCommands]::CloseWindowCommand, 
            {
                param($CommandParameter)
                [System.Windows.SystemCommands]::CloseWindow($CommandParameter)
            }
        ))

        # カスタムウィンドウテンプレートの適用（現在はコメントアウトされています）
        # $this.Template = New-WPFObject -Path "$PSScriptRoot\Views\PartialWindowTemplate.xaml" -BaseUri "$PSScriptRoot" -LocalNamespaceName 'local'
    }
}