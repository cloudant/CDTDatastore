#!/bin/bash

#We modify this plist file so as not to affect files under revision control
info_plist="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReplicationSettings.plist"

echo $info_plist

for k in ${!TEST_COUCH*}
do
    v=${!k}
    echo "Setting ${k} to ${v}"
    /usr/libexec/PlistBuddy -c "Set :${k} '${v}'" "${info_plist}"
done
