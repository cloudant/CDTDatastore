#
#  The various workspaces, schemes and destinations we test using
#

# Workspaces
CDTDATASTORE_WS = 'CDTDatastore.xcworkspace'
SAMPLE_APP_WS = 'Project/Project.xcworkspace'

# Schemes
TESTS_IOS = 'CDTDatastoreTests'
TESTS_OSX = 'CDTDatastoreTestsOSX'
ENCRYPTION_IOS = 'CDTDatastoreEncryptionTests'
ENCRYPTION_OSX = 'CDTDatastoreEncryptionTestsOSX'
REPLICATION_ACCEPTANCE_IOS = 'CDTDatastoreReplicationAcceptanceTests'
REPLICATION_ACCEPTANCE_OSX = 'CDTDatastoreReplicationAcceptanceTestsOSX'
REPLICATION_ACCEPTANCE_ENCRYPTED_IOS = 'CDTDatastoreEncryptedReplicationAcceptanceTests'
REPLICATION_ACCEPTANCE_ENCRYPTED_OSX = 'CDTDatastoreEncryptedReplicationAcceptanceTestsOSX'
SAMPLE_IOS = "Project"


# Destinations
IPHONE_DEST = 'platform=iOS Simulator,OS=latest,name=iPhone 5'
OSX_DEST = 'platform=OS X'

#
#  Primary tasks
#

desc "Run tests for all platforms"
task :test => [:testios, :testosx, :testencryptionios, :testencryptionosx] do
end

desc "Task for travis"
task :travis => [:test, :sample] do
  sh "pod lib lint --allow-warnings --verbose | xcpretty; exit ${PIPESTATUS[0]}"
end

#
#  Update pods
#

desc "pod update"
task :podupdatetests do
  sh "pod _1.0.1_ update"
end

desc "pod update"
task :podupdate => [:podupdatetests] do
end

# Sample build task
desc "Build sample iOS application"
task :sample do
    run_build(SAMPLE_APP_WS,SAMPLE_IOS,IPHONE_DEST)
end

#
#  Specific test tasks
#

desc "Run the CDTDatastore Tests for iOS"
task :testios do
  if (ENV["PLATFORM"] == nil || ENV["PLATFORM"] == "iOS")
    test(CDTDATASTORE_WS, TESTS_IOS, IPHONE_DEST)
  end
end

desc "Run the CDTDatastore Tests for OS X"
task :testosx do
  if (ENV["PLATFORM"] == nil || ENV["PLATFORM"] == "OSX")
    test(CDTDATASTORE_WS, TESTS_OSX, OSX_DEST)
  end
end

desc "Run the CDTDatastore Encryption Tests for iOS"
task :testencryptionios do
  if (ENV["PLATFORM"] == nil || ENV["PLATFORM"] == "iOS-encrypted")
    test(CDTDATASTORE_WS, ENCRYPTION_IOS, IPHONE_DEST)
  end
end

desc "Run the CDTDatastore Encryption Tests for OS X"
task :testencryptionosx do
  if (ENV["PLATFORM"] == nil || ENV["PLATFORM"] == "OSX-encrypted")
    test(CDTDATASTORE_WS, ENCRYPTION_OSX, OSX_DEST)
  end
end

desc "Run the replication acceptance tests for OS X"
task :replicationacceptanceosx do
  test(CDTDATASTORE_WS, REPLICATION_ACCEPTANCE_OSX, OSX_DEST)
end

desc "Run the replication acceptance tests for iOS"
task :replicationacceptanceios do
  test(CDTDATASTORE_WS, REPLICATION_ACCEPTANCE_IOS, IOS_DEST)
end

desc "Run the replication acceptance tests for OS X with encrypted datastores"
task :encryptionreplicationacceptanceosx do
  test(CDTDATASTORE_WS, REPLICATION_ACCEPTANCE_ENCRYPTED_OSX, OSX_DEST)
end

desc "Run the replication acceptance tests for iOS with encrypted datastores"
task :encryptionreplicationacceptanceios do
  test(CDTDATASTORE_WS, REPLICATION_ACCEPTANCE_ENCRYPTED_IOS, IOS_DEST)
end

#
#  Update docs
#

desc "Build docs and install to Xcode"
task :docs do
  system("appledoc --keep-intermediate-files --project-name CDTDatastore --project-company Cloudant -o build/docs --company-id com.cloudant -i Classes/vendor -i Classes/common/touchdb Classes/")
end

#
#  Helper methods
#

# Runs `build` target for workspace/scheme/destination
def run_build(workspace, scheme, destination)
  # build using xcpretty as otherwise it's very verbose when running tests
  return system("xcodebuild -workspace #{workspace} -scheme '#{scheme}' -destination '#{destination}' build | xcpretty; exit ${PIPESTATUS[0]}")
end

# Runs `test` target for workspace/scheme/destination
def run_tests(workspace, scheme, destination)
  return system("xcodebuild -verbose -workspace #{workspace} -scheme '#{scheme}' -destination '#{destination}' test | xcpretty; exit ${PIPESTATUS[0]}")
end

def test(workspace, scheme, destination)
  unless run_tests(workspace, scheme, destination)
    fail "[FAILED] Tests #{workspace}, #{scheme}"
  end
end
