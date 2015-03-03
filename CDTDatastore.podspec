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
  s.version      = "0.14.0"
  s.summary      = "CDTDatastore is a document datastore which syncs."
  s.description  = <<-DESC
                    CDTDatastore is a JSON document datastore which speaks the
                    Apache CouchDB(tm) replication protocol.

                    * Replicates with Cloudant and CouchDB.
                   DESC
  s.homepage     = "http://cloudant.github.io/cloudant-sync-eap"
  s.license      = {:type => 'Apache', :text => license}
  s.author       = { "Cloudant, Inc." => "support@cloudant.com" }
  s.source       = { :git => "https://github.com/cloudant/CDTDatastore.git", :tag => s.version.to_s }

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'

  s.requires_arc = true

  s.default_subspec = 'common'

  s.subspec 'common' do |sp|
    sp.prefix_header_contents = '#import "CollectionUtils.h"', '#import "Logging.h"', '#import "Test.h"'

    sp.source_files = 'Classes/**/*.{h,m}'
    sp.exclude_files = 'Classes/vendor/MYUtilities/*.{h,m}'
    
    sp.ios.exclude_files = 'Classes/osx'
    sp.osx.exclude_files = 'Classes/ios'

    sp.frameworks = 'SystemConfiguration'

    sp.dependency 'CDTDatastore/no-arc'
    sp.dependency 'CocoaLumberjack', '= 2.0.0-rc'

    sp.default_subspec = 'SQLite'

    sp.subspec 'SQLite' do |ssp|
      ssp.library = 'sqlite3', 'z'

      ssp.dependency 'FMDB', '= 2.3'
    end

    sp.subspec 'SQLCipher' do |ssp|
      ssp.library = 'z'

      ssp.dependency 'FMDB/SQLCipher', '= 2.3'
    end
  end

  s.subspec 'no-arc' do |sp|
    sp.requires_arc = false

    sp.prefix_header_contents = '#import "CollectionUtils.h"', '#import "Logging.h"', '#import "Test.h"'

    sp.source_files = 'Classes/vendor/MYUtilities/*.{h,m}'

    sp.ios.exclude_files = 'Classes/vendor/MYUtilities/MYURLHandler.{h,m}'
  end

  s.subspec 'SQLCipher' do |sp|
    sp.dependency 'CDTDatastore/common'
    sp.dependency 'CDTDatastore/common/SQLCipher'
  end
end
