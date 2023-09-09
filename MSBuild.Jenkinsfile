pipeline {
    agent {
        label 'CDBUILD-WIN10'
    }
    parameters {
        choice choices: [], name: 'Product'
        choice choices: ['Test', 'Release'], name: 'BuildType'
    }
    triggers {
        parameterizedCron('''
            H 5 * * 1,3-5 % BuildType=Test
            H 3 * * 2 % BuildType=Release
        ''')
    }
    environment{
        Workdir = ""
    }
    stages {
        stage('Checkout'){
            steps {
                powershell '''
                    .\\PrepWork.ps1
                '''
            }
        }
        stage('Build') {
            steps {
                powershell '''
                New-PSDrive -Name "T" -Root "" -Persist -PSProvider "FileSystem" | Out-Null
                if (-not (Test-Path -Path p:)) {
                    subst p: 'C:\\Program Files (x86)\\PharmAssist'
                    test-path P:
                } Else {
                    Write-host "P is alread mapped"
                }
                    .\\msbuild.ps1
                '''
            }
        }
        stage('Packaging') {
            steps {
                checkout poll: false, scm: scmGit(branches: [[name: '*/main']], extensions: [], gitTool: 'Default', userRemoteConfigs: [[credentialsId: 'b4f5fc22-1fba-4f54-8424-2cce4d859463', url: 'https://iarx-services@dev.azure.com/iarx-services/NEXiA%20Deployment/_git/build-tools-installshield']])
                powershell '''
                . .\\InstallShieldScripts\\InstallShieldPackaging.ps1
                Start-PackagingNexia -WorkingDirectory "$($env:Workdir)" -BuildArchive "$($env:BuildArchive)"
                '''
                powershell '''
                . .\\InstallShieldScripts\\PackageRename.ps1
                Start-PackageRename -WorkingDirectory "$($env:Workdir)" -Product "$($env:Product)" -BuildArchive "$($env:BuildArchive)" -BuildNumber "$($env:BUILD_NUMBER)" -BuildType "$($env:BuildType)" -DevBuildOrMSBuild "MSBuild"
                '''
            }
        }
    }
}
