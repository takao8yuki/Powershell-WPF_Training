function New-WPFObject {
    <#
        .SYNOPSIS
            Creates a WPF object with given Xaml from a string or file
            Uses the dedicated wpf xaml reader rather than the xmlreader.
        .PARAMETER BaseUri
            Path to the root folder of xaml files. Must end with backslash '\' if pointing to folder
            Or a path to a file.Xaml. Untested idea - point to zip file?
            Allows relative sources in the xaml. <ResourceDictionary Source="Common.Xaml" /> where Common.Xaml is allowed vs hard coding the fullpath C:\folder\Common.Xaml.
        .EXAMPLE
            -BaseUri "$PSScriptRoot\"
        .PARAMETER DynamicAssemblyName
            Allows mapping a custom namespace with a dynamic assembly. You will be able to use defined classes in the xaml.
            <local:myClass />
            <localA:CustomFrameElement />
        .EXAMPLE
            $dict = [System.Collections.Generic.Dictionary[string, object]]::new()
            $dict.Add('local',[WindowViewModel])
            $dict.Add('localA',[MainWindowViewModelDP])
            -DynamicAssemblyName $dict
    #>
    [CmdletBinding(DefaultParameterSetName = 'HereString')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'HereString')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'HereStringDynamic')]
        [string[]]$Xaml,

        [Alias('FullName')]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'Path')]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'PathDynamic')]
        [ValidateScript({ Test-Path $_ })]
        [string[]]$Path,

        [Parameter(Mandatory, ParameterSetName = 'HereStringDynamic')]
        [Parameter(Mandatory, ParameterSetName = 'PathDynamic')]
        [string]$BaseUri,

        [Parameter(Mandatory, ParameterSetName = 'HereStringDynamic')]
        [Parameter(Mandatory, ParameterSetName = 'PathDynamic')]
        [System.Collections.Generic.IDictionary[string, object]]$DynamicAssemblyName
    )

    begin {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop
    }

    process {
        Write-Debug $PSCmdlet.ParameterSetName
        $RawXaml = if ($PSBoundParameters.ContainsKey('Path')) { Get-Content -Path $Path } else { $Xaml }

        if ($PSCmdlet.ParameterSetName -in @('PathDynamic', 'HereStringDynamic')) {
            $ParserContext = [System.Windows.Markup.ParserContext]::new()
            $ParserContext.BaseUri = [System.Uri]::new($BaseUri, [System.UriKind]::Absolute)

            $AssemblyNames = foreach($Key in $DynamicAssemblyName.Keys) {
                $ParserContext.XmlnsDictionary.Add($Key, "clr-namespace:;assembly=$($DynamicAssemblyName[$Key].Assembly.GetName().Name)")
                $DynamicAssemblyName[$Key].Assembly.GetName().Name
            }

            $XamlTypeMapper = [System.Windows.Markup.XamlTypeMapper]::new($AssemblyNames)
            foreach($Key in $DynamicAssemblyName.Keys) {
                $XamlTypeMapper.AddMappingProcessingInstruction($Key, '', $($DynamicAssemblyName[$Key].Assembly.GetName().Name))
            }
            $ParserContext.XamlTypeMapper = $XamlTypeMapper

            [System.Windows.Markup.XamlReader]::Parse($RawXaml, $ParserContext)
        } else {
            [System.Windows.Markup.XamlReader]::Parse($RawXaml)
        }
    }
}
