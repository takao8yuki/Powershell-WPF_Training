function Show-WPFMessageBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Title = 'Show-WPFMessageBox',
        [ValidateSet('OK', 'OKCancel', 'AbortRetryIgnore', 'YesNoCancel', 'YesNo', 'RetryCancel')]
        [string]$Button = 'OkCancel',
        [ValidateSet('None', 'Hand', 'Error', 'Stop', 'Question', 'Exclamation', 'Warning', 'Asterisk', 'Information')]
        [string]$Icon = 'None'
    )
    [System.Windows.MessageBox]::Show($Message, $Title, $Button, $Icon)
}
