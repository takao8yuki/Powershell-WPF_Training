Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop
function New-WPFObject {
    <#
        .SYNOPSIS
            ������܂��̓t�@�C������w�肳�ꂽXaml���g�p����WPF�I�u�W�F�N�g���쐬���܂��B
            xmlreader�ł͂Ȃ���p��WPF Xaml���[�_�[���g�p���܂��B
        .PARAMETER BaseUri
            xaml�t�@�C���̃��[�g�t�H���_�ւ̃p�X�B�t�H���_���w���ꍇ�͕K���o�b�N�X���b�V�� '\' �ŏI������K�v������܂��B
            �܂��́Afile.Xaml�ւ̃p�X�B
            ���e�X�g�̃A�C�f�A - zip�t�@�C�����w���H
            xaml���ő��΃\�[�X�������܂��B�Ⴆ�΁A<ResourceDictionary Source="Common.Xaml" /> �̂悤��Common.Xaml�������AC:\folder\Common.Xaml�̃t���p�X���n�[�h�R�[�f�B���O�������Ɏg�p�ł��܂��B
        .EXAMPLE
            -BaseUri "$PSScriptRoot\"
            -BaseUri "C:\Test\Folder\"
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        # 'HereString' �� 'HereStringDynamic' �̃p�����[�^�Z�b�g�Ŏg�p�����p�����[�^
        # �p�C�v���C�����璼��XAML�̕�������󂯎��܂�
        # �֐��ɓn�����ŏ��̈����Ƃ��Ĉʒu0�ɔz�u
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'HereString')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'HereStringDynamic')]
        [string[]]$Xaml,

        # 'Path' �� 'PathDynamic' �̃p�����[�^�Z�b�g�Ŏg�p�����p�����[�^
        # �t�@�C���̃p�X���p�C�v���C������󂯎��܂�
        # 'FullName' �Ƃ����G�C���A�X�������܂�
        # �p�C�v���C������v���p�e�B���Œl���󂯎�邱�Ƃ��ł��A�ʒu0�ɔz�u
        # �w�肳�ꂽ�p�X�����݂��邩�����؂���X�N���v�g���g�p
        [Alias('FullName')]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'Path')]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'PathDynamic')]
        [ValidateScript({ Test-Path $_ })]
        [string[]]$Path,

        # 'HereStringDynamic' �� 'PathDynamic' �̃p�����[�^�Z�b�g�Ŏg�p�����p�����[�^
        # XAML�t�C���̊��URI���w�肵�܂�
        [Parameter(Mandatory, ParameterSetName = 'HereStringDynamic')]
        [Parameter(Mandatory, ParameterSetName = 'PathDynamic')]
        [string]$BaseUri
    )

    begin {
        # WPF�ɕK�v�ȃA�Z���u����ǂݍ��݂܂�
        # �G���[�����������ꍇ�͑����ɒ�~���܂�
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop

        # BaseUri���w�肳��Ă���ꍇ�A���̃p�X�����݂��邩�`�F�b�N���܂�
        # ���݂��Ȃ��ꍇ�́ADirectoryNotFoundException���X���[���܂�
        if (!(Test-Path $BaseUri)) {
            [System.IO.DirectoryNotFoundException]::new("$($BaseUri) �͖����ȃp�X�ł�")
        }

        # BaseUri���o�b�N�X���b�V���ŏI����Ă��Ȃ��ꍇ�A�����Ƀo�b�N�X���b�V����ǉ����܂�
        # ����ɂ��A���΃p�X�̉������������s����悤�ɂȂ�܂�
        if (!$BaseUri.EndsWith('\')) { 
            $BaseUri = "$BaseUri\"
        }
    }

    process {
        Write-Debug $PSCmdlet.ParameterSetName

        $RawXaml = if ($PSBoundParameters.ContainsKey('Path')) { 
            # �t�@�C���𒼐ڃo�C�g�Ƃ��ēǂݍ��݁A���̌�G���R�[�f�B���O���w�肵�ĕ�����ɕϊ�
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            [System.Text.Encoding]::GetEncoding("shift_jis").GetString($bytes)
        } else { 
            $Xaml 
        }

        # 'PathDynamic'�܂���'HereStringDynamic'�p�����[�^�Z�b�g���g�p����Ă���ꍇ
        if ($PSCmdlet.ParameterSetName -in @('PathDynamic', 'HereStringDynamic')) {
            # ParserContext���쐬���ABaseUri��ݒ肵�܂�
            # ����ɂ��AXAML�t�@�C�����̑��΃p�X�𐳂��������ł��܂�
            $ParserContext = [System.Windows.Markup.ParserContext]::new()
            $ParserContext.BaseUri = [System.Uri]::new($BaseUri, [System.UriKind]::Absolute)

            # XamlReader.Parse���g�p����XAML�����
            [System.Windows.Markup.XamlReader]::Parse($RawXaml, $ParserContext)
        } else {
            # XamlReader.Parse���g�p����XAML����́iParserContext�Ȃ��j
            [System.Windows.Markup.XamlReader]::Parse($RawXaml)
        }
    }
}

function ConvertTo-Delegate {
    <#
    .SYNOPSIS
    PowerShell�̃��\�b�h�I�u�W�F�N�g��.NET�̃f���Q�[�g�ɕϊ����܂��B

    .DESCRIPTION
    ���̊֐��́APowerShell��PSMethod�I�u�W�F�N�g���󂯎��A�����.NET�̃f���Q�[�g�ɕϊ����܂��B
    ����́APowerShell�̃��\�b�h��.NET�̃C�x���g�n���h���[��R�[���o�b�N�Ƃ��Ďg�p����ۂɓ��ɗL�p�ł��B

    .PARAMETER PSMethod
    �ϊ�������PowerShell�̃��\�b�h�I�u�W�F�N�g�B���̃p�����[�^�̓p�C�v���C������̓��͂��󂯕t���܂��B

    .PARAMETER Target
    �f���Q�[�g�̃^�[�Q�b�g�ƂȂ�I�u�W�F�N�g�B���̃I�u�W�F�N�g���A�ϊ�����郁�\�b�h�������Ă��܂��B

    .PARAMETER IsPSObject
    �^�[�Q�b�g�I�u�W�F�N�g��PSObject�iPowerShell�̃J�X�^���I�u�W�F�N�g�j�ł��邱�Ƃ������X�C�b�`�p�����[�^�B

    .EXAMPLE
    $button.add_Click | ConvertTo-Delegate -Target $this
    ���̗�ł́A�{�^����Click�C�x���g�n���h���[�����݂̃I�u�W�F�N�g($this)�̃��\�b�h�ɕϊ����Ă��܂��B

    .EXAMPLE
    ConvertTo-Delegate -PSMethod $obj.SomeMethod -Target $obj -IsPSObject
    ���̗�ł́APSObject�̓���̃��\�b�h���f���Q�[�g�ɕϊ����Ă��܂��B

    .NOTES
    ���̊֐��́AWPF�₻�̑���.NET�x�[�X��GUI�t���[�����[�N��PowerShell�𓝍�����ۂɓ��ɗL�p�ł��B

    .LINK
    https://docs.microsoft.com/en-us/dotnet/api/system.delegate

    #>
    [CmdletBinding()]
    param (
        # PowerShell�̃��\�b�h�I�u�W�F�N�g���󂯎��܂�
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [System.Management.Automation.PSMethod[]]$PSMethod,

        # �f���Q�[�g�̃^�[�Q�b�g�ƂȂ�I�u�W�F�N�g���w�肵�܂�
        [Parameter(Mandatory)]
        [object]$Target,

        # �^�[�Q�b�g��PSObject���ǂ����������X�C�b�`�p�����[�^
        [switch]
        $IsPSObject
    )

    process {
        # �^�[�Q�b�g�I�u�W�F�N�g�̎�ނɉ����ă��t���N�V�������\�b�h���擾
        if ($IsPSObject) {
            # PSObject�̏ꍇ�Apsobject�v���p�e�B���o�R���ă��\�b�h���擾
            $ReflectionMethod = $Target.psobject.GetType().GetMethod($PSMethod.Name)
        } else {
            # �ʏ�̃I�u�W�F�N�g�̏ꍇ�A����GetType���烁�\�b�h���擾
            $ReflectionMethod = $Target.GetType().GetMethod($PSMethod.Name)
        }

        # ���\�b�h�̃p�����[�^�^�C�v���擾
        $ParameterTypes = [System.Linq.Enumerable]::Select($ReflectionMethod.GetParameters(), [func[object,object]]{ $args[0].ParameterType })
        # �p�����[�^�^�C�v�Ɩ߂�l�̌^������
        $ConcatMethodTypes = $ParameterTypes + $ReflectionMethod.ReturnType

        # ���\�b�h���߂�l�������Ȃ��ivoid�j���ǂ����𔻒�
        $IsAction = $ReflectionMethod.ReturnType -eq [void]
        if ($IsAction) {
            # void�̏ꍇ��Action�f���Q�[�g�^�C�v���擾
            $DelegateType = [System.Linq.Expressions.Expression]::GetActionType($ParameterTypes)
        } else {
            # �߂�l������ꍇ��Func�f���Q�[�g�^�C�v���擾
            $DelegateType = [System.Linq.Expressions.Expression]::GetFuncType($ConcatMethodTypes)
        }

        # �ŏI�I�Ƀf���Q�[�g���쐬���ĕԂ�
        [delegate]::CreateDelegate($DelegateType, $Target, $ReflectionMethod.Name)
    }
}

<#
.SYNOPSIS
WPF�A�v���P�[�V������ViewModel�̊�{�N���X��񋟂��܂��B

.DESCRIPTION
ViewModelBase�N���X�́AWPF�A�v���P�[�V������MVVM�p�^�[������������ۂ̊�b�ƂȂ�N���X�ł��B
���̃N���X��INotifyPropertyChanged�C���^�[�t�F�[�X���������Ă���AUI�Ƃ̃f�[�^�o�C���f�B���O��e�Ղɂ��܂��B

.NOTES
���̃N���X���p�����āA��̂�ViewModel�N���X���쐬���邱�Ƃ��ł��܂��B

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
$vm.Name = "John"  # ����ɂ��PropertyChanged�C�x���g�����΂��܂�

.LINK
https://docs.microsoft.com/en-us/dotnet/api/system.componentmodel.inotifypropertychanged
#>

class ViewModelBase : PSCustomObject, System.ComponentModel.INotifyPropertyChanged {
    # INotifyPropertyChanged �̎���
    # ���̃C�x���g�́A�v���p�e�B�̒l���ύX���ꂽ�Ƃ��ɒʒm���󂯂邽�߂Ɏg�p����܂��B
    [ComponentModel.PropertyChangedEventHandler]$PropertyChanged
    # �ȉ��́A�R�����g�A�E�g���ꂽ��ł��B�K�v�ɉ����Ďg�p���Ă��������B
    # [System.Collections.Generic.List[object]]$PropertyChanged = [System.Collections.Generic.List[object]]::new()

    # PropertyChanged �C�x���g�Ƀn���h���[��ǉ����郁�\�b�h
    add_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
        # �����̃f���Q�[�g�ɐV�����n���h���[���������܂��B
        $this.psobject.PropertyChanged = [Delegate]::Combine($this.psobject.PropertyChanged, $handler)
        # �ȉ��́A�ʂ̕��@�Ńn���h���[��ǉ������ł��B�K�v�ɉ����Ďg�p���Ă��������B
        # $this.psobject.PropertyChanged.Add($handler)
    }

    # PropertyChanged �C�x���g����n���h���[���폜���郁�\�b�h
    remove_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
        # �����̃f���Q�[�g����w�肳�ꂽ�n���h���[���폜���܂��B
        $this.psobject.PropertyChanged = [Delegate]::Remove($this.psobject.PropertyChanged, $handler)
        # �ȉ��́A�ʂ̕��@�Ńn���h���[���폜�����ł��B�K�v�ɉ����Ďg�p���Ă��������B
        # $this.psobject.PropertyChanged.Remove($handler)
    }

    # �w�肳�ꂽ�v���p�e�B���̕ύX��ʒm���郁�\�b�h
    RaisePropertyChanged([string]$propname) {
        # PropertyChanged �C�x���g�ɓo�^���ꂽ�n���h���[�����݂���ꍇ
        if ($this.psobject.PropertyChanged) {
            # �v���p�e�B�ύX�C�x���g�̈������쐬���܂�
            $evargs = [System.ComponentModel.PropertyChangedEventArgs]::new($propname)
            # ���ׂĂ̓o�^���ꂽ�n���h���[���Ăяo���܂�
            $this.psobject.PropertyChanged.Invoke($this, $evargs) # �S�Ẵ����o�[���Ăяo���܂�
            # �ȉ��́A�f�o�b�O�p�̏o�͗�ł��B�K�v�ɉ����ėL���ɂ��Ă��������B
            # Write-Verbose "RaisePropertyChanged $propname" -Verbose
        }
    }
    # INotifyPropertyChanged �̎����I��
}

<#
.SYNOPSIS
WPF�A�v���P�[�V�����Ń{�^���N���b�N�Ȃǂ̃��[�U�[�A�N�V�������������邽�߂̃N���X�ł��B

.DESCRIPTION
ActionCommand�N���X�́A�{�^���N���b�N�Ȃǂ̃��[�U�[�A�N�V�������������邽�߂Ɏg�p����܂��B
���̃N���X�́A�ȉ��̎�v�ȋ@�\��񋟂��܂��F
1. �A�N�V�����̎��s�F�{�^�����N���b�N���ꂽ�Ƃ��ɓ���̏��������s���܂��B
2. ���s�\��Ԃ̊Ǘ��F�{�^�����������Ԃ��ǂ����𐧌䂵�܂��B
3. �񓯊������FUI���t���[�Y���Ȃ��悤�ɁA�����Ԃ̏�����ʃX���b�h�Ŏ��s���܂��B
4. �X���b�g�����O�F�����Ɏ��s�ł��鏈���̐��𐧌����܂��B

.NOTES
���N���X�́AWPF�A�v���P�[�V������MVVM�iModel-View-ViewModel�j�p�^�[����
�悭�g�p����܂��BViewModel�̒��ł��̃N���X�̃C���X�^���X���쐬���A
XAML��Button��Command�v���p�e�B�Ƀo�C���h���g�p���܂��B

.EXAMPLE
# ViewModel�N���X�ł̎g�p��
class MyViewModel : ViewModelBase {
    MyViewModel() {
        $this | Add-Member -Name MyCommand -MemberType ScriptProperty -Value {
            if (-not $this.psobject.MyCommand) {
                $this.psobject.MyCommand = [ActionCommand]::new({ 
                    # �����Ƀ{�^���N���b�N���̏����������܂�
                    Write-Host "�{�^�����N���b�N����܂���" 
                })
            }
            return $this.psobject.MyCommand
        }
    }
}

# XAML�ł̎g�p��:
# <Button Content="�N���b�N���Ă�" Command="{Binding MyCommand}" />

.LINK
https://docs.microsoft.com/ja-jp/dotnet/desktop/wpf/data/how-to-implement-icommand?view=netframeworkdesktop-4.8
#>
class ActionCommand : ViewModelBase, System.Windows.Input.ICommand {
    # ICommand�C���^�[�t�F�[�X�̎���
    # ���̃C�x���g�́A�R�}���h�̎��s�\��Ԃ��ύX���ꂽ�Ƃ��ɔ������܂�
    [System.EventHandler]$InternalCanExecuteChanged
    # �ȉ��́ACanExecuteChanged�C�x���g�̃n���h���[���i�[���邽�߂̃��X�g���쐬���悤�Ƃ��Ă��܂����B
    # �ڍׂȐ����F
    # 1. [System.Collections.Generic.List[EventHandler]] �́AEventHandler�^�̃I�u�W�F�N�g���i�[�ł���W�F�l���b�N���X�g���`���Ă��܂��B
    # 2. $InternalCanExecuteChanged �́A���̃��X�g���i�[����ϐ����ł��B
    # 3. [System.Collections.Generic.List[EventHandler]]::new() �́A�V������̃��X�g���쐬���Ă��܂��B
    # 
    # ���̍s����������Ă���΁A�R�}���h�̎��s�\��Ԃ��ύX���ꂽ�Ƃ��ɒʒm���󂯎��n���h���[��
    # �Ǘ����邽�߂̃��X�g���쐬���邱�Ƃ��ł��܂����B
    # [System.Collections.Generic.List[EventHandler]]$InternalCanExecuteChanged = [System.Collections.Generic.List[EventHandler]]::new()

    # CanExecuteChanged�C�x���g�Ƀn���h���[��ǉ����郁�\�b�h
    add_CanExecuteChanged([EventHandler] $value) {
        $this.psobject.InternalCanExecuteChanged = [Delegate]::Combine($this.psobject.InternalCanExecuteChanged, $value)
        # [System.Windows.Input.CommandManager]::add_RequerySuggested($value) # ������g�p���āA���ׂẴ{�^�����Ď�����эX�V���܂��B���̃X���b�h/�����X�y�[�X����X�V����ꍇ�́ACommandManager.InvalidateRequerySuggested()���Ăяo���K�v������܂��B
        # $this.psobject.InternalCanExecuteChanged.Add($value)
    }

    # CanExecuteChanged�C�x���g����n���h���[���폜���郁�\�b�h
    remove_CanExecuteChanged([EventHandler] $value) {
        $this.psobject.InternalCanExecuteChanged = [Delegate]::Remove($this.psobject.InternalCanExecuteChanged, $value)
        # [System.Windows.Input.CommandManager]::remove_RequerySuggested($value)
        # $this.psobject.InternalCanExecuteChanged.Remove($value)
    }

    # �R�}���h�����s�\���ǂ����𔻒f���郁�\�b�h
    [bool]CanExecute([object]$CommandParameter) {
        # �X���b�g�����O���ݒ肳��Ă���ꍇ�A���݂̎��s�����X���b�g�����O�l�����Ȃ���s�\
        if ($this.psobject.Throttle -gt 0) { return ($this.psobject.Workers -lt $this.psobject.Throttle) }
        # CanExecuteAction���ݒ肳��Ă���ꍇ�͂�����Ăяo��
        if ($this.psobject.CanExecuteAction) { return $this.psobject.CanExecuteAction.Invoke() }
        # ����ȊO�̏ꍇ�͏�Ɏ��s�\
        return $true
    }

    # �R�}���h�����s���郁�\�b�h
    [void]Execute([object]$CommandParameter) {
        try {
            if ($this.psobject.Action) {
                if ($this.psobject.ThreadManager) {
                    # ThreadManager���ݒ肳��Ă���ꍇ�͔񓯊��Ŏ��s
                    $null = $this.psobject.ThreadManager.Async($this.psobject.Action, $this.psobject.InvokeCanExecuteChangedDelegate)
                    # $this.psobject.ThreadManager.AsyncTask($this.psobject.Action, $this.psobject.InvokeCanExecuteChangedDelegate)   # NEW-UNBOUNDCLASSINSTANCE VIEWMODEL���@�\���܂� - �ʂ̃����X�y�[�X�Ŏ��O�Ɏ��s����Ă���f�B�X�p�b�`���[���g�p���܂��B
                    $this.Workers++
                } else {
                    # ThreadManager���ݒ肳��Ă��Ȃ��ꍇ�͓����I�Ɏ��s
                    $this.psobject.Action.Invoke()
                }
            } else {
                # ActionObject���ݒ肳��Ă���ꍇ�̏����i���݂͎�������Ă��܂���j
                if ($this.psobject.ThreadManager) {
                    throw '��������Ă��܂���'
                    # $null = $this.psobject.ThreadManager.Async($this.psobject.ActionObject, $this.psobject.InvokeCanExecuteChangedDelegate)
                    $this.Workers++
                } else {
                    $this.psobject.ActionObject.Invoke($CommandParameter)
                }
            }
        } catch {
            Write-Error "ActionCommand.Execute�̏������ɃG���[���������܂���: $_"
        }
    }
    # ICommand �����̏I��

    # �f�t�H���g�R���X�g���N�^
    ActionCommand() {
        $this.psobject.Init()  # ���������\�b�h���Ăяo��
    }

    # Action���󂯎��R���X�g���N�^
    ActionCommand([Action]$Action) {
        $this.psobject.Action = $Action  # �����œn���ꂽAction��ݒ�
    }

    # �I�u�W�F�N�g�������Ɏ��Action���󂯎��R���X�g���N�^
    ActionCommand([Action[object]]$Action) {
        $this.psobject.ActionObject = $Action  # �I�u�W�F�N�g�������Ɏ��Action��ݒ�
    }

    # Action��ThreadManager���󂯎��R���X�g���N�^
    ActionCommand([Action]$Action, $ThreadManager) {
        $this.psobject.Init()  # ������
        $this.psobject.Action = $Action  # Action��ݒ�
        $this.psobject.ThreadManager = $ThreadManager  # ThreadManager��ݒ�
    }

    # �I�u�W�F�N�g�������Ɏ��Action��ThreadManager���󂯎��R���X�g���N�^
    ActionCommand([Action[object]]$Action, $ThreadManager) {
        $this.psobject.Init()  # ������
        $this.psobject.ActionObject = $Action  # �I�u�W�F�N�g�������Ɏ��Action��ݒ�
        $this.psobject.ThreadManager = $ThreadManager  # ThreadManager��ݒ�
    }

    # ���������\�b�h
    Init() {
        # CanExecuteChanged�C�x���g���Ăяo�����߂̃f���Q�[�g���쐬
        $this.psobject.InvokeCanExecuteChangedDelegate = $this.psobject.CreateDelegate($this.psobject.InvokeCanExecuteChanged)
        
        # Workers�v���p�e�B�𓮓I�ɒǉ�
        # ���̃v���p�e�B�́A���s���Ď��s�ł��郏�[�J�[�̐��𐧌䂵�܂�
        $this | Add-Member -Name Workers -MemberType ScriptProperty -Value {
            return $this.psobject.Workers  # ���݂̒l��Ԃ�
        } -SecondValue {
            param($value)
            $this.psobject.Workers = $value  # �V�����l��ݒ�
            $this.psobject.RaisePropertyChanged('Workers')  # �v���p�e�B�ύX��ʒm
            $this.psobject.RaiseCanExecuteChanged()  # CanExecute�̏�Ԃ��ύX���ꂽ�\�������邱�Ƃ�ʒm
        }

        # Throttle�v���p�e�B�𓮓I�ɒǉ�
        # ���̃v���p�e�B�́A�R�}���h�̎��s�p�x�𐧌����邽�߂Ɏg�p����܂�
        $this | Add-Member -Name Throttle -MemberType ScriptProperty -Value {
            return $this.psobject.Throttle  # ���݂̒l��Ԃ�
        } -SecondValue {
            param($value)
            $this.psobject.Throttle = $value  # �V�����l��ݒ�
            $this.psobject.RaisePropertyChanged('Throttle')  # �v���p�e�B�ύX��ʒm
            $this.psobject.RaiseCanExecuteChanged()  # CanExecute�̏�Ԃ��ύX���ꂽ�\�������邱�Ƃ�ʒm
        }
    }

    # CanExecuteChanged�C�x���g�𔭐������郁�\�b�h
    # ���̃��\�b�h�́A�R�}���h�̎��s�\��Ԃ��ύX���ꂽ�Ƃ��ɌĂяo����܂�
    [void]RaiseCanExecuteChanged() {
        # InternalCanExecuteChanged�C�x���g�n���h���[���擾
        $eCanExecuteChanged = $this.psobject.InternalCanExecuteChanged
        if ($eCanExecuteChanged) {
            # �R�}���h�����s�\�ȏ�Ԃ��A�X���b�g�����O���ݒ肳��Ă���ꍇ�ɃC�x���g�𔭐�������
            if ($this.psobject.CanExecuteAction -or ($this.psobject.Throttle -gt 0)) {
                # �C�x���g�n���h���[���Ăяo���A���EventArgs��n��
                $eCanExecuteChanged.Invoke($this, [System.EventArgs]::Empty)
            }
        }
    }

    # �񓯊������������Workers�������炵�ACanExecuteChanged���Ăяo�����\�b�h
    # ���̃��\�b�h�́A�񓯊����������������Ƃ���UI�X���b�h�Ŏ��s����܂�
    [void]InvokeCanExecuteChanged() {
        $ActionCommand = $this
        # UI�X���b�h��Workers�������炵�ACanExecuteChanged�C�x���g�𔭐�������
        $this.psobject.Dispatcher.Invoke(9,[Action[object]]{
            param($ActionCommand)
            # Workers����1���炷
            $ActionCommand.Workers--
            # ����: ������CanExecuteChanged�C�x���g�𖾎��I�ɔ��������Ă��Ȃ����A
            # Workers�v���p�e�B�̕ύX�ɂ���ĊԐړI�ɔ�������\��������
        }, $ActionCommand)
    }

    # �N���X�̃v���p�e�B�ƃt�B�[���h�̒�`

    $Action                  # ���������Ȃ��A�N�V�������i�[
    $ActionObject            # �I�u�W�F�N�g�������Ɏ��A�N�V�������i�[
    $CanExecuteAction        # �R�}���h�����s�\���ǂ����𔻒f���邽�߂̏������i�[
    $ThreadManager           # �X���b�h�Ǘ��I�u�W�F�N�g���i�[
    $Workers = 0             # ���ݎ��s���̃��[�J�[����ǐՁi�����l��0�j
    $Throttle = 0            # �R�}���h���s�̐����l�i�����l��0�A�����Ȃ��j
    $InvokeCanExecuteChangedDelegate  # CanExecuteChanged�C�x���g���Ăяo�����߂̃f���Q�[�g
    $Dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher  # ���݂�UI�X���b�h��Dispatcher���擾

    # �f���Q�[�g���쐬���郁�\�b�h
    # ���̃��\�b�h�́APowerShell�̃��\�b�h��.NET�̃f���Q�[�g�ɕϊ����܂�
    [Delegate]CreateDelegate([System.Management.Automation.PSMethod]$Method) {
        # ���\�b�h�̏����擾
        $ReflectionMethod = $this.psobject.GetType().GetMethod($Method.Name)
        
        # ���\�b�h�̃p�����[�^�^���擾
        $ParameterTypes = [System.Linq.Enumerable]::Select($ReflectionMethod.GetParameters(), [func[object,object]]{$args[0].parametertype})
        
        # �p�����[�^�^�Ɩ߂�l�̌^������
        $ConcatMethodTypes = $ParameterTypes + $ReflectionMethod.ReturnType
        
        # �K�؂ȃf���Q�[�g�^���擾
        $DelegateType = [System.Linq.Expressions.Expression]::GetDelegateType($ConcatMethodTypes)
        
        # �f���Q�[�g���쐬
        $Delegate = [delegate]::CreateDelegate($DelegateType, $this, $ReflectionMethod.Name)
        
        # �쐬�����f���Q�[�g��Ԃ�
        return $Delegate
    }
}


<#
.SYNOPSIS
�����̔񓯊��������Ǘ����邽�߂̃N���X�ł��B

.DESCRIPTION
ThreadManager�N���X�́A�����̔񓯊������i�o�b�N�O���E���h�^�X�N�j��
�����I�ɊǗ����邽�߂Ɏg�p����܂��B���̃N���X�̎�ȋ@�\�́F
1. �����̔񓯊������𓯎��Ɏ��s����
2. �����̊�����҂�
3. �����̌��ʂ��擾����
4. �g�p���Ă��Ȃ����\�[�X��K�؂ɉ������

.NOTES
���̃N���X�́AUI�̉��������ێ����Ȃ��璷���Ԃ̏������s���K�v������
WPF�A�v���P�[�V�����œ��ɗL�p�ł��B

.EXAMPLE
# ThreadManager�̍쐬
$threadManager = [ThreadManager]::new()

# �񓯊������̎��s
$task = $threadManager.Async({ 
    # �����ɒ����Ԃ̏����������܂�
    Start-Sleep -Seconds 5
    return "�������������܂���"
})

# �����̊�����҂��A���ʂ��擾
$result = $task.Result
Write-Host $result

# �g�p�I����Ƀ��\�[�X�����
$threadManager.Dispose()

.LINK
https://docs.microsoft.com/ja-jp/dotnet/api/system.threading.tasks.task?view=net-5.0
#>
class ThreadManager : System.IDisposable {
    # IDisposable�C���^�[�t�F�[�X�̎���
    # ���\�[�X��������郁�\�b�h
    Dispose() {
        $this.RunspacePool.Dispose()
    }

    # ���L�ϐ����i�[���邽�߂̎���
    $SharedPoolVars = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
    
    # �^�X�N�������ɌĂяo�����f���Q�[�g
    $DisposeTaskDelegate = $this.CreateDelegate($this.DisposeTask)

    # PowerShell�C���X�^���X�����s���邽�߂�RunspacePool
    $RunspacePool

    # �֐����̃��X�g���󂯎��R���X�g���N�^
    ThreadManager($FunctionNames) {
        $this.Init($FunctionNames)  # ���������\�b�h���Ăяo��
    }

    # �f�t�H���g�R���X�g���N�^
    ThreadManager() {
        $this.Init($null)  # �֐����Ȃ��ŏ��������\�b�h���Ăяo��
    }

    # ���������\�b�h�i����J�j
    hidden Init($FunctionNames) {
        # �f�t�H���g�̏����Z�b�V������Ԃ��쐬
        $State = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        
        # ���L�ϐ����Z�b�V������Ԃɒǉ�
        $RunspaceVariable = New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'SharedPoolVars', $this.SharedPoolVars, $null
        $State.Variables.Add($RunspaceVariable)

        # �w�肳�ꂽ�֐����Z�b�V������Ԃɒǉ�
        foreach ($FunctionName in $FunctionNames) {
            # �֐���`���擾
            $FunctionDefinition = Get-Content Function:\$FunctionName -ErrorAction 'Stop'
            # �Z�b�V������ԂɊ֐���ǉ�
            $SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $FunctionName, $FunctionDefinition
            $State.Commands.Add($SessionStateFunction)
        }

        # RunspacePool���쐬
        # �ŏ�1�A�ő�̓v���Z�b�T��+1�̃X���b�h���g�p
        $this.RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $([int]$env:NUMBER_OF_PROCESSORS + 1), $State, (Get-Host))
        
        # RunspacePool�̐ݒ�
        $this.RunspacePool.ApartmentState = 'STA'  # �V���O���X���b�h�A�p�[�g�����g���[�h��ݒ�
        $this.RunspacePool.ThreadOptions = 'ReuseThread'  # �X���b�h�̍ė��p��ݒ�
        $this.RunspacePool.CleanupInterval = [timespan]::FromMinutes(2)  # �N���[���A�b�v�Ԋu��2���ɐݒ�
        
        # RunspacePool���J��
        $this.RunspacePool.Open()  # TODO: ���������\�b�h�Ɉړ����邩�ARunspacePool���N���X�O�̕ϐ��ɂ���
    }

    # �񓯊��������J�n���郁�\�b�h
    [object]Async([scriptblock]$scriptblock) {
        # PowerShell�C���X�^���X�̍쐬
        $Powershell = [powershell]::Create()
        $EndInvokeDelegate = $this.CreateDelegate($Powershell.EndInvoke, $Powershell)
        $Powershell.RunspacePool = $this.RunspacePool

        # �X�N���v�g�u���b�N�̒ǉ��Ǝ��s�J�n
        $null = $Powershell.AddScript($scriptblock)
        $Handle = $Powershell.BeginInvoke()

        # �^�X�N�̍쐬
        $TaskFactory = [System.Threading.Tasks.TaskFactory]::new([System.Threading.Tasks.TaskScheduler]::Default)
        $Task = $TaskFactory.FromAsync($Handle, $EndInvokeDelegate)
        $null = $Task.ContinueWith($this.DisposeTaskDelegate, $Powershell)

        return $Task
    }

    # �f���Q�[�g��񓯊��Ŏ��s���郁�\�b�h�i�I�[�o�[���[�h�j
    [object]Async([Delegate]$MethodToRunAsync) {
        return $this.Async($MethodToRunAsync, $null)
    }

    # �f���Q�[�g�ƃR�[���o�b�N��񓯊��Ŏ��s���郁�\�b�h
    [object]Async([Delegate]$MethodToRunAsync, [Delegate]$Callback) {
        # PowerShell�C���X�^���X�̍쐬
        $Powershell = [powershell]::Create()
        $EndInvokeDelegate = $this.CreateDelegate($Powershell.EndInvoke, $Powershell)
        $Powershell.RunspacePool = $this.RunspacePool

        # ���s����A�N�V�����̒�`
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

        # PowerShell�C���X�^���X�ɃX�N���v�g�ƃp�����[�^��ǉ�
        $null = $Powershell.AddScript($NoContext)
        $null = $Powershell.AddParameter('MethodToRunAsync', $MethodToRunAsync)
        if ($Callback) { $null = $Powershell.AddParameter('Callback', $Callback) }
        $Handle = $Powershell.BeginInvoke()

        # �^�X�N�̍쐬
        $TaskFactory = [System.Threading.Tasks.TaskFactory]::new([System.Threading.Tasks.TaskScheduler]::Default)
        # �������Ɏ����I�� EndInvoke ��񓯊��ŌĂяo���܂��B
        # �����ă^�X�N��Ԃ��܂��B
        # ��p�̃����X�y�[�X�𗧂��グ�ăN���[���A�b�v����K�v�͂���܂���B
        $Task = $TaskFactory.FromAsync($Handle, $EndInvokeDelegate)
        $null = $Task.ContinueWith($this.DisposeTaskDelegate, $Powershell)

        return $Task
    }

    # �^�X�N��������PowerShell�C���X�^���X��j�����郁�\�b�h
    DisposeTask([System.Threading.Tasks.Task]$Task, [object]$Powershell) {
        # $Task.Result
        $Powershell.Dispose()
    }

    # CreateDelegate���\�b�h�̃I�[�o�[���[�h�i������1�̃o�[�W�����j
    [Delegate]CreateDelegate([System.Management.Automation.PSMethod]$Method) {
        # ���g�i$this�j���^�[�Q�b�g�Ƃ��āA2�̈��������o�[�W������CreateDelegate���Ăяo��
        return $this.CreateDelegate($Method, $this)
    }

    # CreateDelegate���\�b�h�̃I�[�o�[���[�h�i������2�̃o�[�W�����j
    [Delegate]CreateDelegate([System.Management.Automation.PSMethod]$Method, $Target) {
        # ���t���N�V�������g�p���ă��\�b�h�����擾
        $ReflectionMethod = $Target.GetType().GetMethod($Method.Name)
        
        # ���\�b�h�̃p�����[�^�^���擾
        # LINQ��Select���\�b�h���g�p���āA�e�p�����[�^�̌^�𒊏o
        $ParameterTypes = [System.Linq.Enumerable]::Select($ReflectionMethod.GetParameters(), [func[object,object]]{$args[0].parametertype})
        
        # �p�����[�^�^�Ɩ߂�l�̌^������
        $ConcatMethodTypes = $ParameterTypes + $ReflectionMethod.ReturnType
        
        # �K�؂ȃf���Q�[�g�^���擾
        # �����������\�b�h�^�����g�p���āA�K�؂ȃf���Q�[�g�^�𐶐�
        $DelegateType = [System.Linq.Expressions.Expression]::GetDelegateType($ConcatMethodTypes)
        
        # �f���Q�[�g���쐬
        # �w�肳�ꂽ�^�[�Q�b�g�A���\�b�h���A�f���Q�[�g�^���g�p���ăf���Q�[�g�𐶐�
        $Delegate = [delegate]::CreateDelegate($DelegateType, $Target, $ReflectionMethod.Name)
        
        # �쐬�����f���Q�[�g��Ԃ�
        return $Delegate
    }
}
