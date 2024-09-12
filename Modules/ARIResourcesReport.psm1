function Start-ARIResourceReporting {
    Param($InTag, $file, $SmaResources, $DefaultPath, $TableStyle, $Unsupported, $DebugEnvSize, $DataActive, $Debug)
    if ($Debug.IsPresent)
        {
            $DebugPreference = 'Continue'
            $ErrorActionPreference = 'Continue'
        }
    else
        {
            $ErrorActionPreference = "silentlycontinue"
        }
    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Reporting Phase.')
    Write-Progress -activity $DataActive -Status "Processing Inventory" -PercentComplete 50

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Running Offline, Gathering List Of Modules.')
    if($PSScriptRoot -like '*\*')
        {
            $Modules = Get-ChildItem -Path ($PSScriptRoot + '\Scripts\*.ps1') -Recurse
        }
    else
        {
            $Modules = Get-ChildItem -Path ($PSScriptRoot + '/Scripts/*.ps1') -Recurse
        }

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Modules Found: ' + $Modules.Count)
    $Lops = $Modules.count
    $ReportCounter = 0

    if($DebugEnvSize -eq 'Large')
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Looking for Cache Files.')
            $LocalCacheFiles = Get-ChildItem -Path ($DefaultPath+'\ReportCache\*.json')
        }

    foreach ($Module in $Modules) {

        $c = (($ReportCounter / $Lops) * 100)
        $c = [math]::Round($c)
        Write-Progress -Id 1 -activity "Building Report" -Status "$c% Complete." -PercentComplete $c

        $ModuSeq0 = New-Object System.IO.StreamReader($Module.FullName)
        $ModuSeq = $ModuSeq0.ReadToEnd()
        $ModuSeq0.Dispose()
        Start-Sleep -Milliseconds 50
        $ModuleName = $Module.name.replace('.ps1','')

        if($DebugEnvSize -eq 'Large')
        {
            $SmaResources = foreach ($LocalFile in $LocalCacheFiles)
                {
                    $TempContent = Get-Content -Path $LocalFile | ConvertFrom-Json
                    if ($TempContent.$ModuleName.count -gt 0)
                        {
                            $TempVar = @{
                                $ModuleName = $TempContent.$ModuleName
                            }
                        }
                        $TempVar
                }
        }

        $ModuleResourceCount = $SmaResources.$ModuleName.count

        if ($ModuleResourceCount -gt 0)
            {
                Start-Sleep -Milliseconds 100
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+"Running Module: '$ModuleName'. Lines Count: $ModuleResourceCount")

                $ExcelRun = ([PowerShell]::Create()).AddScript($ModuSeq).AddArgument($PSScriptRoot).AddArgument($null).AddArgument($InTag).AddArgument($null).AddArgument('Reporting').AddArgument($file).AddArgument($SmaResources).AddArgument($TableStyle).AddArgument($Unsupported)

                $ExcelJob = $ExcelRun.BeginInvoke()

                while ($ExcelJob.IsCompleted -contains $false) { Start-Sleep -Milliseconds 500 }

                $ExcelRun.EndInvoke($ExcelJob)

                $ExcelRun.Dispose()

                [System.GC]::GetTotalMemory($true) | out-null
            }

        if($DebugEnvSize -eq 'Large')
            {
                Clear-Variable SmaResources
                [System.GC]::GetTotalMemory($true) | out-null
            }

        $ReportCounter ++

    }

    if($DebugEnvSize -eq 'Large')
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Cleaning Cache Files.')
            Remove-Item -Path ($DefaultPath+'\ReportCache\') -Recurse
        }

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Resource Reporting Phase Done.')
}