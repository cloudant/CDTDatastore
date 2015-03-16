desc "Run the CDTDatastore Tests for iOS"
task :testios do
    # build using xcpretty as otherwise it's very verbose when running tests
  $ios_success = system("xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests iOS' -destination 'platform=iOS Simulator,OS=latest,name=iPhone 4S' build | xcpretty; exit ${PIPESTATUS[0]}")
  unless $ios_success
    puts "** Build failed"
    exit(-1)
  end
  $ios_success = system("xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests iOS' -destination 'platform=iOS Simulator,OS=latest,name=iPhone 4S' test")
  puts "\033[0;31m! iOS unit tests failed with status code #{$?}" unless $ios_success
  if $ios_success
    puts "** All tests executed successfully"
  else
    exit(-1)
  end
end

desc "Run the CDTDatastore Tests for OS X"
task :testosx do
    # build using xcpretty as otherwise it's very verbose when running tests
  $osx_success = system("xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests OSX' -destination 'platform=OS X' build | xcpretty; exit ${PIPESTATUS[0]}")
  unless $osx_success
    puts "** Build failed"
    exit(-1)
  end
  $osx_success = system("xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests OSX' -destination 'platform=OS X' test")
  puts "\033[0;31m! OS X unit tests failed with status code #{$?}" unless $osx_success
  if $osx_success
    puts "** All tests executed successfully"
  else
    exit(-1)
  end
end

desc "Run the CDTDatastore Encryption Tests for iOS"
task :testencryptionios do
    # build using xcpretty as otherwise it's very verbose when running tests
  $ios_success = system("xcodebuild -workspace EncryptionTests/EncryptionTests.xcworkspace -scheme 'Encryption Tests' -destination 'platform=iOS Simulator,OS=latest,name=iPhone 4S' build | xcpretty; exit ${PIPESTATUS[0]}")
  unless $ios_success
    puts "** Build failed"
    exit(-1)
  end
  $ios_success = system("xcodebuild -workspace EncryptionTests/EncryptionTests.xcworkspace -scheme 'Encryption Tests' -destination 'platform=iOS Simulator,OS=latest,name=iPhone 4S' test")
  puts "\033[0;31m! iOS unit tests failed with status code #{$?}" unless $ios_success
  if $ios_success
    puts "** All tests executed successfully"
  else
    exit(-1)
  end
end

desc "Run the CDTDatastore Encryption Tests for OS X"
task :testencryptionosx do
    # build using xcpretty as otherwise it's very verbose when running tests
  $osx_success = system("xcodebuild -workspace EncryptionTests/EncryptionTests.xcworkspace -scheme 'Encryption Tests OSX' -destination 'platform=OS X' build | xcpretty; exit ${PIPESTATUS[0]}")
  unless $osx_success
    puts "** Build failed"
    exit(-1)
  end
  $osx_success = system("xcodebuild -workspace EncryptionTests/EncryptionTests.xcworkspace -scheme 'Encryption Tests OSX' -destination 'platform=OS X' test")
  puts "\033[0;31m! OS X unit tests failed with status code #{$?}" unless $osx_success
  if $osx_success
    puts "** All tests executed successfully"
  else
    exit(-1)
  end
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

desc "pod update all test projects"
task :podupdatetests do
  sh "for i in Tests EncryptionTests\ndo\ncd $i ; pod update ; cd ..\ndone"
end

desc "Run the replication acceptance tests"
task :replicationacceptance do
    $osx_success = system("xcodebuild -workspace ./ReplicationAcceptance/ReplicationAcceptance.xcworkspace -scheme 'RA_Tests' -destination 'platform=OS X' test | xcpretty; exit ${PIPESTATUS[0]}")
    puts "\033[0;31m! OS X unit tests failed" unless $osx_success
    if $osx_success
        puts "** All tests executed successfully"
        else
        exit(-1)
    end
end

desc "Run the replication acceptance tests"
task :testdevice do
    $osx_success = system("xcodebuild -workspace ./ReplicationAcceptance/ReplicationAcceptance.xcworkspace -scheme 'ReplicationAcceptanceApp' -destination 'platform=iOS Simulator,OS=latest,name=iPhone Retina (3.5-inch)' test | xcpretty; exit ${PIPESTATUS[0]}")
    puts "\033[0;31m! OS X unit tests failed" unless $osx_success
    if $osx_success
        puts "** All tests executed successfully"
        else
        exit(-1)
    end
end

desc "pod update all included projects"
task :podupdate => [:podupdatetests] do
  sh "for i in ReplicationAcceptance Project\ndo\ncd $i ; pod update ; cd ..\ndone"
end

desc "Build docs and install to Xcode"
task :docs do
  system("appledoc --keep-intermediate-files --project-name CDTDatastore --project-company Cloudant -o build/docs --company-id com.cloudant -i Classes/vendor -i Classes/common/touchdb Classes/")
end
