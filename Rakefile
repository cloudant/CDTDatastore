# Runs `build` target for workspace/scheme/destination
def run_build(workspace, scheme, destination)
  # build using xcpretty as otherwise it's very verbose when running tests
  $ios_success = system("xcodebuild -workspace #{workspace} -scheme '#{scheme}' -destination '#{destination}' build | xcpretty; exit ${PIPESTATUS[0]}")
  return $ios_success
end

# Runs `test` target for workspace/scheme/destination
def run_tests(workspace, scheme, destination)
  $ios_success = system("xcodebuild -workspace #{workspace} -scheme '#{scheme}' -destination '#{destination}' test")
  unless $ios_success
    puts "\033[0;31m! Unit tests failed with status code #{$?}"
  end
  return $ios_success
end

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

def test(workspace, scheme, destination)
  unless run_build(workspace, scheme, destination)
    fail "[FAILED] Build #{workspace}, #{scheme}"
  end
  unless run_tests(workspace, scheme, destination)
    fail "[FAILED] Tests #{workspace}, #{scheme}"
  end
end

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

desc "Run tests for all platforms"
task :test do
  sh "rake testios"
  sh "rake testosx"
  sh "rake testencryptionios"
  sh "rake testencryptionosx"
end

desc "Task for travis"
task :travis do
  sh "rake testios"
  sh "rake testosx"
  sh "rake testencryptionios"
  sh "rake testencryptionosx"
  sh "pod lib lint --allow-warnings"
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

desc "pod update all test projects"
task :podupdatetests do
  sh "for i in Tests EncryptionTests\ndo\ncd $i ; pod update ; cd ..\ndone"
end

desc "pod update all included projects"
task :podupdate => [:podupdatetests] do
  sh "for i in ReplicationAcceptance Project\ndo\ncd $i ; pod update ; cd ..\ndone"
end

desc "Build docs and install to Xcode"
task :docs do
  system("appledoc --keep-intermediate-files --project-name CDTDatastore --project-company Cloudant -o build/docs --company-id com.cloudant -i Classes/vendor -i Classes/common/touchdb Classes/")
end
