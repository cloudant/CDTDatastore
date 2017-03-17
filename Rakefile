#
#  The various workspaces, schemes and destinations we test using
#

# Workspaces
CDTDATASTORE_WS = 'CDTDatastore.xcworkspace'
SAMPLE_APP_WS = 'Project/Project.xcworkspace'

# Schemes
TESTS_IOS = 'CDTDatastoreTests'
TESTS_OSX = 'CDTDatastoreTestsOSX'
REPLICATION_ACCEPTANCE_IOS = 'CDTDatastoreReplicationAcceptanceTests'
REPLICATION_ACCEPTANCE_OSX = 'CDTDatastoreReplicationAcceptanceTestsOSX'
SAMPLE_IOS = "Project"


# Destinations
IPHONE_DEST = (ENV["IPHONE_DEST"] == nil || ENV["IPHONE_DEST"] == "null") ? 'platform=iOS Simulator,OS=latest,name=iPhone 5' : ENV["IPHONE_DEST"]
OSX_DEST = (ENV["OSX_DEST"] == nil || ENV["IPHONE_DEST"] == "null") ? 'platform=OS X' : ENV["OSX_DEST"]

#
#  Primary tasks
#

desc "Run tests for all platforms"
task :test => [:testios, :testosx] do
end

desc "Task for travis"
task :travis => [:podupdate, :test, :sample] do
  sh "pod lib lint --allow-warnings --verbose | xcpretty; exit ${PIPESTATUS[0]}"
end

#
#  Update pods
#

desc "pod update"
task :podupdatetests do
  sh "pod update"
end

desc "sample pod update"
task :podupdatesample do
  sh "cd Project && pod update"
end

desc "pod update"
task :podupdate => [:podupdatetests] do
end

# Sample build task
desc "Build sample iOS application"
task :sample => [:podupdatesample] do
    unless run_build(SAMPLE_APP_WS,SAMPLE_IOS,IPHONE_DEST)
      fail "[FAILED] Sample failed to compile"
    end
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

desc "Run the replication acceptance tests for OS X"
task :replicationacceptanceosx do
  test(CDTDATASTORE_WS, REPLICATION_ACCEPTANCE_OSX, OSX_DEST)
end

desc "Run the replication acceptance tests for iOS"
task :replicationacceptanceios do
  test(CDTDATASTORE_WS, REPLICATION_ACCEPTANCE_IOS, IPHONE_DEST)
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
  settings = "GCC_PREPROCESSOR_DEFINITIONS='${inherited} ENCRYPT_DATABASE=1'" unless !ENV["encrypted"]
  # build using xcpretty as otherwise it's very verbose when running tests
  return system("xcodebuild -workspace #{workspace} -scheme '#{scheme}' -destination '#{destination}' #{settings} build | xcpretty; exit ${PIPESTATUS[0]}")
end

# Runs `test` target for workspace/scheme/destination
def run_tests(workspace, scheme, destination)
  settings = "GCC_PREPROCESSOR_DEFINITIONS='${inherited} ENCRYPT_DATABASE=1'" unless !ENV["encrypted"]
  logName = (ENV["encrypted"] ? "Encrypted" : "") + "#{scheme}.log"
  return system("xcodebuild -verbose -workspace #{workspace} -scheme '#{scheme}' -destination '#{destination}' #{settings} test | tee #{logName} | xcpretty -r junit; exit ${PIPESTATUS[0]}")
end

def test(workspace, scheme, destination)
  unless run_tests(workspace, scheme, destination)
    fail "[FAILED] Tests #{workspace}, #{scheme}"
  end
end
