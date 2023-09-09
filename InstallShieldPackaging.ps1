<#
    .SYNOPSIS
    This script is used to package the NEXiA application using InstallShield SAB.

    .DESCRIPTION
    This script is used to package the NEXiA application using InstallShield SAB. It is called by importing the module, calling the function 
    and passing the required parameters.

    .PARAMETER WorkingDirectory, BuildArchive
    

    .EXAMPLE
    Start-PackagingNexia -WorkingDirectory $WorkingDirectory -BuildArchive $BuildArchive -SourceRoot $SourceRoot
#>

Function Start-PackagingNexia{
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory=$true)]
        [string]$BuildArchive,
        [Parameter(Mandatory=$true)]
        [string]$SourceRoot
    )

    # Trap any errors found in if InstallShiled fails to complete
    trap {"Error Found: $_"; exit 1}
    # Ensure T drive is mapped

    # Generate the latest version number
    $SimpleVersion = ((Get-ChildItem -Directory $BuildArchive | Sort-Object LastWriteTime -Descending | Where-Object {$_.BaseName  -Match "\d\d.\d\d.\d\d"} | Select-Object -First 1) -split " ")[-1]
    if ($env:BuildType -eq 'Release') {
        $Version = $SimpleVersion -split "\."
        $Major = $Version[0]
        $Minor = $Version[1] 
        $Build = "{0:00}" -f ([int]($Version[2] -split "_")[0] + 1)
        $Version = "$Major" + "." + "$Minor" + "." + "$Build"
    } else {
        $Version = $SimpleVersion
    }
    

    # Establish parameters for InstallShield command line
    $Installshieldstandalone = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "InstallShield\2021 SAB\System\IsCmdBld.exe"
    $Installshieldproject = Join-Path -Path $WorkingDirectory -ChildPath "Install\NEXiA.ism"
    $Installshieldmodulesi386 = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "InstallShield\2021 SAB\Modules\i386"
    $Installshieldobjects = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "InstallShield\2021 SAB\Objects"
    Start-Process -NoNewWindow -Wait -ErrorAction Stop -FilePath $Installshieldstandalone @("-p `"$Installshieldproject`" -e Y -r Release -l SourceRoot=`"$SourceRoot`" -o `"$Installshieldmodulesi386,$Installshieldobjects`" -y `"$Version`" -x")
}