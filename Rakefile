#
#  The various workspaces, schemes and destinations we test using
#

# Workspaces
CDTDATASTORE_WS = 'CDTDatastore.xcworkspace'
ENCRYPTION_WS = 'EncryptionTests/EncryptionTests.xcworkspace'
REPLICATION_ACCEPTANCE_WS = './ReplicationAcceptance/ReplicationAcceptance.xcworkspace'

# Schemes
TESTS_IOS = 'Tests iOS'
TESTS_OSX = 'Tests OSX'
ENCRYPTION_IOS = 'Encryption Tests'
ENCRYPTION_OSX = 'Encryption Tests OSX'
REPLICATION_ACCEPTANCE_IOS = 'RA_Tests'
REPLICATION_ACCEPTANCE_OSX = 'RA_Tests_OSX'
REPLICATION_ACCEPTANCE_ENCRYPTED_IOS = 'RA_EncryptionTests'
REPLICATION_ACCEPTANCE_ENCRYPTED_OSX = 'RA_EncryptionTests_OSX'

# Destinations
IPHONE_DEST = 'platform=iOS Simulator,OS=latest,name=iPhone 4S'
OSX_DEST = 'platform=OS X'

#
#  Primary tasks
#

desc "Run tests for all platforms"
task :test => [:testosx, :testios, :testencryptionosx, :testencryptionios] do
end

desc "Task for travis"
task :travis => [:test] do
  sh "pod lib lint --allow-warnings"
end

#
#  Update pods
#

desc "pod update all test projects"
task :podupdatetests do
  sh "for i in Tests EncryptionTests\ndo\ncd $i ; pod update ; cd ..\ndone"
end

desc "pod update all included projects"
task :podupdate => [:podupdatetests] do
  sh "for i in ReplicationAcceptance Project\ndo\ncd $i ; pod update ; cd ..\ndone"
end

#
#  Specific test tasks
#

desc "Run the CDTDatastore Tests for iOS"
task :testios do
  test(CDTDATASTORE_WS, TESTS_IOS, IPHONE_DEST)
end

desc "Run the CDTDatastore Tests for OS X"
task :testosx do
  test(CDTDATASTORE_WS, TESTS_OSX, OSX_DEST)
end

desc "Run the CDTDatastore Encryption Tests for iOS"
task :testencryptionios do
  test(ENCRYPTION_WS, ENCRYPTION_IOS, IPHONE_DEST)
end

desc "Run the CDTDatastore Encryption Tests for OS X"
task :testencryptionosx do
  test(ENCRYPTION_WS, ENCRYPTION_OSX, OSX_DEST)
end

desc "Run the replication acceptance tests for OS X"
task :replicationacceptanceosx do
  test(REPLICATION_ACCEPTANCE_WS, REPLICATION_ACCEPTANCE_OSX, OSX_DEST)
end

desc "Run the replication acceptance tests for iOS"
task :replicationacceptanceios do
  test(REPLICATION_ACCEPTANCE_WS, REPLICATION_ACCEPTANCE_IOS, IOS_DEST)
end

desc "Run the replication acceptance tests for OS X with encrypted datastores"
task :encryptionreplicationacceptanceosx do
  test(REPLICATION_ACCEPTANCE_WS, REPLICATION_ACCEPTANCE_ENCRYPTED_OSX, OSX_DEST)
end

desc "Run the replication acceptance tests for iOS with encrypted datastores"
task :encryptionreplicationacceptanceios do
  test(REPLICATION_ACCEPTANCE_WS, REPLICATION_ACCEPTANCE_ENCRYPTED_IOS, IOS_DEST)
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
  return system("xcodebuild -workspace #{workspace} -scheme '#{scheme}' -destination '#{destination}' test")
end

def test(workspace, scheme, destination)
  unless run_build(workspace, scheme, destination)
    fail "[FAILED] Build #{workspace}, #{scheme}"
  end
  unless run_tests(workspace, scheme, destination)
    fail "[FAILED] Tests #{workspace}, #{scheme}"
  end
end
