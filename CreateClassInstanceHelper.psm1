$Script:powershell = $null
$Script:body = @'
    function New-UnboundClassInstance ([Type] $type, [object[]] $arguments) {
        [activator]::CreateInstance($type, $arguments)
    }
'@

function Initialize {
    ## ランスペースが作成され、その中にPowerShellクラスは定義されません
    $Script:powershell = [powershell]::Create()
    ## 与えられた型と引数を使用してインスタンスを作成する関数をそのランスペースで定義します
    $Script:powershell.AddScript($Script:body).Invoke()
    $Script:powershell.Commands.Clear()
}

<#
.SYNOPSIS
指定されたPowerShellクラスの新しいインスタンスを、現在のランスペースに束縛されていない状態で作成します。

.DESCRIPTION
この関数は、指定されたPowerShellクラスの新しいインスタンスを作成します。作成されたインスタンスは
現在のランスペースに束縛されていないため、複数のスレッドから安全にアクセスできます。
これは特に、非同期処理や並列処理を行う際に有用です。

.PARAMETER type
インスタンスを作成するPowerShellクラスの型。

.PARAMETER arguments
クラスのコンストラクタに渡す引数の配列。省略可能です。

.EXAMPLE
$myInstance = New-UnboundClassInstance -type ([MyClass])
このコマンドは、MyClassの新しいインスタンスを作成し、それを$myInstanceに格納します。

.EXAMPLE
$myInstance = New-UnboundClassInstance -type ([MyClass]) -arguments @("arg1", 42)
このコマンドは、MyClassの新しいインスタンスを作成し、コンストラクタに"arg1"と42を引数として渡します。

.NOTES
この関数は、PowerShell 5.1で[NoRunspaceAffinity()]属性の代替として使用できます。
PowerShell 7以降では、代わりに[NoRunspaceAffinity()]属性を使用することをお勧めします。

.LINK
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes

#>
function New-UnboundClassInstance ([Type] $type, [object[]] $arguments = $null)
{
    if ($null -eq $Script:powershell) { Initialize }

    try {
        ## PowerShellクラスの型とコンストラクタの引数を渡し、他のランスペースでヘルパー関数を実行します
        if ($null -eq $arguments) { $arguments = @() }
        $result = $Script:powershell.AddCommand("New-UnboundClassInstance").
                                     AddParameter("type", $type).
                                     AddParameter("arguments", $arguments).
                                     Invoke()
        return $result
    } finally {
        $Script:powershell.Commands.Clear()
    }
}
