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
    lock('pod') {
        if(fileExists('Podfile.lock')) {
            sh "cd ${podfileDir} && pod update --verbose"
        } else {
            sh "cd ${podfileDir} && pod install --verbose"
        }
    }
}

def buildAndTest(nodeLabel, target, rakeEnv, encrypted) {
    node(nodeLabel) {
        // Unstash the source on this node
        unstash name: 'source'

        // Build and test
        try {
            def envVariables = ["${rakeEnv}=${env.DEST_PLATFORM}", "TEST_COUCH_HOST=cloudantsync002.bristol.uk.ibm.com", "TEST_COUCH_PORT=5984", "TEST_COUCH_HTTP=http"]
            if (encrypted == 'yes') {
                envVariables.add('encrypted=yes')
            }
            withEnv(envVariables) {
                // Install or update the pods
                if (target == 'sample') {
                    podfile('Project')
                } else {
                    podfile('.')
                }
                sh "rake ${target}"
            }
        } finally {
            // Load the test results
            junit 'build/reports/junit.xml'
            // Archive the complete log in case more debugging needed
            archiveArtifacts artifacts: '*CDTDatastoreTests*.log'
        }
    }
}

stage('Checkout') {
    // Checkout, build and assemble the source and doc
    node {
        checkout scm
        stash name: 'source'
    }
}

stage('BuildAndTest') {
    parallel(
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
        }
    )
}

// Publish the master branch
stage('Publish') {
    if (env.BRANCH_NAME == "master") {
        node {
            checkout scm // re-checkout to be able to git tag
            // read the version name and determine if it is a release build
            def versionFile = readFile('CDTDatastore/Version.h').trim()
            def versionMatcher = versionFile =~ /#define CLOUDANT_SYNC_VERSION \"(.*)\"/
            if (versionMatcher.matches()) {
              isReleaseVersion = !versionMatcher.group(1).toUpperCase(Locale.ENGLISH).contains("SNAPSHOT")

              // if it is a release build then do the git tagging
              if (isReleaseVersion) {

                  // Read the CHANGELOG.md to get the tag message
                  changes = """"""
                  changes += readFile('CHANGELOG.md')
                  tagMessage = """"""
                  for (line in changes.readLines()) {
                      if (!"".equals(line)) {
                          // append the line to the tagMessage
                          tagMessage = "${tagMessage}${line}\n"
                      } else {
                          break
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
}
