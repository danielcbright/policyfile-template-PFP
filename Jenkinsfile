def PUB_POLICY_JSON
def FIRST_POLICY_GROUP
def POLICY_NAME
def POLICY_ID
def CREATE_PR_BOOL = "false"
def UPDATED_POLICY_LOCKS

pipeline {
  agent any
  triggers {
    // Run every 30 minutes, M-F
    cron('H/30 * * * 1-5')
  }
  environment {
    HOME = "/root/"
  }
  stages {
    stage('Master triggered by CRON'){
      agent any
      when {
             branch 'master'
           }
      steps {
        wrap([$class: 'ChefIdentityBuildWrapper', jobIdentity: 'jenkins-dbright']) {
          echo "INFO: I'm running this stage based on a CRON trigger, this means I am going to<br>do 2 things:<br>1. I will check if any policies I depend on have new ID's<br>2. If they have new ID's, I will create a PR to build a new Policyfile, else I'll stop<br>because I'm running from MASTER and no changes should be pushed directly to MASTER."
          script {
            def jsonString = sh (
              script: """
              LOCAL_CMD=`cat Policyfile.rb | grep "name\\s*'" | sed -E "s/^name '(.*)'.*/chef show-policy \\1/"`
              LOCAL_CMD="\$LOCAL_CMD `cat policy_groups.txt | head -n 1 | awk -F'[ :]' '{print \$1}'`"
              eval \$LOCAL_CMD
              """,
              returnStdout: true
            ).trim()
            PUB_POLICY_JSON = readJSON text: jsonString
          }
          script {
            for ( POLICY_LOCK in PUB_POLICY_JSON.included_policy_locks ) {
              def jsonString = sh (
                script: "/opt/chef-workstation/bin/chef show-policy ${POLICY_LOCK.source_options.policy_name} ${POLICY_LOCK.source_options.policy_group}",
                returnStdout: true
              ).trim()
              def POLICY_LOCK_JSON = readJSON text: jsonString
              if ( POLICY_LOCK_JSON.revision_id == POLICY_LOCK.source_options.policy_revision_id ) {
                echo "Included Policy Lock ${POLICY_LOCK.source_options.policy_name} has the same revision_id as what is already currently deployed, no change."
                echo "${POLICY_LOCK_JSON.revision_id} = ${POLICY_LOCK.source_options.policy_revision_id}"
              } else {
                echo "Included Policy Lock ${POLICY_LOCK.source_options.policy_name} has a differing revision_id than what is currently deployed, change detected."
                echo "Creating PR to merge new upstream Policies.."
                if (UPDATED_POLICY_LOCKS) {
                  UPDATED_POLICY_LOCKS = "${UPDATED_POLICY_LOCKS} ${POLICY_LOCK.source_options.policy_name}:${POLICY_LOCK.source_options.policy_revision_id}"
                } else {
                  UPDATED_POLICY_LOCKS = "${POLICY_LOCK.source_options.policy_name}:${POLICY_LOCK.source_options.policy_revision_id}"
                }
                CREATE_PR_BOOL = "true"
              }
            }
          }
        }
      }
    }
    stage('Create PR to merge upstream policy locks') {
      when {
        allOf {
          branch 'master'
          expression { CREATE_PR_BOOL == "true" }
        }
      }
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: 'jenkins-pr', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
            env.GITHUB_TOKEN = "$PASSWORD"
            env.USERNAME = "$USERNAME"
          }
          delBranches = sh (
            script: 'git branch | grep -v "master" || echo "No branches to clean up..."',
            returnStdout: true
          ).trim()
          dateStamp = sh (
            script: 'date "+%Y%m%d%H%M%S%N"',
            returnStdout: true
          ).trim()
          gitUrl = sh (
            script: 'git config remote.origin.url | sed -E "s/^.*\\/\\/(.*)$/\\1/"',
            returnStdout: true
          ).trim()
          if (delBranches != "No branches to clean up...") {
            sh "git branch -D ${delBranches}"
          }
        }
        sh "git remote rm origin"
        sh "git config --global user.name \"Jenkins\"; git config --global user.email jenkins@dbright.io"
        sh "git remote add origin https://$USERNAME:$GITHUB_TOKEN@${gitUrl}"
        sh "git checkout -b JenkinsAutoUpdate-${dateStamp}"
        sh 'git status'
        sh "touch .autoupdate; echo \"${UPDATED_POLICY_LOCKS}\" >> .autoupdate"
        sh 'git add .autoupdate'
        sh "git commit -m \"[Jenkins] updating file .autoupdate due to policy include upstream changes detected\""
        sh "git push --set-upstream origin JenkinsAutoUpdate-${dateStamp}"
        sh "/usr/local/bin/hub pull-request -m \"[Jenkins] Auto Updater\" -m \"Updating: A Jenkins Automated Build Job ($BUILD_URL) detected changes in upstream policy locks (${UPDATED_POLICY_LOCKS}), this PR is to rebuild this policy and include those new policy locks. \""
      }
    }
    stage('Tests') {
      when {
        not {
          branch 'master'
        }
      }
      steps {
        withAWS(credentials: 'aws-policyfile-archive', region: 'us-east-1') {
          wrap([$class: 'ChefIdentityBuildWrapper', jobIdentity: 'jenkins-dbright']) {
            sh "/opt/chef-workstation/bin/cookstyle ."
            // sh "/opt/chef-workstation/bin/kitchen test"
            fileExists 'policy_groups.txt'
            fileExists 'Policyfile.rb'
          }
        }
      }
    }
    stage('Build Policyfile Archive (.tgz)') {
      when {
        not {
          branch 'master'
        }
      }
      steps {
        wrap([$class: 'ChefIdentityBuildWrapper', jobIdentity: 'jenkins-dbright']) {
          sh "/opt/chef-workstation/bin/chef install"
          script {
            // Let's use system commands to get values to avoid using @NonCPS (thus making our pipeline serializable)
            // We'll get the Policy information here to use in further steps
            POLICY_ID = sh (
              script: '/opt/chef-workstation/bin/chef export Policyfile.lock.json ./output -a | sed -E "s/^Exported policy \'(.*)\' to.*\\/.*-(.*)\\.tgz$/\\2/"',
              returnStdout: true
            ).trim()
            POLICY_NAME = sh (
              script: "ls ./output/*$POLICY_ID* | sed -E \"s/.*\\/(.*)-.*\$/\\1/\"",
              returnStdout: true
            ).trim()
          }
          // Get rid of the Policyfile.lock.json for future runs
          sh "rm Policyfile.lock.json"
          sh "mkdir to_upload"
          sh "cp ./output/*$POLICY_ID* ./to_upload/; cp ./policy_groups.txt ./to_upload/"
        }
        echo "${POLICY_ID}"
        echo "${POLICY_NAME}"
      }
    }
    stage('Upload Policyfile Archive to Remote Storage in AWS/GCP/Azure') {
      when {
        not {
          branch 'master'
        }
      }
      parallel {
        stage('Upload to GCS') {
          steps {
            dir("to_upload") {
              // GCS
              googleStorageUpload(credentialsId: 'gcs-policyfile-archive', bucket: "gs://policyfile-archive/$POLICY_NAME/$POLICY_ID/", pattern: "*.*")
            }
          }
        }
        stage('Upload to S3') {
          steps {
            dir("to_upload") {
              // S3
              withAWS(credentials: 'aws-policyfile-archive', region: 'us-east-1') {
                s3Upload(bucket: 'dcb-policyfile-archive', path: "$POLICY_NAME/$POLICY_ID/", includePathPattern: '*.*')
              }            
            }
          }
        }
        stage('Upload to Azure') {
          steps {
            dir("to_upload") {
              // Azure Storage
              azureUpload(storageCredentialId: 'fbc18e3a-1207-4a90-9f29-765a8b88ac86', filesPath: "*.*", storageType: 'FILE_STORAGE', containerName: 'policyfile-archive', virtualPath: "$POLICY_NAME/$POLICY_ID/" )   
            }
          }
        }
      }
    }
    stage('Kick off Publish Job') {
      when {
        not {
          branch 'master'
        }
      }
      steps {
        build job: 'policyfile-publish-PFP/master', propagate: false, wait: false,
          parameters: [
              string(name: 'POLICY_NAME', value: String.valueOf(POLICY_NAME)),
              string(name: 'POLICY_ID', value: String.valueOf(POLICY_ID))
          ]
      }
    }
  }
  post { 
    always { 
      cleanWs()
    }
  }
}