license = <<EOT
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOT

Pod::Spec.new do |s|
  s.name         = "CDTDatastore"
  s.version      = "2.0.0"
  s.summary      = "CDTDatastore is a document datastore which syncs."
  s.description  = <<-DESC
                    CDTDatastore is a JSON document datastore which speaks the
                    Apache CouchDB(tm) replication protocol.

                    * Replicates with Cloudant and CouchDB.
                   DESC
  s.homepage     = "http://github.com/cloudant/CDTDatastore"
  s.license      = {:type => 'Apache, Version 2.0', :text => license}
  s.author       = { "Cloudant, Inc." => "support@cloudant.com" }
  s.source       = { :git => "https://github.com/cloudant/CDTDatastore.git", :tag => s.version.to_s }

  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.9'

  s.requires_arc = true

  s.default_subspec = 'standard'

  s.subspec 'standard' do |sp|
    sp.prefix_header_contents = '#import "CollectionUtils.h"', '#import "Logging.h"', '#import "Test.h"', '#import "CDTMacros.h"'
    sp.private_header_files = 'CDTDatastore/touchdb/*.h'
    sp.source_files = 'CDTDatastore/**/*.{h,m}'
    sp.exclude_files = 'CDTDatastore/vendor/MYUtilities/*.{h,m}'
    sp.library = 'sqlite3', 'z'
    sp.dependency 'CDTDatastore/common-dependencies'
    sp.dependency 'FMDB', '= 2.6'
  end

  s.subspec 'common-dependencies' do |sp|
    sp.frameworks = 'SystemConfiguration'

    sp.dependency 'CDTDatastore/no-arc'
    sp.dependency 'CocoaLumberjack', '~> 2.0'
    sp.dependency 'GoogleToolboxForMac/NSData+zlib', '~> 2.1.1'
  end

  s.subspec 'no-arc' do |sp|
    sp.requires_arc = false

    sp.prefix_header_contents = '#import "CollectionUtils.h"', '#import "Logging.h"', '#import "Test.h"'

    sp.source_files = 'CDTDatastore/vendor/MYUtilities/*.{h,m}'
    sp.ios.exclude_files = 'CDTDatastore/vendor/MYUtilities/MYURLHandler.{h,m}'

  end
end
