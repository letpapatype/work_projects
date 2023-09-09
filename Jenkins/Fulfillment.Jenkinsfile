pipeline {
    agent {
        label ''
    }
    parameters {
        choice choices: ['Release', 'Test', 'ReleaseNoVersionInc'], description: '''Test = Debug build
        Release = Release build, with a version increment
        ReleaseNoVersionInc = Release build that does not increase the version
        ''', name: 'BuildType'
    }
    environment {
        Workdir = "C:\\Workspace\\"
        TEAMS = credentials('TEAMS_URL')
    }
    stages {
        stage('Build Prep') {
            steps {
                bat'''
                CD "%Workdir%\\BuildUtils"
                call BuildPrep.bat
                '''
            }
        }
        stage('Building') {
            steps {
                bat'''
                CD "%Workdir%\\BuildUtils"
                call Build.bat %Buildtype%
                '''
            }
        }
        stage('Packaging') {
            when {
                anyOf {
                    environment name: 'BuildType', value: 'Release'
                    environment name: 'BuildType', value: 'ReleaseNoVersionInc'
                }
            }
            steps {
                powershell '''
                if (-not (Get-PSDrive T -ErrorAction SilentlyContinue)) {
                    New-PSDrive -Name "T" -Root "\\\\iacolumbia\\ia" -Persist -PSProvider "FileSystem"
                }
                $Installshieldstandalone = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "InstallShield\\2021 SAB\\System\\IsCmdBld.exe"
                $Installshieldproject = Join-Path -Path $env:Workdir -ChildPath "Install\\NEXiA.ism"
                $Installshieldmodulesi386 = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "InstallShield\\2021 SAB\\Modules\\i386"
                $Installshieldobjects = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "InstallShield\\2021 SAB\\Objects"
                $Buildversion = Join-Path -Path $env:Workdir -ChildPath "BuildUtils\\LastVersionNumber.txt"
                $Latestversion = (Get-Content -Path $Buildversion)
                Start-Process -NoNewWindow -Wait -FilePath $Installshieldstandalone @("-p `"$Installshieldproject`" -e Y -r Release -o `"$Installshieldmodulesi386,$Installshieldobjects`" -y `"$Latestversion`"")
                '''
                powershell '''
                $LatestVersion = Get-Content "$env:Workdir\\BuildUtils\\LastVersionNumber.txt"
                $1709BuildArchive = $($env:1709BuildArchive)
                $NewestBuild = Get-ChildItem -Directory $1709BuildArchive | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Host "$NewestBuild will be renamed..."
                $SimpleVersion = ($NewestBuild -split " ")[-1]
                $LatestBuildName = $NewestBuild -replace $SimpleVersion, $LatestVersion
                $OriginalDirName = Join-Path $1709BuildArchive -ChildPath $NewestBuild
                $NewDirName = Join-Path $1709BuildArchive -ChildPath $LatestBuildName
                if (Test-Path $NewDirName) {
                    $RepackBuildDirName = $NewDirName + "_RP$($env:BUILD_NUMBER)"
                    Rename-Item $OriginalDirName -NewName $RepackBuildDirName
                }
                else {
                    Rename-Item $OriginalDirName -NewName $NewDirName
                }
                $NewestBuild = Get-ChildItem -Directory $1709BuildArchive | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Host "$NewestBuild is ready for testing!"
                '''
            }
        }
    }
    post {
        success {
            powershell '''
            $1709BuildArchive = $($env:1709BuildArchive)
            $NewestBuild = Get-ChildItem -Directory $1709BuildArchive | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $TEAMS = $($env:TEAMS)
            $NewestBuildLocation = Join-Path $1709BuildArchive -ChildPath $NewestBuild

            [System.Collections.Generic.List[PSObject]] $BotBuilder = @()
            $BotBuilder.Add(@{
                    '@type'           = 'Message Card'
                    '@context'        = 'http://schema.org/extensions'
                    'themeColor'      = '00b300'
                    'summary'         = 'Jenkins Build Completion'
                    'sections'        = @(
                        @{
                            'activityTitle'    = 'Jenkins has completed a build.'
                            'activitySubtitle' = 'Please review the build, and proceed accordingly.'
                            'activityImage'    = 'https://iarx.com/wp-content/uploads/iarx-logo.png'
                            'facts'            = @(
                                @{
                                    'name'  = 'Build'
                                    'value' = $($env:BuildType)
                                }
                                @{
                                    'name'  = 'Build Status'
                                    'value' = 'Successful'
                                }
                                @{
                                    'name'  = 'File location'
                                    'value' = $NewestBuildLocation
                                }
                            )
                            'markdown'         = 'true'
                        }
                    )
                    'potentialAction' = @(
                        @{
                            '@type'   = 'OpenUri'
                            'name'    = 'View Build'
                            'targets' = @(
                                @{
                                    'os'  = 'default'
                                    'uri' = $($env:BUILD_URL)
                                }
                            )
                        }
                    )
            })
            $TeamsBot = ".\\Bot.json"
            $BotBuilder | ConvertTo-Json -Depth 10 | Out-File $TeamsBot -Encoding UTF8
            $Script = Get-Content -Path $TeamsBot
            Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $Script -Uri $TEAMS
            '''
        }
    }
}
