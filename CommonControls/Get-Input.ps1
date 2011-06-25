function Get-Input
{
    param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({
        $in = $_
        $badKeys =$in.Keys | Where-Object { $_ -isnot [string] }
        if ($badKeys) {
            throw "Not all field names were strings.  All field names must be strings."
        }
        
        $badValues = $in.Values | 
            Get-Member | 
            Select-Object -ExpandProperty TypeName -Unique |
            Where-Object { 
                ($_ -ne 'System.RuntimeType' -and
                $_ -ne 'System.Management.Automation.ScriptBlock' -and
                $_ -ne 'System.String')
            }
        if ($badValues) {
            throw "Not all values were strings, types, or script blocks.  All values must be strings, types or script blocks."
        }   
        return $true             
    })]
    [Hashtable]$Field,    
    [string[]]$Order,    
    # The name of the control        
    [string]$Name,
    # If the control is a child element of a Grid control (see New-Grid),
    # then the Row parameter will be used to determine where to place the
    # top of the control.  Using the -Row parameter changes the 
    # dependency property [Windows.Controls.Grid]::RowProperty
    [Int]$Row,
    # If the control is a child element of a Grid control (see New-Grid)
    # then the Column parameter will be used to determine where to place
    # the left of the control.  Using the -Column parameter changes the
    # dependency property [Windows.Controls.Grid]::ColumnProperty
    [Int]$Column,
    # If the control is a child element of a Grid control (see New-Grid)
    # then the RowSpan parameter will be used to determine how many rows
    # in the grid the control will occupy.   Using the -RowSpan parameter
    # changes the dependency property [Windows.Controls.Grid]::RowSpanProperty 
    [Int]$RowSpan,
    # If the control is a child element of a Grid control (see New-Grid)
    # then the RowSpan parameter will be used to determine how many columns
    # in the grid the control will occupy.   Using the -ColumnSpan parameter
    # changes the dependency property [Windows.Controls.Grid]::ColumnSpanProperty
    [Int]$ColumnSpan,
    # The -Width parameter will be used to set the width of the control
    [Int]$Width, 
    # The -Height parameter will be used to set the height of the control
    [Int]$Height,
    # If the control is a child element of a Canvas control (see New-Canvas),
    # then the Top parameter controls the top location within that canvas
    # Using the -Top parameter changes the dependency property 
    # [Windows.Controls.Canvas]::TopProperty
    [Double]$Top,
    # If the control is a child element of a Canvas control (see New-Canvas),
    # then the Left parameter controls the left location within that canvas
    # Using the -Left parameter changes the dependency property
    # [Windows.Controls.Canvas]::LeftProperty
    [Double]$Left,
    # If the control is a child element of a Dock control (see New-Dock),
    # then the Dock parameter controls the dock style within that panel
    # Using the -Dock parameter changes the dependency property
    # [Windows.Controls.DockPanel]::DockProperty
    [Windows.Controls.Dock]$Dock,
    # If Show is set, then the UI will be displayed as a modal dialog within the current
    # thread.  If the -Show and -AsJob parameters are omitted, then the control should be 
    # output from the function
    [Switch]$Show,
    # If AsJob is set, then the UI will displayed within a WPF job.
    [Switch]$AsJob
    )
    
    $uiParameters=  @{} + $psBoundParameters
    $null = $uiParameters.Remove('Field')
    New-Grid -Columns 'Auto', 1* -ControlName Get-Input @uiParameters -On_Loaded {
        $this.RowDefinitions.Clear()
        $rows = ConvertTo-GridLength (@('Auto')*($field.Count + 2))
        foreach ($rd in $rows) {
            $r = New-Object Windows.Controls.RowDefinition -Property @{Height=$rd}
            $null =$this.RowDefinitions.Add($r)
        }
        $row = 0        
        
        if (-not $fieldOrder) {
            $fieldOrder = @($field.Keys |Sort-Object)
        }       
        
        foreach ($key in $fieldOrder) {            
            if ($field[$key]) {
                
                $value = $field[$key]
                New-Label $key -Row $row | 
                    Add-ChildControl -parent $this
                                    
                if ($value -is [ScriptBlock]) {
                    if ($value.Render) {
                        # If Render is set, the ScriptBlock creates the contents of a stackpanel
                        # otherwise, the scriptblock is the validation                    
                    } else {
                        if ($value.AllowScriptEntry) {
                        }
                    }
                } elseif ($value -is [Type]) {
                    # If a type is provided, try to find a match 
                    $commands =Get-UICommand | 
                        Where-Object {
                            ($_.OutputType | Select-Object -ExpandProperty Type) -contains $value
                        }      
                    if (-not $commands) {
                        # No match, accept a string value
                    } else {
                        if ($commands.Count) {
                            $getKeyMatch = $commands | 
                                Where-Object {                                
                                    $_.Name -eq "Get-$Key"                                 
                                }                        
                            $editKeyMatch = $commands | 
                                Where-Object { 
                                    $_.Name -eq "Edit-$Key"
                                }
                            if ($getKeyMatch) {
                                $command = $getKeyMatch
                            } elseif ($editKeyMatch) {
                                $command = $editKeyMatch
                            } else {
                                $command = $commands | Select-Object -First 1 
                            }                     
                        } else {
                            # Only one match, use it
                            $command = $commands
                        }
                        & $command -Name $key -Row $row -Column 1 | 
                                Add-ChildControl -parent $this 
                    }              
                } elseif ($value -is [string]) {
                    # The string is cue text
                    $expectedType = if ($value.ExpectedType -as [Type]) { $value.ExpectedType } else {[PSObject] }
                    New-TextBox -Resource @{ExpectedType=$expectedType} -Name $key -Column 1 -Row $row -VisualStyle CueText -Text $value -On_TextChanged {
                        if (-not ($this.Text -as $expectedType)) {
                        }
                    }  | 
                        Add-ChildControl -parent $this
                }
                    
                $row++
            }
        }
        
        New-TextBlock -ColumnSpan 2 -Row $row -Name 'ErrorText' -Visibility Collapsed | 
            Add-ChildControl -parent $this
        
        New-UniformGrid -Row $row -ColumnSpan 2 {
            New-Button -Name CancelButton -IsCancel -On_Click {
                Get-ParentControl | 
                    Close-Control
            }
            
            New-Button -Column 1 -Name OKButton -IsDefault { "_OK" } -On_Click {
                Get-ParentControl | 
                    Set-UIValue -passThru | 
                    Close-Control
            } 
        }  | 
                Add-ChildControl -parent $this
    }
}