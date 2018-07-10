//
//  SwiftTests.swift
//  CDTDatastore
//
//  Created by tomblench on 09/04/2018.
//  Copyright © 2018 IBM Corporation. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

import Foundation
import XCTest

public class SwiftTests : CloudantSyncTests {

    // test that the result of listIndexes() is correctly bridged from obj-c to swift
    public func testListIndexes() {
        autoreleasepool { () -> Void in
        do {
            let store = try factory.datastoreNamed("my_ds")
            let rev = CDTDocumentRevision()
            rev.body = NSMutableDictionary(dictionary: ["hello":"world"])
            try store.createDocument(from: rev)
            store.ensureIndexed(["hello"], withName: "index")
            let indexes = store.listIndexes()
            XCTAssertEqual(indexes["index"]!["type"] as! String, "json")
            XCTAssertTrue((indexes["index"]!["fields"] as! Array<String>).contains("_id"))
            XCTAssertTrue((indexes["index"]!["fields"] as! Array<String>).contains("_rev"))
            XCTAssertTrue((indexes["index"]!["fields"] as! Array<String>).contains("hello"))
            }

         catch {
            XCTFail("Test failed with \(error)")
        }
        }
        print("done")
    }
    
}
