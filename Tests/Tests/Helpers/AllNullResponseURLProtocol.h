//
//  CannedResponseURLProtocol.h
//  Tests
//
//  Created by Michael Rhodes on 04/09/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import <Foundation/Foundation.h>

/**
 A simple NSURLProtocol which responds to *every* request, and responds with a 404 and
 empty data. Intended to stub where we don't care about the request, but want to avoid
 side-effects.
 */
@interface AllNullResponseURLProtocol : NSURLProtocol

@end
