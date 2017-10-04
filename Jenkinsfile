#!groovy

/*
 * Copyright © 2016 IBM Corp. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the
 * License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
 * either express or implied. See the License for the specific language governing permissions
 * and limitations under the License.
 */

def podfile(podfileDir) {
    // Lock the pod repo and update the pod

    // Note that each macOS host has a podfile so there is one Jenkins lock
    // available per host. Nodes are named as nodeHost-executorEnv so we use the
    // part of the node name before the - to identify the pod lock.

    lock("${env.NODE_NAME.split('-')[0]}pod") {
        if(fileExists('Podfile.lock')) {
            sh "cd ${podfileDir} && pod update --verbose"
        } else {
            sh "cd ${podfileDir} && pod install --verbose"
        }
    }
}

def buildAndTest(nodeLabel, target, rakeEnv, encrypted) {
    node(nodeLabel) {
        // Clean the directory before un-stashing (removes old logs)
        deleteDir()

        // Unstash the source on this node
        unstash name: 'source'

        // Build and test
        try {
            def envVariables = ["${rakeEnv}=${env.DEST_PLATFORM}", "TEST_COUCH_HOST=cloudantsync002.bristol.uk.ibm.com", "TEST_COUCH_PORT=5984", "TEST_COUCH_HTTP=http", "TEST_COUCH_N_DOCS=10", "TEST_COUCH_LARGE_REV_TREE_SIZE=10"]
            if (encrypted == 'yes') {
                envVariables.add('encrypted=yes')
            }
            withEnv(envVariables) {
                withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'couchdb', usernameVariable: 'TEST_COUCH_USERNAME', passwordVariable: 'TEST_COUCH_PASSWORD']]) {
                    // Install or update the pods
                    if (target == 'sample') {
                        podfile('Project')
                    } else {
                        podfile('.')
                    }
                    sh "rake ${target}"
                }
            }
        } finally {
            // Note the sample build has no junit results or CDT*.log
            if (target != 'sample') {
                // Load the test results
                junit 'build/reports/junit.xml'
                // Archive the complete log in case more debugging needed
                archiveArtifacts artifacts: '*CDTDatastore*.log'
            }
        }
    }
}

def buildAndIamTest(nodeLabel, target, rakeEnv, encrypted) {
    node(nodeLabel) {
        // Clean the directory before un-stashing (removes old logs)
        deleteDir()

        // Unstash the source on this node
        unstash name: 'source'

        // Build and test
        try {
            def envVariables = ["${rakeEnv}=${env.DEST_PLATFORM}", "TEST_COUCH_HOST=clientlibs-test.cloudant.com", "TEST_COUCH_PORT=443", "TEST_COUCH_HTTP=https", "TEST_COUCH_N_DOCS=10", "TEST_COUCH_LARGE_REV_TREE_SIZE=10"]
            if (encrypted == 'yes') {
             envVariables.add('encrypted=yes')
            }
            withEnv(envVariables) {
                withCredentials([usernamePassword(credentialsId: 'clientlibs-test', usernameVariable: 'TEST_COUCH_USERNAME', passwordVariable: 'TEST_COUCH_PASSWORD'), string(credentialsId: 'clientlibs-test-iam', variable: 'TEST_COUCH_IAM_API_KEY')]) {
                 // Install or update the pods
                    if (target == 'sample') {
                        podfile('Project')
                    } else {
                        podfile('.')
                    }
                    sh "rake ${target}"
                }
            }
        } finally {
            // Note the sample build has no junit results or CDT*.log
            if (target != 'sample') {
                // Load the test results
                junit 'build/reports/junit.xml'
                // Archive the complete log in case more debugging needed
                archiveArtifacts artifacts: '*CDTDatastore*.log'
            }
        }
    }
}

@NonCPS
def getVersion(versionFile) {
  def versionMatcher = versionFile =~ /#define CLOUDANT_SYNC_VERSION "(.*)"/
  return versionMatcher[0][1]
}

def isReleaseVersion(version) {
  return !version.toUpperCase(Locale.ENGLISH).contains("SNAPSHOT")
}

stage('Checkout') {
    // Checkout, build and assemble the source and doc
    node {
        checkout scm
        stash name: 'source'
    }
}

stage('BuildAndTest') {
    def axes = [
            ios: {
                buildAndTest('ios', 'testios', 'IPHONE_DEST', 'no')
                buildAndTest('ios', 'sample', 'IPHONE_DEST', 'no')
            },
            iosEncrypted: {
                buildAndTest('ios', 'testios', 'IPHONE_DEST', 'yes')
            },
            macos: {
                buildAndTest('macos', 'testosx', 'OSX_DEST', 'no')
            },
            macosEncrypted: {
                buildAndTest('macos', 'testosx', 'OSX_DEST', 'yes')
            }]
    def iamAxes = []
    // Add replication acceptance tests for the master branch
    if (env.BRANCH_NAME == "master" || env.BRANCH_NAME == "iam-testing") {
        axes.putAll(
            iosRAT: {
                buildAndTest('ios', 'replicationacceptanceios', 'IPHONE_DEST', 'no')
            },
            iosRATEncrypted: {
                buildAndTest('ios', 'replicationacceptanceios', 'IPHONE_DEST', 'yes')
            },
            macosRAT: {
                buildAndTest('macos', 'replicationacceptanceosx', 'OSX_DEST', 'no')
            },
            macosRATEncrypted: {
                buildAndTest('macos', 'replicationacceptanceosx', 'OSX_DEST', 'yes')
            })
            // Run IAM iOS RA test
            buildAndIamTest('ios', 'replicationacceptanceios', 'IPHONE_DEST', 'no')

    }
    parallel(axes)
    
}

// Publish the master branch
stage('Publish') {
    if (env.BRANCH_NAME == "master") {
        node {
            checkout scm // re-checkout to be able to git tag

            // read the version string
            def versionFile = readFile('CDTDatastore/Version.h').trim()
            def version = getVersion(versionFile)

            // if it is a release build then do the git tagging
            if (isReleaseVersion(version)) {

                def inMessage = false
                // Read the CHANGELOG.md to get the tag message
                tagMessage = ''
                // find the message following the first "##" header
                for (line in readFile('CHANGELOG.md').readLines()) {
                    if (line =~ /^##/) {
                        if (!inMessage) {
                            inMessage = true
                            continue
                        } else {
                            break
                        }
                    }
                    if (inMessage) {
                        // append the line to the tagMessage
                        tagMessage = "${tagMessage}${line}\n"
                    }
                }

                // Use git to tag the release at the version
                try {
                    // Awkward workaround until resolution of https://issues.jenkins-ci.org/browse/JENKINS-28335
                    withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'github-token', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']]) {
                        sh "git config user.email \"nomail@hursley.ibm.com\""
                        sh "git config user.name \"Jenkins CI\""
                        sh "git config credential.username ${env.GIT_USERNAME}"
                        sh "git config credential.helper '!echo password=\$GIT_PASSWORD; echo'"
                        sh "git tag -a ${version} -m '${tagMessage}'"
                        sh "git push origin ${version}"
                    }
                } finally {
                    sh "git config --unset credential.username"
                    sh "git config --unset credential.helper"
                }
            }
        }
    }
}
