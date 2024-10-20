$Script:powershell = $null
$Script:body = @'
    function New-UnboundClassInstance ([Type] $type, [object[]] $arguments) {
        [activator]::CreateInstance($type, $arguments)
    }
'@

function Initialize {
    ## �����X�y�[�X���쐬����A���̒���PowerShell�N���X�͒�`����܂���
    $Script:powershell = [powershell]::Create()
    ## �^����ꂽ�^�ƈ������g�p���ăC���X�^���X���쐬����֐������̃����X�y�[�X�Œ�`���܂�
    $Script:powershell.AddScript($Script:body).Invoke()
    $Script:powershell.Commands.Clear()
}

<#
.SYNOPSIS
�w�肳�ꂽPowerShell�N���X�̐V�����C���X�^���X���A���݂̃����X�y�[�X�ɑ�������Ă��Ȃ���Ԃō쐬���܂��B

.DESCRIPTION
���̊֐��́A�w�肳�ꂽPowerShell�N���X�̐V�����C���X�^���X���쐬���܂��B�쐬���ꂽ�C���X�^���X��
���݂̃����X�y�[�X�ɑ�������Ă��Ȃ����߁A�����̃X���b�h������S�ɃA�N�Z�X�ł��܂��B
����͓��ɁA�񓯊���������񏈗����s���ۂɗL�p�ł��B

.PARAMETER type
�C���X�^���X���쐬����PowerShell�N���X�̌^�B

.PARAMETER arguments
�N���X�̃R���X�g���N�^�ɓn�������̔z��B�ȗ��\�ł��B

.EXAMPLE
$myInstance = New-UnboundClassInstance -type ([MyClass])
���̃R�}���h�́AMyClass�̐V�����C���X�^���X���쐬���A�����$myInstance�Ɋi�[���܂��B

.EXAMPLE
$myInstance = New-UnboundClassInstance -type ([MyClass]) -arguments @("arg1", 42)
���̃R�}���h�́AMyClass�̐V�����C���X�^���X���쐬���A�R���X�g���N�^��"arg1"��42�������Ƃ��ēn���܂��B

.NOTES
���̊֐��́APowerShell 5.1��[NoRunspaceAffinity()]�����̑�ւƂ��Ďg�p�ł��܂��B
PowerShell 7�ȍ~�ł́A�����[NoRunspaceAffinity()]�������g�p���邱�Ƃ������߂��܂��B

.LINK
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes

#>
function New-UnboundClassInstance ([Type] $type, [object[]] $arguments = $null)
{
    if ($null -eq $Script:powershell) { Initialize }

    try {
        ## PowerShell�N���X�̌^�ƃR���X�g���N�^�̈�����n���A���̃����X�y�[�X�Ńw���p�[�֐������s���܂�
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
