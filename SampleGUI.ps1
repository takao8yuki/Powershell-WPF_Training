using Assembly PresentationFramework
using Assembly PresentationCore
using Assembly WindowsBase
using module .\WPFClassHelpers.psm1
Import-Module .\CreateClassInstanceHelper.psm1
. .\ViewModel.ps1

$ThreadManager = [ThreadManager]::new('Get-Million')
$MyViewModel = New-UnboundClassInstance MyViewModel
$MyViewModel.psobject.CreateButtons($ThreadManager)

# MyViewModel.Jobs�R���N�V�����̓�����L���ɂ��܂��B����ɂ��A�����̃X���b�h������S�ɃA�N�Z�X�ł���悤�ɂȂ�܂��B
[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($MyViewModel.psobject.Jobs, $MyViewModel.psobject.JobsLock)

# MainWindow.xaml���g�p����ꍇ�͂�����̃R�����g���������Ă�������
# $wpf = New-WPFObject -Path "$PSScriptRoot\Views\MainWindow.xaml" -BaseUri "$PSScriptRoot\"

# PartialWindow.xaml���g�p
$wpf = New-WPFObject -Path "$PSScriptRoot\Views\PartialWindow.xaml" -BaseUri "$PSScriptRoot\"
$wpf.DataContext = $MyViewModel

# �E�B���h�E��������Ƃ��̃C�x���g�n���h��
# $wpf.add_Closing({
#     param([System.ComponentModel.CancelEventHandler]$Handler)
#     $ThreadManager.Dispose()
# })

$wpf.ShowDialog()

# �W���u�̌��ʂ�\�`���ŕ\��
$MyViewModel.psobject.Jobs | Format-Table
