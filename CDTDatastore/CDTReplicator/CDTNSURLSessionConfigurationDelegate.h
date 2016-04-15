//
//  CDTNSURLSessionConfigurationDelegate.h
//
//
//  Created by Bryn Harding.
//  Copyright (c) 2016 IBM Corp.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

/**
 This protocol is used to enable the customisation of the NSURLSessionConfiguration by the user.
 This allows particular configuration options to be customised based on the client's requirements.
 E.g. to enable replication only over wifi, the user could set the allowsCellularAccess attribute
 to NO.
 */
@protocol CDTNSURLSessionConfigurationDelegate
- (void)customiseNSURLSessionConfiguration:(nonnull NSURLSessionConfiguration *)config;
@end


