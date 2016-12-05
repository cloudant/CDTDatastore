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

#import "DBQueryUtils.h"

#import <sqlite3.h>

#import <XCTest/XCTest.h>
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMResultSet.h"
#import "TDCollateJSON.h"
#import "TDJSON.h"
#import "TD_Revision.h"

NSString* const DBQueryUtilsErrorDomain = @"DBQueryUtilsErrorDomain";

@interface DBQueryUtils()
@property (nonatomic, readwrite) NSSet *sqlTables;
@end

@implementation DBQueryUtils

-(instancetype) initWithDbPath:(NSString*)dbPath
{
    self = [super init];
    if (self) {
        _queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        if (!_queue)
            return nil;
        [self registerCollationFunctions:_queue];
    }
    return self;
}

-(void) registerCollationFunctions:(FMDatabaseQueue *)queue
{
    // Register CouchDB-compatible JSON collation functions:
    [queue inDatabase:^(FMDatabase *db){
        sqlite3_create_collation(db.sqliteHandle, "JSON", SQLITE_UTF8,
                                 kTDCollateJSON_Unicode, TDCollateJSON);
        sqlite3_create_collation(db.sqliteHandle, "JSON_RAW", SQLITE_UTF8,
                                 kTDCollateJSON_Raw, TDCollateJSON);
        sqlite3_create_collation(db.sqliteHandle, "JSON_ASCII", SQLITE_UTF8,
                                 kTDCollateJSON_ASCII, TDCollateJSON);
        sqlite3_create_collation(db.sqliteHandle, "REVID", SQLITE_UTF8,
                                 NULL, TDCollateRevIDs);
    }];

}

-(void) printFMResult:(FMResultSet *)result ignorecolumns:(NSSet *)ignored
{
    for(int i = 0; i < [result columnCount]; i++){
        NSString *resultString = [result stringForColumnIndex:i];
        NSString *columnName =[result columnNameForIndex:i];
        if([ignored member:columnName])
            continue;
        
        if([columnName isEqualToString:@"json"]){
            NSData *jsonData =[result dataForColumnIndex: i];
            NSDictionary *jsonDoc = nil;
            if(jsonData)
                jsonDoc = [TDJSON JSONObjectWithData:jsonData
                                             options: TDJSONReadingMutableContainers
                                               error: NULL];
            if(jsonDoc)
                resultString = [NSString stringWithFormat:@"%@", jsonDoc];
            else
                resultString = [NSString stringWithFormat:
                                @"object type: %@. description: %@",
                                [[result objectForColumnIndex:i] class], [result dataForColumnIndex:i]];
            
        }
        
//        NSLog(@"%@ : %@",[result columnNameForIndex:i], resultString);
    }
}

-(void) printAllRowsForTable:(NSString *)table
{
    NSString *sql = [NSString stringWithFormat:@"select * from %@", table];
    [self printResultsForQuery:sql];
}

-(void) printDocsAndRevs
{
    NSString *sql = [NSString stringWithFormat:@"select revs.doc_id as doc_id, docid, revid, sequence, parent, current, deleted, json from revs, docs where revs.doc_id = docs.doc_id order by docid, sequence"];
    [self printResultsForQuery:sql];
}

-(void) printResultsForQuery:(NSString *)sql
{
    __weak DBQueryUtils  *weakSelf = self;
    [self.queue inDatabase:^(FMDatabase *db) {
        DBQueryUtils *strongSelf = weakSelf;
        FMResultSet *result = [db executeQuery:sql];
        
//        NSLog(@"results for query: %@", sql);
        
        while([result next]){
            [strongSelf printFMResult:result ignorecolumns:nil];
//            NSLog(@" ");
        }
        
        [result close];
    }];
    
}

-(int) rowCountForTable:(NSString *)table
{
    __block int count = 0;
    [self.queue inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"select count(*) as counts from %@", table];
        FMResultSet *result = [db executeQuery:sql];
        [result next];
        count =  [result intForColumn:@"counts"];
        [result close];
    }];
    
    return count;
    
}

-(NSMutableDictionary *) getAllTablesRowCount
{
    NSMutableDictionary *rowCount = [[NSMutableDictionary alloc] init];
    for(NSString *table in self.sqlTables){
        [rowCount setValue:[NSNumber numberWithInt:[self rowCountForTable:table]] forKey:table];
    }
    return rowCount;
}


- (NSSet*) sqlTables
{
    if(_sqlTables)
        return _sqlTables;
    
    __block NSMutableArray *tables = [[NSMutableArray alloc] init];
    
    [self.queue inDatabase:^(FMDatabase *db){
        NSString *sql = @"select name from sqlite_master where type='table' and name not in ('sqlite_sequence')";
        FMResultSet  *result = [db executeQuery:sql];
        while([result next]){
            [tables addObject:[result stringForColumn:@"name"]];
        }
        [result close];
    }];
    
    _sqlTables = [NSSet setWithArray:tables];
    return _sqlTables;
}
/*
 Both dictionaries should contain keys that are the names of tables and values that are NSNumbers.
 The values of initialRowCount are the "initial" number of rows in each table.
 The values of modifiedRows should be the expected number of news rows found in each table.
 */
-(void) checkTableRowCount:(NSDictionary *)initialRowCount
                modifiedBy:(NSDictionary *)modifiedRowCount
{
    
    for(NSString* table in initialRowCount){
        
//        NSLog(@"testing for modification to %@", table);
        NSInteger initCount = [initialRowCount[table] integerValue];
        NSInteger expectCount = initCount;
        
        if([modifiedRowCount[table] respondsToSelector:@selector(integerValue)])
            expectCount += [modifiedRowCount[table] integerValue];  //we expect there to be one new row in the modifiedTables
        
        NSInteger foundCount = [self rowCountForTable:table];
        XCTAssertTrue(
            foundCount == expectCount,
            @"For table %@: row count mismatch. initial number of rows %ld expected %ld found %ld.",
            table, (long)initCount, (long)expectCount, (long)foundCount);
    }
}

+(NSSet *) compileOptions:(FMDatabaseQueue *)queue
{
    __block NSMutableArray *compileOptions = [NSMutableArray array];
    
    [queue inDatabase:^(FMDatabase *db){
        FMResultSet *result = [db executeQuery:@"PRAGMA compile_options"];
        while ([result next]) {
            [compileOptions addObject:[result stringForColumnIndex:0]];
        }
        [result close];
    }];
    
    return [NSSet setWithArray:compileOptions];
}


@end
