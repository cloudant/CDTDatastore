#!/usr/bin/ruby 
#
#  -couch <type> couchdb1.6, couchdb2.0, cloudantSAAS, cloudantlocal - default is couchdb1.6

#  -platform <platfrom> OSX | iOS default is OSX
#  -platform-version iOS version to test agasint (only supported for iOS)
#  -hardware the simultated hardware to test against eg iPhone 4S (only supported for iOS)
#  -D* gets passed into build.
#  -ra true | false  default is false flags if true it runs the replication acceptance tests
#                    in addition to the normal unit tests
#
require 'fileutils'

params = {}
arg_is_value = false 
prev_arg = nil


ARGV.each do |arg|

	 #process arguments into a hash
	 unless arg_is_value 
	 	params[arg[1,arg.length] ] = nil
	 	$prev_arg = arg[1,arg.length] 
	 	arg_is_value = true
	 else
	 	params[$prev_arg] = arg
	 	arg_is_value = false 
	 end

end


#apply defaults
params["platform"] = "OSX" unless params["platform"] 
params["couch"] = "couchdb1.6" unless params["couch"]
params["platform-version"] = "latest" unless params["platform-version"]
params["hardware"] = "iPhone 4S" unless params["hardware"]
params["ra"] = "false" unless params["ra"]

#kill any docker container that may be running on the machine.
#we don't want to effected by another failing build
system("docker rm --force couchdb")

#launch docker
puts "Starting docker container #{$couch}"

#cloudant local current runs in a Vagrant box, rather than docker, this box is *always* running on cloudantsync001
#so we skip the docker set up commands and change the options to enable connection to cloudant local
if params["couch"] == "cloudantlocal" 

	#Set evn variables to cloudant local settings

	ENV["TEST_COUCH_USERNAME"] = "admin"
	ENV["TEST_COUCH_PASSWORD"] = "pass"
	ENV["TEST_COUCH_HOST"] = "127.0.0.1"
	ENV["TEST_COUCH_PORT"] = "8081"
	ENV["TEST_COUCH_HTTP"] = "http"
else

	docker_port = 5984 
	#special case for couchdb2.0 it runs on port 15984 in the docker container rather than 5984
	docker_port = 15984 if params["couch"] == "couchdb2.0"

	unless system("docker run -p 5984:#{docker_port} -d -h db1.dockertest --name 'couchdb' #{params["couch"]}")
		#we need to stop, we failed to run the docker container, just in case we will delete
		system("docker rm --force couchdb")
		exit 1

	end
end

puts "Performing build"

system("rake podupdate")

#handle the differences in the platform

replication_options = Array.new


ENV.each do |key,value|

	next unless key.start_with?("TEST_COUCH")


	replication_options.push(key+"="+value)

end

if params["platform"] == "OSX"

	system("xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests OSX' -destination 'platform=OS X' #{replication_options.join(" ")} test | xcpretty -r junit ; exit ${PIPESTATUS[0]}")
	FileUtils.mv("build/reports/junit.xml","build/reports/osx_unit.xml")

	if(params["ra"] == "true")
		system("xcodebuild -workspace ./ReplicationAcceptance/ReplicationAcceptance.xcworkspace -scheme 'RA_Tests_OSX' -destination 'platform=OS X' #{replication_options.join(" ")} test | xcpretty -r junit; exit ${PIPESTATUS[0]}")
		FileUtils.mv("build/reports/junit.xml","build/reports/osx_ra.xml")
	end
elsif params["platform"] == "iOS"

	system("xcodebuild -workspace CDTDatastore.xcworkspace -scheme 'Tests iOS' -destination 'platform=iOS Simulator,OS=#{params["platform-version"]},name=#{params["hardware"]}' #{replication_options.join(" ")} test | xcpretty -r junit ; exit ${PIPESTATUS[0]}")
	FileUtils.mv("build/reports/junit.xml","build/reports/ios_unit.xml")

	if(params["ra"] == "true")	
		system("xcodebuild -workspace ./ReplicationAcceptance/ReplicationAcceptance.xcworkspace -scheme 'RA_Tests' -destination 'platform=iOS Simulator,OS=#{params["platform-version"]},name=#{params["hardware"]}' #{replication_options.join(" ")}  test | xcpretty -r junit; exit ${PIPESTATUS[0]}")
		FileUtils.mv("build/reports/junit.xml","build/reports/ios_ra.xml")
	end
end

#get the build exit code, will exit with this after tearing down the docker container
exitcode = $?


unless params["couch"] == "cloudantlocal"
	puts "Tearing down docker container" 
	system("docker stop couchdb")

	system("docker rm couchdb")
end

exit exitcode.to_i
