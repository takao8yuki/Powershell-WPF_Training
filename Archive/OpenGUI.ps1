using module '.\WPFClassHelper\WPFClassHelper.psd1'
using module '.\SampleWPF.psm1'
using namespace System.Collections.Generic

$DebugPreference = 'Continue'

$firstView = New-WPFObject -Path "$PSScriptRoot\Views\FirstView.Xaml"
$firstView.DataContext = [FirstViewModel]::new()
$secondView = New-WPFObject -Path "$PSScriptRoot\Views\SecondView.Xaml"
$secondView.DataContext = [SecondViewModel]::new()
$windowViewModel = [WindowViewModel]::new([ViewModelNames]::First, $firstView)
$windowViewModel.AddView([ViewModelNames]::Second, $secondView)

$dict = [Dictionary[string, object]]::new()
$dict.Add('local', [WindowViewModel]) # the dynamic assembly contains all classes in the WindowViewModel's file.
$window = New-WPFObject -Path "$PSScriptRoot\Views\MainWindow.Xaml" -BaseUri "$PSScriptRoot\Views\" -DynamicAssemblyName $dict
$window.DataContext = $windowViewModel
$window.ShowDialog()
