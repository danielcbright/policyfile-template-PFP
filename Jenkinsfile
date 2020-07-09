def POLICY_NAME
def POLICY_ID

pipeline {
  agent any
  environment {
    HOME = "/root/"
  }
  stages {
    stage('Tests') {
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