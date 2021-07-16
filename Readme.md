# Powershell 5.1 and WPF
This is my attempt at learning WPF with Powershell, along with VSCode and github.

This went from a simple GUI from [FoxDeploy](https://www.foxdeploy.com/blog/part-v-powershell-guis-responsive-apps-with-progress-bars.html) to an attempt at something resembling MVVM.

### **Why?**

Many who are in the IT field, or have C# in their toolbelts, would have written their GUI project in C#. I've seen many attempts at stackoverflow, with comments that say *move onto C#*, *use a proper tool for it*, *it's easier in C#*. I'm not qualified to judge, but I'd assume they're correct.

However, I, am currently not in the IT field and *probably don't know any better*. This was written because I wanted to learn. I have no formal training in C#. I am self taught in Powershell. Fortunately the syntax between Powershell and C# closely resemble each other. C# was brought up numerous times while researching how to put this together. As many have said, Powershell is a gateway drug to C#.

# Requirements
### **Modules in $env:PSModulePath**
1. Modules\RunspacePool\RunspacePool.psm1
2. Modules\ViewModel\ViewModel.psm1
3. Modules\ViewModel\ViewModel.psd1
4. Modules\ViewModel\ViewModelHelper.psm1

- **RunspacePool.psm1** for simulated background tasks.
- **ViewModel.psm1** requires assemblies **PresentationFramework** and **PresentationCore** to be loaded first.
- Since classes in Powershell are parsed before assemblies are loaded, we need a helper module, **ViewModelHelper.psm1**, to load the required assemblies.
- **ViewModel.psd1** includes **ViewModelHelper.psm1** as a nested module. Nested modules in .psd1 files are loaded before the root .psm1 file.

# Notes
#### **Buttons**
- Buttons that only act on the view should stay on the view code behind, not the view model. So custom close, maximize, restore, minimize in the code behind are fine.

https://stackoverflow.com/questions/4671368/binding-the-windowstate-property-of-a-window-in-wpf-using-mvvm

- Button states must be refreshed manually if task is on another runspace/thread by calling:

```powershell
[System.Windows.Input.CommandManager]::InvalidateRequerySuggested()
```

https://stackoverflow.com/questions/50927967/relaycommand-change-canexecute-automatic

#### **Context Menu**

Context Menu's are not part of the visual tree, use PlacementTarget.property, RelativeSource to find the datacontext.

https://stackoverflow.com/questions/9880589/bind-to-selecteditems-from-datagrid-or-listbox-in-mvvm

# Helpful References

RelayCommand

https://github.com/nohwnd/WpfToolkit

Snake

https://gist.github.com/nikonthethird/2ab6bfad9a81d5fe127fd0d1c2844b7c

Minesweeper

https://gist.github.com/nikonthethird/4e410ac3c04ea6633043a5cb7be1d717

Starter GUI

https://www.foxdeploy.com/blog/part-v-powershell-guis-responsive-apps-with-progress-bars.html

Xaml MenuItem ControlTemplate

https://stackoverflow.com/questions/24698755/how-to-change-the-background-of-the-menuitem-on-mouseover-in-wpf

