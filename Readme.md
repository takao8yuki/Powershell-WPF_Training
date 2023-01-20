# Powershell 5.1 and WPF
An attempt at learning WPF with PowerShell, along with VSCode, Git and, Github.

Challenge:
1. To write a GUI in pure PowerShell and .Net.
2. No added custom C# code through ```Add-Type```.
3. Limited to resources that come natively with Windows 10.


# Notes

#### *It's okay to take the easier route. The code behind doesn't need to be devoid of anycode whatsoever. The UI was created using something that wasn't meant to create a UI.*

<br>


#### **Context Menu**

Context Menu's are not part of the visual tree, use PlacementTarget.property, RelativeSource to find the datacontext.

https://stackoverflow.com/questions/9880589/bind-to-selecteditems-from-datagrid-or-listbox-in-mvvm

# Helpful References

RelayCommand

https://github.com/nohwnd/WpfToolkit

Incomplete example

https://gist.github.com/mouadcherkaoui/7b0f32d9dbefa71102acdbb07299c9bb

Snake

https://gist.github.com/nikonthethird/2ab6bfad9a81d5fe127fd0d1c2844b7c

Minesweeper

https://gist.github.com/nikonthethird/4e410ac3c04ea6633043a5cb7be1d717

Xaml MenuItem ControlTemplate

https://stackoverflow.com/questions/24698755/how-to-change-the-background-of-the-menuitem-on-mouseover-in-wpf

