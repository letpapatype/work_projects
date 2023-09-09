<#

    .SYNOPSIS
    Simple script to rename the latest build to the proper version name.

    .EXAMPLE
    Start-PackageRename -WorkingDirectory "$($env:WorkingDirectory)" -Product "$($env:PRODUCT)" -BuildArchive "$($env:OutputDirectory)" -BuildNumber "$($env:BUILD_NUMBER)" -BuildType "$($env:BUILD_TYPE)" -DevBuildOrMSBuild "MSBuild"

    Without variables:
    Start-PackageRename -WorkingDirectory "C:\Workspace\Fulfillment 17.10 - Release" -Product "Fulfillment 17.10 - Release" -BuildArchive "T:\Engr\Soft\PharmASSIST CD Data\Symphony High Volume\NEXiA Fulfillment 17.10 - Test Only Builds" -IsRebuild $false -BuildNumber "3000" -BuildType "Test" -DevBuildOrMSBuild "DevBuild"
#>


Function Start-PackageRename{
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory=$true)]
        [string]$Product,
        [Parameter(Mandatory=$true)]
        [string]$BuildArchive,
        [Parameter(Mandatory=$true)]
        [string]$BuildNumber,
        [Parameter(Mandatory=$true)]
        [string]$BuildType,
        [Parameter(Mandatory=$true)]
        [string]$DevBuildOrMSBuild
    )

    # Programatically determine the latest version and establish the proper version name based on the most recent release build
    $SimpleVersion = ((Get-ChildItem -Directory $BuildArchive | Sort-Object LastWriteTime -Descending | Where-Object {$_.BaseName  -Match "\d\d.\d\d.\d\d"} | Select-Object -First 1) -split " ")[-1]
    $Version = $SimpleVersion -split "\."
    $Major = $Version[0]
    $Minor = $Version[1] 
    $Build = "{0:00}" -f ([int]($Version[2] -split "_")[0] + 1)
    $Version = "$Major" + "." + "$Minor" + "." + "$Build"

    $LatestVersion = $Version
    if ($BuildType -ne "Release") {
        $Baseline = (($Product -split " ")[1])
        $LatestVersion = "$Baseline" + "_" + "$DevBuildOrMSBuild" + "_" + "$BuildNumber"
    } 

    # Get the latest produced build and ensure it is a DoNotUse build
    $NewestBuild = Get-ChildItem -Directory $BuildArchive | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($NewestBuild -match 'DoNotUse') {
        Write-Host "$NewestBuild will be renamed to $LatestVersion..."
    } else {
        Write-Error "There was an error in packaging, a folder ending in DoNotUse was not found."
        Write-Output "The latest build is $NewestBuild"
        exit 1
    }

    # Rename the build directory to the proper version name for example: NEXiA Fulfillment 17.10.DoNotUse will be renamed to NEXiA Fulfillment 17.10.01
    $SimpleVersion = ($NewestBuild -split " ")[-1]
    $LatestBuildName = $NewestBuild -replace $SimpleVersion, $LatestVersion
    $OriginalDirName = Join-Path $BuildArchive -ChildPath $NewestBuild
    $NewDirName = Join-Path $BuildArchive -ChildPath $LatestBuildName
    if (Test-Path $NewDirName) {
        $RepackBuildDirName = $NewDirName + "_RP_BuildNumber_$($env:BUILD_NUMBER)"
        Rename-Item $OriginalDirName -NewName $RepackBuildDirName
        "The directory has been renamed to {0}" -f $RepackBuildDirName
    } else {
        Rename-Item $OriginalDirName -NewName $NewDirName
        "The directory has been renamed to {0}" -f $NewDirName
    }

    # Based on the build type, move the build to the proper location, for this example, if it is not a release build, the build will be moved to the Nightly Builds - Not for Test folder
    if ($BuildType -ne "Release") {
        Move-Item -Path $NewDirName -Destination "$BuildArchive\Nightly Builds - Not for Test" -Force
        $RelocatedBuild = Get-ChildItem -Directory "$BuildArchive\Nightly Builds - Not for Test" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Output "$($RelocatedBuild.FullName) if now ready in Nightly Builds - Not for Test"
    } else {
        $NewestBuild = (Get-ChildItem -Directory $BuildArchive | Sort-Object LastWriteTime -Descending | Where-Object {$_.BaseName  -Match "\d\d.\d\d.\d\d"} | Select-Object -First 1).FullName
        Write-Host "$NewestBuild is ready for testing!"
    }
}
