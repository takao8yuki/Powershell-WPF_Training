using module .\WPFClassHelpers.psm1
using Assembly PresentationFramework
using Assembly PresentationCore
using Assembly WindowsBase

<#
.SYNOPSIS
WPF�A�v���P�[�V�����̃f�[�^�Ɠ�����Ǘ�����ViewModel�N���X

.DESCRIPTION
����MyViewModel�N���X�́AWPF�A�v���P�[�V������MVVM�iModel-View-ViewModel�j�p�^�[���ɂ�����
ViewModel�̖������ʂ����܂��B��ȋ@�\�͈ȉ��̒ʂ�ł��F

1. UI�ɕ\������f�[�^�̊Ǘ�
2. ���[�U�[�̑���i�{�^���N���b�N�Ȃǁj�ɑ΂��鏈���̎��s
3. �����̃X���b�h���g�p�����񓯊������̊Ǘ�
4. UI�Ƃ̃f�[�^�o�C���f�B���O�i�\���̎����X�V�j�̎���

.NOTES
���̃N���X���g�p����ۂ̒��ӓ_�F
- PowerShell 5.1�ł́ANew-UnboundClassInstance���g�p���ăC���X�^���X������K�v������܂��B
  ����́A�����̃X���b�h�œ����ɏ������s�����߂ɕK�v�ł��B
- PowerShell 7�ȍ~�ł́A�����NoRunspaceAffinity�������g�p�ł��܂��B

.EXAMPLE
# ViewModel�̃C���X�^���X���iPowerShell 5.1�̏ꍇ�j
$viewModel = New-UnboundClassInstance -Type ([MyViewModel])

# �{�^���̍쐬�i�X���b�h�Ǘ��I�u�W�F�N�g��n���j
$viewModel.CreateButtons($threadManager)

# �v���p�e�B�̒l���擾
$currentValue = $viewModel.SharedResource

.LINK
MVVM �p�^�[���ɂ��Ă̏ڍׁF
https://docs.microsoft.com/ja-jp/archive/msdn-magazine/2009/february/patterns-wpf-apps-with-the-model-view-viewmodel-design-pattern
#>
class MyViewModel : ViewModelBase {
    # UI�X���b�h�Ŏg�p����I�u�W�F�N�g
    # ���L���\�[�X�i�����̃X���b�h����A�N�Z�X�����l�j
    # $Dispatcher# = [System.Windows.Threading.Dispatcher]::CurrentDispatcher # New-UnboundClassInstance�ɂ���č쐬���ꂽ�ꍇ�A���̃X���b�h�̓����X�y�[�X���Ȃ��Ȃ������ߒ�~���܂��B
    $SharedResource = 0
    # ���L���\�[�X�ւ̃A�N�Z�X�𐧌䂷�邽�߂̃��b�N�I�u�W�F�N�g
    hidden $SharedResourceLock = [object]::new()
    # ���s���̃W���u�i�����j�̃��X�g
    $Jobs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
    # �W���u���X�g�ւ̃A�N�Z�X�𐧌䂷�邽�߂̃��b�N�I�u�W�F�N�g
    hidden $JobsLock = [object]::new()

    # �v�Z�T�[�r�X�i���Ԃ̂����鏈�����V�~�����[�g���邽�߂̃N���X�j
    $CalculationService = [CalculationService]::new() # �܂��A���̃��\�b�h�ւ̕����̌Ăяo�����\�ɂ��邽�߂ɁA�o�C���h����Ă��Ȃ��N���X�Ƃ��č쐬���ꂽ�B

    # ViewModel�N���X�̃v���p�e�B��`

    # �f���Q�[�g�F���\�b�h��\���I�u�W�F�N�g
    # �����́A���\�b�h��ϐ��Ƃ��Ĉ����A��Ŏ��s�ł���悤�ɂ��邽�߂Ɏg�p����܂�

    # AddTenSlowly���\�b�h�ɑΉ�����f���Q�[�g
    # ���̃f���Q�[�g�́A���l��10���������Ƒ��������郁�\�b�h��\���܂�
    $AddTenSlowlyDelegate

    # ExternalMethod���\�b�h�ɑΉ�����f���Q�[�g
    # ���̃f���Q�[�g�́A�O���Œ�`���ꂽ���\�b�h��\���܂�
    $ExternalMethodDelegate

    # CmdletInMethod���\�b�h�ɑΉ�����f���Q�[�g
    # ���̃f���Q�[�g�́APowerShell��Cmdlet������Ŏg�p���郁�\�b�h��\���܂�
    $CmdletInMethodDelegate

    # �R�}���h�F���[�U�[�C���^�[�t�F�C�X�̃A�N�V�����i��F�{�^���N���b�N�j�Ɗ֘A�t���邽�߂̃I�u�W�F�N�g
    # �����́AWPF��ICommand�C���^�[�t�F�[�X���������Ă���AUI��ViewModel�����т��܂�

    # AddTenSlowly���\�b�h�ɑΉ�����R�}���h
    # ���̃R�}���h���g���K�[�����ƁAAddTenSlowly���\�b�h�����s����܂�
    $AddTenSlowlyCommand

    # ExternalMethod���\�b�h�ɑΉ�����R�}���h
    # ���̃R�}���h���g���K�[�����ƁAExternalMethod�����s����܂�
    $ExternalMethodCommand

    # CmdletInMethod���\�b�h�ɑΉ�����R�}���h
    # ���̃R�}���h���g���K�[�����ƁACmdletInMethod�����s����܂�
    $CmdletInMethodCommand

    # �R���X�g���N�^�i�N���X�̃C���X�^���X���쐬�����Ƃ��ɌĂяo����郁�\�b�h�j
    MyViewModel() {
        # SharedResource�v���p�e�B�̒�`
        # ���̃v���p�e�B���ύX���ꂽ�Ƃ��ɁA�����I��UI�̕\�����X�V���邽�߂̐ݒ�
        $this | Add-Member -Name SharedResource -MemberType ScriptProperty -Value {
			return $this.psobject.SharedResource
		} -SecondValue {
			param($value)
			$this.psobject.SharedResource = $value
			# �v���p�e�B���ύX���ꂽ���Ƃ�UI�ɒʒm
			$this.psobject.RaisePropertyChanged('SharedResource')
            Write-Verbose "SharedResource��$value�ɐݒ肳��܂���" -Verbose
		}
    }

    # �{�^�����쐬���郁�\�b�h
    CreateButtons([ThreadManager]$ThreadManager) {
        # �{�^���́A�ʂ̃����X�y�[�X����RaiseCanExecuteChanged���Ăяo�����߂Ƀf�B�X�p�b�`���[���K�v�ł��B
        # �{�^����New-UnboundClassInstance���g�p���ăR���X�g���N�^�ō쐬���邱�Ƃ͂ł��܂���B�֘A����X���b�h���V���b�g�_�E������A�f�B�X�p�b�`���[���@�\���Ȃ����߂ł��B
        # MyViewModel�̓{�^���Ɉˑ����Ă��܂���B����̓r���[�̖��ł��B���̃��\�b�h�̓{�^���Ȃ��ŌĂяo�����Ƃ��ł��܂��I
        # $this.psobject.Dispatcher = $Dispatcher

        # �e���\�b�h�ɑΉ�����f���Q�[�g�ƃR�}���h���쐬
        $this.psobject.AddTenSlowlyDelegate = $this.psobject.CreateDelegate($this.psobject.AddTenSlowly)
        $this.psobject.AddTenSlowlyCommand = [ActionCommand]::new($this.psobject.AddTenSlowlyDelegate, $ThreadManager)
        # �����Ɏ��s�ł��鏈���̐���3�ɐ���
        $this.psobject.AddTenSlowlyCommand.psobject.Throttle = 3

        $this.psobject.ExternalMethodDelegate = $this.psobject.CreateDelegate($this.psobject.ExternalMethod)
        $this.psobject.ExternalMethodCommand = [ActionCommand]::new($this.psobject.ExternalMethodDelegate, $ThreadManager)
        $this.psobject.ExternalMethodCommand.psobject.Throttle = 6

        $this.psobject.CmdletInMethodDelegate = $this.psobject.CreateDelegate($this.psobject.Cmdlet)
        $this.psobject.CmdletInMethodCommand = [ActionCommand]::new($this.psobject.CmdletInMethodDelegate, $ThreadManager)
        $this.psobject.CmdletInMethodCommand.psobject.Throttle = 6
    }

    # pwsh 7+�ł͕s�v
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
        $this.psobject.Jobs.Add($DataRow) # UI�X���b�h�ňȉ���L���ɂ��邱�Ƃŉ\�ɂȂ�܂��I: [System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($MyViewModel.psobject.Jobs, $MyViewModel.psobject.JobsLock)=

        [System.Threading.Monitor]::Enter($this.psobject.SharedResourceLock)
        try {
            Write-Verbose "���b�N���擾���܂��� $(Get-Date)" -Verbose
            # ���̎��_�ŕ����̃X���b�h���V�~�����[�g���܂��B10���ׂĂ��ǉ�����邱�Ƃ�ۏ؂��邽�߂Ƀ��b�N���K�v�ł��B
            1..10 | ForEach-Object {
                $this.SharedResource++
                Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 400)
            }
        } catch {
            Write-Verbose "�G���[: $($Error)" -Verbose
        } finally {
            [System.Threading.Monitor]::Exit($this.psobject.SharedResourceLock)
            Write-Verbose "���b�N��������܂��� $(Get-Date)" -Verbose
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
            Write-Verbose "���b�N���擾���܂��� $(Get-Date)" -Verbose
            $this.SharedResource += $NewNumber
        } catch {
            Write-Verbose "�G���[: $($Error)" -Verbose
        } finally {
            [System.Threading.Monitor]::Exit($this.psobject.SharedResourceLock)
            Write-Verbose "���b�N��������܂��� $(Get-Date)" -Verbose
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
            Write-Verbose "���b�N���擾���܂��� $(Get-Date)" -Verbose
            $this.SharedResource += $NewNumber
        } catch {
            Write-Verbose "�G���[: $($Error)" -Verbose
        } finally {
            [System.Threading.Monitor]::Exit($this.psobject.SharedResourceLock)
            Write-Verbose "���b�N��������܂��� $(Get-Date)" -Verbose
        }

        $DataRow = [PSCustomObject]@{Id = [runspace]::DefaultRunspace.Id; Type = 'End'; Time = Get-Date; Snapshot = $this.psobject.SharedResource; Method = 'Cmdlet'}
        $this.psobject.Jobs.Add($DataRow)
    }
}

<#
.SYNOPSIS
�v�Z�T�[�r�X��񋟂���N���X

.DESCRIPTION
���̃N���X�́A���Ԃ̂�����v�Z�������V�~�����[�g���܂��B
�񓯊������̃e�X�g�Ɏg�p����܂��B

.EXAMPLE
$calculationService = [CalculationService]::new()
$result = $calculationService.GetThousandDelegate.Invoke(10)

.NOTES
���̃N���X���A���o�E���h�N���X�Ƃ��Ďg�p���邱�Ƃ�z�肵�Ă��܂��B
#>
class CalculationService {
    $GetThousandDelegate = $this.CreateDelegate($this.GetThousand)
    CalculationService() {}

    [int]GetThousand($Seed) {
        # �N���X���A���o�E���h�łȂ��ꍇ�A�񓯊��{�^���ŌĂяo���ꂽ�ꍇ�Ƀp�C�v���C���̎g�p�͕s�\�ł�
        # UI�X���b�h�ŃL���[�ɓ�����A�񓯊��ŌĂяo����܂�
        # �A���o�E���h�łȂ��ꍇ�̓f���Q�[�g���Ăяo���K�v������܂�

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
100����Ԃ��֐�

.DESCRIPTION
���̊֐��́A�w�肳�ꂽ�V�[�h�l���g�p���ă����_���Ȓx���𔭐���������A
100����Ԃ��܂��B�񓯊������̃e�X�g�Ɏg�p����܂��B

.PARAMETER Seed
�����_���Ȓx���𐶐����邽�߂̃V�[�h�l

.EXAMPLE
$result = Get-Million -Seed 42

.NOTES
���̊֐��́A�񓯊������̃V�~�����[�V�����Ɏg�p����܂��B
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
WPF�ŉE�}�[�W���𓮓I�ɐݒ肷�邽�߂̒l�R���o�[�^�[

.DESCRIPTION
����RightMarginConverter�N���X�́AWPF�iWindows Presentation Foundation�j�A�v���P�[�V������
�g�p��������ȃN���X�ł��B��Ȗ����́A���l���󂯎��A���̒l���g����
UI�G�������g�̉E���̃}�[�W���i�]���j��ݒ肷�邱�Ƃł��B

���̃N���X�̎�ȓ����F
1. System.Windows.Data.IValueConverter�C���^�[�t�F�[�X���������Ă��܂��B
   ����́AWPF�̃f�[�^�o�C���f�B���O�V�X�e�������̃N���X���g�p�ł���悤�ɂ��邽�߂ł��B
2. ���l���󂯎��A�����System.Windows.Thickness�I�u�W�F�N�g�ɕϊ����܂��B
   Thickness�́AWPF��UI�G�������g�̗]����\�����߂Ɏg�p�����I�u�W�F�N�g�ł��B
3. ���͂����̐��l�̏ꍇ�A���̒l���E�}�[�W���Ƃ��Đݒ肵�܂��B
4. ����ȊO�̏ꍇ�́A���ׂẴ}�[�W����0�ɐݒ肵�܂��B

.EXAMPLE
# XAML�ł̎g�p��F
<TextBlock Text="�T���v���e�L�X�g">
    <TextBlock.Margin>
        <Binding Path="SomeValue" Converter="{StaticResource RightMarginConverter}"/>
    </TextBlock.Margin>
</TextBlock>

# ���̗�ł́A'SomeValue'�Ƃ����v���p�e�B�̒l���A
# RightMarginConverter��ʂ���TextBlock�̉E�}�[�W���ɐݒ肳��܂��B

.NOTES
���̃N���X���g�p����ɂ́A�܂�XAML�Ń��\�[�X�Ƃ��Ē�`����K�v������܂��B
��F
<Window.Resources>
    <local:RightMarginConverter x:Key="RightMarginConverter"/>
</Window.Resources>

���̌�A��L��.EXAMPLE�Z�N�V�����̂悤�ɁABinding�Ŏg�p�ł��܂��B
#>
class RightMarginConverter : System.Windows.Data.IValueConverter {
    # �R���X�g���N�^�F���̃N���X�̃C���X�^���X���쐬�����Ƃ��ɌĂяo����郁�\�b�h
    # ����͓��ɉ����s��Ȃ��̂ŋ�̂܂܂ł�
    RightMarginConverter() {}

    # Convert ���\�b�h�F�l��ϊ����邽�߂̎�v�ȃ��\�b�h
    # WPF�̃o�C���f�B���O�V�X�e�����\�[�X�i��FViewModel�j����^�[�Q�b�g�i��FUI�v�f�j��
    # �l��n���ۂɁA���̕��@���Ăяo����܂�
    [object]Convert([object]$value, [Type]$targetType, [object]$parameter, [CultureInfo]$culture) {
        # ���͒l�����l�idouble�^�j�ŁA����0���傫���ꍇ
        if ($value -is [double] -and $value -gt 0) {
            # ���͒l�����O�ɏo�́i�f�o�b�O�p�j
            Write-Verbose $value -Verbose
            # �V����Thickness�I�u�W�F�N�g���쐬
            # ������ (��, ��, �E, ��) �̃}�[�W����\���܂�
            # �����ł͉E�}�[�W���݂̂ɓ��͒l��ݒ肵�A����0�ɂ��Ă��܂�
            return [System.Windows.Thickness]::new(0, 0, $value, 0)
        }
        # ���͒l�����l�łȂ����A0�ȉ��̏ꍇ
        Write-Verbose '�f�t�H���g 0,0,0,0 ��Ԃ��܂�' -Verbose
        # ���ׂẴ}�[�W����0�ɐݒ肵��Thickness�I�u�W�F�N�g��Ԃ��܂�
        return [System.Windows.Thickness]::new(0, 0, 0, 0)
    }

    # ConvertBack ���\�b�h�F�t�����̕ϊ����s�����߂̃��\�b�h
    # �ʏ�AUI����ViewModel�ɒl��߂��ۂɎg�p����܂����A
    # ���̏ꍇ�͎�������Ă��Ȃ��̂ŗ�O���X���[���܂�
    [object]ConvertBack([object]$value, [Type]$targetType, [object]$parameter, [CultureInfo] $culture) {
        throw '�t�����̕ϊ��iUI����ViewModel�ցj�͎�������Ă��܂���'
    }
}

<#
.SYNOPSIS
�J�X�^���@�\������WPF�E�B���h�E�N���X

.DESCRIPTION
����PartialWindow�N���X�́A�W����WPF�E�B���h�E�iSystem.Windows.Window�j���g�����A
�E�B���h�E�̊�{�I�ȑ���i�ŏ����A�ő剻�A����Ȃǁj���J�X�^�}�C�Y���܂��B
����ɂ��A�Ǝ��̃f�U�C���⓮������E�B���h�E���쐬���邱�Ƃ��ł��܂��B

��ȓ����F
1. �V�X�e�����j���[�̕\��
2. �E�B���h�E�̍ŏ���
3. �E�B���h�E�̍ő剻
4. �E�B���h�E�̌��̃T�C�Y�ւ̕���
5. �E�B���h�E�����

�����̑���́A�ʏ�̃E�B���h�E�̕W���I�ȓ�����G�~�����[�g���Ă��܂����A
�J�X�^���f�U�C���̃E�B���h�E�ł��������@�\����悤�Ɏ�������Ă��܂��B

.EXAMPLE
# PartialWindow�N���X�̃C���X�^���X���쐬
$window = [PartialWindow]::new()

# �E�B���h�E��\��
$window.Show()

.NOTES
���̃N���X�́A�ʏ�A�J�X�^���f�U�C����XAML�e���v���[�g�Ƒg�ݍ��킹�Ďg�p���܂��B
�e���v���[�g�ł́A�����̃R�}���h���Ăяo���{�^���₻�̑��̃R���g���[�����`���܂��B
#>
class PartialWindow : System.Windows.Window {
    # �R���X�g���N�^�F�N���X�̃C���X�^���X���쐬�����Ƃ��ɌĂяo����郁�\�b�h
    PartialWindow() {
        # �V�X�e�����j���[��\������R�}���h�̃o�C���f�B���O��ǉ�
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            # �V�X�e�����j���[��\������R�}���h
            [System.Windows.SystemCommands]::ShowSystemMenuCommand, 
            # �R�}���h�����s���ꂽ�Ƃ��̏���
            {
                param($CommandParameter)
                # �}�E�X�̌��݈ʒu���擾���A�X�N���[�����W�ɕϊ�
                $Point = $CommandParameter.PointToScreen([System.Windows.Input.Mouse]::GetPosition($CommandParameter))
                # �V�X�e�����j���[��\��
                [System.Windows.SystemCommands]::ShowSystemMenu($CommandParameter,$Point)
            }
        ))

        # �E�B���h�E���ŏ�������R�}���h�̃o�C���f�B���O��ǉ�
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            [System.Windows.SystemCommands]::MinimizeWindowCommand, 
            {
                param($CommandParameter)
                [System.Windows.SystemCommands]::MinimizeWindow($CommandParameter)
            }
        ))

        # �E�B���h�E���ő剻����R�}���h�̃o�C���f�B���O��ǉ�
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            [System.Windows.SystemCommands]::MaximizeWindowCommand, 
            {
                param($CommandParameter)
                [System.Windows.SystemCommands]::MaximizeWindow($CommandParameter)
            }
        ))

        # �E�B���h�E�����̃T�C�Y�ɖ߂��R�}���h�̃o�C���f�B���O��ǉ�
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            [System.Windows.SystemCommands]::RestoreWindowCommand, 
            {
                param($CommandParameter)
                [System.Windows.SystemCommands]::RestoreWindow($CommandParameter)
            }
        ))

        # �E�B���h�E�����R�}���h�̃o�C���f�B���O��ǉ�
        $this.CommandBindings.Add([System.Windows.Input.CommandBinding]::new(
            [System.Windows.SystemCommands]::CloseWindowCommand, 
            {
                param($CommandParameter)
                [System.Windows.SystemCommands]::CloseWindow($CommandParameter)
            }
        ))

        # �J�X�^���E�B���h�E�e���v���[�g�̓K�p�i���݂̓R�����g�A�E�g����Ă��܂��j
        # $this.Template = New-WPFObject -Path "$PSScriptRoot\Views\PartialWindowTemplate.xaml" -BaseUri "$PSScriptRoot" -LocalNamespaceName 'local'
    }
}