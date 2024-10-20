using Assembly PresentationFramework
using Assembly PresentationCore
using Assembly WindowsBase
using module .\WPFClassHelpers.psm1
Import-Module .\CreateClassInstanceHelper.psm1
. .\ViewModel.ps1

$ThreadManager = [ThreadManager]::new('Get-Million')
$MyViewModel = New-UnboundClassInstance MyViewModel
$MyViewModel.psobject.CreateButtons($ThreadManager)

# MyViewModel.Jobsコレクションの同期を有効にします。これにより、複数のスレッドから安全にアクセスできるようになります。
[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($MyViewModel.psobject.Jobs, $MyViewModel.psobject.JobsLock)

# MainWindow.xamlを使用する場合はこちらのコメントを解除してください
# $wpf = New-WPFObject -Path "$PSScriptRoot\Views\MainWindow.xaml" -BaseUri "$PSScriptRoot\"

# PartialWindow.xamlを使用
$wpf = New-WPFObject -Path "$PSScriptRoot\Views\PartialWindow.xaml" -BaseUri "$PSScriptRoot\"
$wpf.DataContext = $MyViewModel

# ウィンドウが閉じられるときのイベントハンドラ
# $wpf.add_Closing({
#     param([System.ComponentModel.CancelEventHandler]$Handler)
#     $ThreadManager.Dispose()
# })

$wpf.ShowDialog()

# ジョブの結果を表形式で表示
$MyViewModel.psobject.Jobs | Format-Table
