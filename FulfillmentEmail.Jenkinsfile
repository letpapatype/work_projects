pipeline{
    agent {
        label ''
    }
    triggers {
      cron 'H 8 * * 2'
    }
    // a parameter to set a Product
    parameters {
        string(name: 'Product', defaultValue: 'Fulfillment 17.11 - Release', description: 'Product to build')
    }
    environment {
        TFSPAT = credentials('TFS-WI-PAT')
    }
    stages {
        stage('Email'){
            steps{
                script{
                    nextBuild = powershell(returnStdout: true, script: '''
                        if (-not (Get-PSDrive T -ErrorAction SilentlyContinue)) {    
                            New-PSDrive -Name "T" -Root "\\\\iacolumbia\\ia" -Persist -PSProvider "FileSystem" | Out-Null
                        }
                        $SimpleVersion = ((Get-ChildItem -Directory $env:BuildArchive | Sort-Object LastWriteTime -Descending | Where-Object {$_.BaseName  -Match "\\d\\d.\\d\\d.\\d\\d"} | Select-Object -First 1) -split " ")[-1]
                        $Version = $SimpleVersion -split "\\."
                        $Major = $Version[0]
                        $Minor = $Version[1]
                        $Build = "{0:00}" -f ([int]($Version[2] -split "_")[0] + 1)
                        $Version = "$Major" + "." + "$Minor" + "." + "$Build"
                        $Version
                    ''')
                    htmlInformation = powershell(returnStdout: true, script: '.\\WorkItemStatusEmail.ps1')
                }
                mail bcc: '', body: """Hello,<br><br>
                Please ensure all code is working and checked in by midnight tonight. We will be begin building version <b>${nextBuild}</b> tomorrow.<br><br>
                ${htmlInformation}<br><br>
                Best, and happy developing!<br><br>
                Jenkins""", cc: '', from: 'Jenkins', mimeType: 'text/html', replyTo: '', subject: 'REMINDER: Fulfillment Weekly Build Notice', to: ''
                cleanWs()
            }
        }
    }
}