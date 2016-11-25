//
//  DBQueryUtils.h
//
//  Created by G. Adam Cox on 2014/03/11.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>

@class FMDatabaseQueue;
@class FMResultSet;

@interface DBQueryUtils : NSObject

@property (nonatomic, strong) FMDatabaseQueue *queue;
@property (nonatomic, readonly) NSSet *sqlTables;

-(instancetype) initWithDbPath:(NSString*)dbPath;
-(void) printResultsForQuery:(NSString *)sql;
-(void) printDocsAndRevs;
-(void) printAllRowsForTable:(NSString *)table;
-(void) printFMResult:(FMResultSet *)result ignorecolumns:(NSSet *)ignored;
-(NSMutableDictionary *) getAllTablesRowCount;
-(void) registerCollationFunctions:(FMDatabaseQueue *)aQueue;
-(int) rowCountForTable:(NSString *)table;
-(void) checkTableRowCount:(NSDictionary *)initialRowCount
               modifiedBy:(NSDictionary *)modifiedRowCount;
+(NSSet *) compileOptions:(FMDatabaseQueue *)queue;

@end
