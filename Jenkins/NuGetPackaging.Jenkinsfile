// developing a pipeline with a stage to checkout the code from tfs, then a stage to build/package a nuget package, and a stage to publish the package to a nuget feed
pipeline {
    agent {
        label '*****'
    }
    parameters {
        string(name: 'Project', defaultValue: 'C:\\Workspace\\*****', description: 'The path to the project to build')
    }
    stages {
        stage('Checkout') {
            steps {
                powershell '''
                    tf get "$($env:Project)" /recursive /overwrite /noprompt
                    tf history "$($env:Project)" /noprompt /recursive /stopafter:1
                    '''
            }
        }
        stage('Build and Package') {
            steps {
                powershell '''
                    subst p: 'C:\\Program Files (x86)\\PharmAssist' | Out-Null
                    set-location "$($env:Project)"
                    $msbuild = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Professional\\MSBuild\\Current\\Bin"
                    nuget pack -SolutionDirectory ".\\PaRapidRx.sln" -MsBuildPath $msbuild -p Configuration=Release -Version "0.1.$($env:BUILD_NUMBER)" -Build -OutputDirectory "$($env:WORKSPACE)\\"
                '''
            }
        }
        stage('Publish'){
            steps {
                dotnetNuGetPush apiKeyId: 'ADO-ARTIFACTS-TOKEN', root: "${WORKSPACE}\\*.nupkg", source: 'https://pkgs.dev.azure.com/***/_packaging/****/nuget/v3/index.json'
            }
        }
    }
}