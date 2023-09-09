# HOWTO: For local testing, declare the following variables:
# $env:BuildType = "Test" ["Test" or "Release"], 
# $env:1709BuildArchive = "T:\Engr\Soft\PharmASSIST CD Data\Symphony High Volume\NEXiA Fulfillment 17.09 - Test Only Builds" to the path of Fulfillment "Test Build Only Folder", 
# $env:TFSWorkspace = "C:\Workspace"
# $env:Product = "Fulfillment 17.09 - Release"
# TODO: Unlock the branch after build
trap { $host.ui.WriteErrorLine($_.Exception); break }
# Ensure the script stops, and errors when running
$ErrorActionPreference = 'Stop'

# Declaring path variables to DRY out paths to solutions to build
$MSBuildPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe"
Set-Alias msBuild $MSBuildPath
$ProjectDirectory = Join-Path -Path $env:TFSWorkspace -ChildPath $env:Product
$NETInstalled = Join-Path $ProjectDirectory -ChildPath "Code\NET\Installed"
$VB6ProjectDirectory = Join-Path $ProjectDirectory -ChildPath "Code\VS6\Installed"
$HVReleaseIndependent = Join-Path -Path $env:SymphonyHVReleaseIndependent -ChildPath "Code\NET\Not Installed\Configuration"
$ReleaseIndependentDatabase = Join-Path -Path $env:SymphonyReleaseIndependent -Childpath "Code\Net\Not Installed"
$PaUpgradeDatabase = Join-Path $ReleaseIndependentDatabase -ChildPath "Database\PaUpgradeDatabase\PaUpgradeDatabase.sln"
$PaLoadDbObjects = Join-Path $ReleaseIndependentDatabase -ChildPath "Database\PaLoadDbObjects\PaLoadDbObjects.sln"
$PaUpdateEncryption = Join-Path $ReleaseIndependentDatabase -Childpath "Install Utilities\PaUpdateEncryption\PaUpdateEncryption.sln"
$PaLoadConfigParamDefs = Join-Path $HVReleaseIndependent -childpath "PaLoadConfigParamDefs\PaLoadConfigParamDefs.sln"
$PaLoadConfigParamVals = Join-Path $HVReleaseIndependent -Childpath "PaLoadConfigParamVals\PaLoadConfigParamVals.sln"

# Git committed txts that manage files to delete, GAC's to update, and CF VB6 projects to build
$VBProjectPath = Get-Content ".\Resources\VB6ProjectsPaths.txt"
$FilesToDelete = Get-Content ".\Resources\CFFilesToDelete.txt"
$NETProjectAssemblyFiles = Get-Content ".\Resources\CFAssemblyFiles.txt"

# Establish the lastest build version number by parsing it out of the last build on T, setting $Major, $Minor and $Build
Write-Host "Retrieving the most recent build number..."
$SimpleVersion = ((Get-ChildItem -Directory $env:BuildArchive | Sort-Object LastWriteTime -Descending | Where-Object {$_.BaseName  -Match "\d\d.\d\d.\d\d"} | Select-Object -First 1) -split " ")[-1]
Write-Host "$SimpleVersion is the latest build number"
if ($env:BuildType -eq "Release") {
    $Version = $SimpleVersion -split "\." 
    $Major = $Version[0]
    $Minor = $Version[1]
    $Build = "{0:00}" -f ([int]($Version[2] -split "_")[0] + 1)
    $Version = "$Major" + "." + "$Minor" + "." + "$Build"
    Write-Host "The new build number will be $Version"
} else {
    $Version = $SimpleVersion
    Write-Host "$env:BuildType build, sticking with version $Version"
}

# In release, the GAC's will be updated to the new build number, which is programmatically captured by querying the Test Build folder on T
function Start-NETVersionIncrease() {
    ForEach ($NETProjectAssemblyFile in $NETProjectAssemblyFiles) {   
        $NETProjectGAC = Join-Path -Path "$ProjectDirectory" -ChildPath $NETProjectAssemblyFile
        Set-ItemProperty -path $NETProjectGAC -Name IsReadOnly -Value $false -Force
        (Get-Content "$NETProjectGAC") -replace "\d\d.\d\d.\d\d.\d", "$Major.$Minor.$Build.0" | Set-Content $NETProjectGAC
    }
}

# All of the functionality happens in these 2 functions, Start-VB6Builds to run VB6 /Make against the declared Fulfillment VB6 projects.
# Pulls $Version into the ForEach loop, and updates the projects version IF the $env:BuildType is "Release"
function Start-VB6Builds() {
    trap { $host.ui.WriteErrorLine($_.Exception); break }
    ForEach ($project in $VBProjectPath) {
        $VB6Files = Join-Path -Path $VB6ProjectDirectory -ChildPath $project
        ForEach ($VB6File in $VB6Files) {
            Set-ItemProperty -path $VB6File -Name IsReadOnly -Value $false -Force
            if ($env:BuildType -eq "Release") {
                $VB6ToUpdate = Get-Content $VB6File
                $VB6ToUpdate -replace "MajorVer=\d\d", "MajorVer=$Major" | Set-Content $VB6File
                $VB6ToUpdate -replace "MinorVer=\d\d", "MinorVer=$Minor" | Set-Content $VB6File
                $VB6ToUpdate -replace "RevisionVer=\d\d", "RevisionVer=$Build" | Set-Content $VB6File
            }
            try {
                Write-Host "Building $VB6File"
                Start-Process -NoNewWindow -Wait -ErrorAction Stop -FilePath $env:VB6 -ArgumentList @("/MAKE `"$VB6File`"")
                Write-Host "$VB6File Build Complete"
            } catch {
                Write-Error "Build Failed: "
                Write-Error $_
            }
        }
    }  
}


# Funtion ensure's the solution is not READONLY, then calls MSBuild against the project passed in
function Start-MSBuild($solution) {
    Write-Output "Now building $solution..."
    msbuild $solution -t:$target -m:3 -p:Configuration=$BuildType -p:ContinueOnError=$ContinueOnError -clp:$DisplayErrorsOnly -v:m -restore
    Write-Output "$solution COMPLETE..."
}

# Set Start-MSBuild switch settings for initial build. PA needs to build and proceed to VB6 builds. Debug/Release will be 
# determined by the Jenkins parameter BuildType
$ContinueOnError = $true
$DisplayErrorsOnly = "ErrorsOnly"
$target ='rebuild'

if ($env:BuildType -eq "Release") {
    $BuildType = "Release"
    Start-NETVersionIncrease
    Write-Host "The .NET Assembly files have been updated to Version $Version"
} else {
    $BuildType = "Debug"
}



# Delete files from P using "Resources\CFFilestoDelete.txt" to prevent build errors
ForEach ($File in $FilesToDelete) {
    if (Test-Path $File -ErrorAction SilentlyContinue) {
        Remove-Item $File -Force
        Write-Output "$File was found, and deleted."
    } else {
        Write-Output "$File was not found."
    }
}

# Begin building
Start-MSBuild "$ProjectDirectory\PA.sln"

Write-Host "PA.sln complete, starting to build VB6 projects..."
Start-VB6Builds
Write-Host "VB6 projects are complete. Building PA.sln again..."

# Update the MSBuild switch variables to stop the script on failure
$ContinueOnError = "ErrorAndStop"
$DisplayErrorsOnly = "Summary"

Start-MSBuild "$ProjectDirectory\PA.sln"

Start-MSBuild "$NETInstalled\Reports\BuildNETReports.sln" 

Start-MSBuild "$NETInstalled\DLLs\PaNetUiForms\PaNetUiForms.sln" 

Start-MSBuild $PaUpgradeDatabase

Start-MSBuild $PaLoadDbObjects

Start-MSBuild $PaUpdateEncryption

Start-MSBuild $PaLoadConfigParamDefs

Start-MSBuild $PaLoadConfigParamVals

if ($env:BuildType -eq 'Test'){
    Copy-Item -Path "" -Destination "P:\" -Force
    Write-Output "Copied Interop.PaPmssInterface.dll from the Debug output folder to P."
} else {
    Copy-Item -Path "" -Destination "P:\" -Force
    Write-Output "Copied Interop.PaPmssInterface.dll from the Release output folder to P."
}

Write-Output "Build Complete!"