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
  s.version      = "0.15.0"
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

  s.default_subspec = 'standard'

  s.subspec 'standard' do |sp|
    # DUPLICATED CODE - Check subspec 'SQLCipher' - BEGIN
    # CDTDatastore code depends on FMDB, without this dependency the code will
    # not compile ('pod lib lint' will fail). FMDB can be compiled based on
    # SQLite or SQLCipher and we want to offer both options. To do that, we have
    # to define 2 subspecs and specify in both the CDTDatastore code and one of
    # FMDB subspecs.
    # If you try to make one of the subspecs to depend on the other to avoid the
    # duplicated code, the resulting subspec will include at the same time
    # SQLite and SQLCipher.

    sp.prefix_header_contents = '#import "CollectionUtils.h"', '#import "Logging.h"', '#import "Test.h"'

    sp.source_files = 'Classes/**/*.{h,m}'

    sp.exclude_files = 'Classes/vendor/MYUtilities/*.{h,m}'
    sp.ios.exclude_files = 'Classes/osx'
    sp.osx.exclude_files = 'Classes/ios'

    sp.dependency 'CDTDatastore/common-dependencies'

    # DUPLICATED CODE - Check subspec 'SQLCipher' - END

    sp.library = 'sqlite3', 'z'

    sp.dependency 'FMDB', '= 2.3'
  end

  s.subspec 'SQLCipher' do |sp|
    # DUPLICATED CODE - Check subspec 'standard' - BEGIN
    # CDTDatastore code depends on FMDB, without this dependency the code will
    # not compile ('pod lib lint' will fail). FMDB can be compiled based on
    # SQLite or SQLCipher and we want to offer both options. To do that, we have
    # to define 2 subspecs and specify in both the CDTDatastore code and one of
    # FMDB subspecs.
    # If you try to make one of the subspecs to depend on the other to avoid the
    # duplicated code, the resulting subspec will include at the same time
    # SQLite and SQLCipher.

    sp.prefix_header_contents = '#import "CollectionUtils.h"', '#import "Logging.h"', '#import "Test.h"'

    sp.source_files = 'Classes/**/*.{h,m}'

    sp.exclude_files = 'Classes/vendor/MYUtilities/*.{h,m}'
    sp.ios.exclude_files = 'Classes/osx'
    sp.osx.exclude_files = 'Classes/ios'

    sp.dependency 'CDTDatastore/common-dependencies'
    
    # DUPLICATED CODE - Check subspec 'standard' - END

    sp.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DENCRYPT_DATABASE' }

    sp.library = 'z'

    # Some CDTDatastore classes use SQLite functions, we have to include
    # 'SQLCipher' although 'FMDB/SQLCipher' also depends on 'SQLCipher' or they
    # will not compile (linker will not find some symbols)
    sp.dependency 'SQLCipher'
    sp.dependency 'FMDB/SQLCipher', '= 2.3'
  end

  s.subspec 'common-dependencies' do |sp|
    sp.frameworks = 'SystemConfiguration'

    sp.dependency 'CDTDatastore/no-arc'
    sp.dependency 'CocoaLumberjack', '~> 2.0'
  end

  s.subspec 'no-arc' do |sp|
    sp.requires_arc = false

    sp.prefix_header_contents = '#import "CollectionUtils.h"', '#import "Logging.h"', '#import "Test.h"'

    sp.source_files = 'Classes/vendor/MYUtilities/*.{h,m}'

    sp.ios.exclude_files = 'Classes/vendor/MYUtilities/MYURLHandler.{h,m}'
  end
end
