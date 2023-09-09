pipeline {
    agent {
        label 'CDBUILD2WIN10VM'
    }
    parameters {
        string(name: 'BUILD_TYPE', defaultValue: 'ReleaseNoVersionInc', description: 'The type of build to perform')
        string(name: 'PRODUCT', defaultValue: '', description: 'The type of build to perform')
        booleanParam(name: 'IS_REBUILD', defaultValue: false, description: 'Are we rebuilding a RELEASE build?')
    }
    // This job is scheduled to run Mon-Wed and Friday as a Release test build, with a release and version increment build running on Thursdays. 4AM EST is the current build time.
    triggers {
        parameterizedCron('''
            H 5 * * 1-2,4-5 % BUILD_TYPE=ReleaseNoVersionInc
            H 5 * * 3 % BUILD_TYPE=Release
        ''')
    }
    options {
        timestamps()
    }
    environment {
        Workdir = "$TFSWorkspace\\" + "$PRODUCT"
        TEAMS = credentials('TEAMS_URL')
        pat = credentials('TFS-WI-PAT')
    }
    stages {
        // The prep stage ensures mapping, get's latest and ensures the proper baseline is installed ex.'17.10'
        // Upon failure, an email will be sent to the SWDev Managers for assessment
        stage('Build Prep') {
            steps {
                powershell'''
                    Set-Alias TF.exe "$env:TF17"
                    $Projects = @($($env:Workdir),
                        $($env:SymphonyHVReleaseIndependent),
                        $($env:SymphonyHV),
                        $($env:SymphonyReleaseIndependent),
                        $($env:StandAlone),
                        $($env:ThirdParty),
                        $($env:BuildUtils),
                        $($env:InstallUtils))
                    foreach ($Project in $Projects) {
                        TF.exe get "$Project" /recursive /overwrite /noprompt
                        Write-Output "$Project has been updated"
                        TF.exe history "$Project" /noprompt /recursive /stopafter:5
                    }
                '''
            }
        }
        // Build procedure for NEXiA
        stage('Building') {
            steps {
                bat'''
                CD "%Workdir%\\BuildUtils"
                call Build.bat %BUILD_TYPE%
                '''
            }
            post {
                failure {
                    mail bcc: '', body: """Good Morning, <br><br>
                    Today's build for ${PRODUCT} has failed. To review the Console Log and assess the issue, please <a href='${RUN_DISPLAY_URL}'>Click Here</a>. You can parse the Console log by searching (ctrl+f) "<b>ERROR(s) shown below</b>."<br><br>
                    To contact the Build Team, simply reply to this email.<br><br>
                    Thank you,<br>
                    Jenkins""", cc: '', from: 'Jenkins', mimeType: 'text/html', replyTo: '', subject: "Build Errors - ${Product}", to: ''
                }
            }
        }
        // Installshield phase, packaging and producing the MSI to T. Then PackageRename changes the produced directory name to either the current release build # or dev build #
        stage('Packaging') {
            when {
                anyOf {
                    environment name: 'BUILD_TYPE', value: 'Release'
                    environment name: 'BUILD_TYPE', value: 'ReleaseNoVersionInc'
                }
            }
            steps {
                powershell '''
                .\\Scripts\\InstallShield.ps1
                '''
                powershell '''
                .\\Scripts\\PackageRename.ps1
                '''
            }
        }
        // The last stage of the build is a python tool to query work item, list them with their url, and update the state of code reviewed items to ready to test with the updated test build #
        // Also, an email will also be sent out to with the location of the build upon success
        stage('Release Notifications') {
            when {
                anyOf {
                    environment name: 'BUILD_TYPE', value: 'Release'
                    environment name: 'IS_REBUILD', value: 'true'
                }
            }
            steps{
                powershell'Write-Output "Skipping Automated Work Item updates this week for further development"'
            }
            post{
                success {
                    script {
                        mostRecentRelease = powershell(returnStdout: true, script: '''
                        New-PSDrive -Name "T" -Root "\\\\iacolumbia\\ia" -Persist -PSProvider "FileSystem" -ErrorAction SilentlyContinue | Out-Null
                        $MostRecentReleaseBuild = (Get-ChildItem -Directory $env:BuildArchive | Sort-Object LastWriteTime -Descending | Where-Object {$_.BaseName  -Match "\\d\\d.\\d\\d.\\d\\d"} | Select-Object -First 1)
                        $MostRecentReleaseBuild.FullName
                        ''')
                        releaseNumber = powershell(returnStdout: true, script: '''
                        New-PSDrive -Name "T" -Root "\\\\iacolumbia\\ia" -Persist -PSProvider "FileSystem" -ErrorAction SilentlyContinue | Out-Null
                        $MostRecentReleaseBuild = (Get-ChildItem -Directory $env:BuildArchive | Sort-Object LastWriteTime -Descending | Where-Object {$_.BaseName  -Match "\\d\\d.\\d\\d.\\d\\d"} | Select-Object -First 1)
                        (($MostRecentReleaseBuild.Name) -split " ")[-1]
                        ''')
                    }
                    mail bcc: '', body: """Good Morning, <br><br>
                    The weekly Release build is complete and published to: <b>${mostRecentRelease}</b>.<br><br>
                    To view the build Console Log and Work Item status: <a href='${RUN_DISPLAY_URL}'>Click Here</a>.<br><br>
                    If there are any questions, please reply to this email to contact the Build Team.<br><br>
                    Thank You,<br>
                    Jenkins""", cc: '', from: 'Jenkins', mimeType: 'text/html', replyTo: 'BuildTeam@iarx.com', subject: "Fulfillment ${releaseNumber} is complete and ready for install", to: '_softtesthv@innovationassociates.onmicrosoft.com, buildteam@iarx.com'
                }
            }
        }
    }
    // Upon success, a Teams message is posted with the file path for the new build, along with the link to the blue ocean build console
    // Upon failure, a failure notice is sent with the blue ocean console URL
    // The cloned directory where the build files are cloned to is deleted post build as a new copy is cloned down every build.
    post {
        success {
            powershell '.\\Scripts\\TeamsNotification.ps1'
            cleanWs()
        }
        failure {
            powershell '.\\Scripts\\TeamsFailure.ps1'
            cleanWs()
        }
    }
}
