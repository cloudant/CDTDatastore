#!/bin/bash

#We modify this plist file so as not to affect files under revision control
info_plist="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReplicationSettings.plist"

echo $info_plist

if [ "$TEST_COUCH_USERNAME" ]; then
	echo "Setting couch username"
    /usr/libexec/PlistBuddy -c "Set :TEST_COUCH_USERNAME '${TEST_COUCH_USERNAME}'" "${info_plist}"
fi

if [ "$TEST_COUCH_PASSWORD" ]; then
		echo "Setting couch password"
/usr/libexec/PlistBuddy -c "Set :TEST_COUCH_PASSWORD '${TEST_COUCH_PASSWORD}'" "${info_plist}"
fi

if [ "$TEST_COUCH_HOST" ]; then
		echo "Setting couch host"
/usr/libexec/PlistBuddy -c "Set :TEST_COUCH_HOST '${TEST_COUCH_HOST}'" "${info_plist}"
fi

if [ "$TEST_COUCH_PORT" ]; then
		echo "Setting couch port"
    /usr/libexec/PlistBuddy -c "Set :TEST_COUCH_PORT '${TEST_COUCH_PORT}'" "${info_plist}";
fi

if [ "$TEST_COUCH_HTTP" ]; then
		echo "Setting couch http"
    /usr/libexec/PlistBuddy -c "Set :TEST_COUCH_HTTP '${TEST_COUCH_HTTP}'" "${info_plist}";
fi
