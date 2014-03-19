//
//  CDTViewController.m
//  Project
//
//  Created by Michael Rhodes on 03/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTViewController.h"

#import "CDTAppDelegate.h"
#import "CDTTodoReplicator.h"
#import "CDTTodo.h"

#import <CloudantSync.h>

@interface CDTViewController ()

@property (readonly) CDTDatastore *datastore;
@property (nonatomic,strong) NSArray *taskRevisions;

- (void)addTodoItem:(NSString*)item;
- (void)deleteTodoItem:(CDTDocumentRevision*)revision;
- (void)reloadTasks;

@end

@implementation CDTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadTasks];
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Data managment


- (void)addTodoItem:(NSString*)description {
    CDTTodo *todo = [[CDTTodo alloc] initWithDescription:description
                                               completed:NO];
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:[todo toDict]];
    
    NSError *error;
    [self.datastore createDocumentWithBody:body error:&error];
    
    if (error != nil) {
        NSLog(@"Error adding item: %@", error);
    }
}

- (void)deleteTodoItem:(CDTDocumentRevision*)revision {
    
    NSError *error;
    [self.datastore deleteDocumentWithId:revision.docId
                                     rev:revision.revId
                                   error:&error];
    
    if (error != nil) {
        NSLog(@"Error deleting item: %@", error);
    }
}

- (void)toggleTodoCompletedForRevision:(CDTDocumentRevision*)revision {

    CDTTodo *todo = [CDTTodo fromDict:[revision documentAsDictionary]];
    todo.completed = !todo.completed;

    NSLog(@"Toggling completed status for %@", todo.description);
    
    NSError *error;
    [self.datastore updateDocumentWithId:revision.docId
                                 prevRev:revision.revId
                                    body:[[CDTDocumentBody alloc] initWithDictionary:[todo toDict]]
                                   error:&error];
    
    if (error != nil) {
        NSLog(@"Error updating item: %@", error);
    }
}

- (void)reloadTasks {
    self.taskRevisions = [self.datastore getAllDocuments];
}


#pragma mark Properties

- (CDTDatastore *)datastore {
    CDTAppDelegate *delegate = (CDTAppDelegate *)[[UIApplication sharedApplication] delegate];
    return delegate.datastore;
}

#pragma mark Handlers

- (void)addTodoButtonTap:(NSObject *)sender {
    NSString *description = self.addTodoTextField.text;
    if (description.length == 0) { return; }  // don't create empty tasks
    NSLog(@"Adding task: %@", description);
    [self addTodoItem:description];
    [self reloadTasks];
    [self.tableView reloadData];
    self.addTodoTextField.text = @"";
}

-(IBAction)replicateTapped:(id)sender {
    NSLog(@"Replicate");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[[CDTTodoReplicator alloc] init] sync];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadTasks];
            [self.tableView reloadData];
        });
    });
}

#pragma mark UITableView delegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"Selected row at [%i, %i]", indexPath.section, indexPath.row);
    if (indexPath.section == 1) {
        // Get the revision, toggle completed status on the body
        // and save a new revision, passing the current revision
        // ID and rev.
        CDTDocumentRevision *revision = [self.taskRevisions objectAtIndex:indexPath.row];
        [self toggleTodoCompletedForRevision:revision];
        [self reloadTasks];
        [self.tableView reloadData];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        return YES;
    } else {
        return NO;
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        CDTDocumentRevision *revision = [self.taskRevisions objectAtIndex:indexPath.row];
        [self deleteTodoItem:revision];
        [self reloadTasks];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationLeft];
    }
}

#pragma mark UITableView data source methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        int count = [self datastore].documentCount;
        if (count < 0) { // error
            return 0;
        } else {
            return count;
        }
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        // Add cell
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AddCell"];
        self.addTodoTextField = (UITextField*)[cell viewWithTag:100];
        return cell;
    } else {
        // Item cell
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TodoCell"];
        CDTDocumentRevision *task = [self.taskRevisions objectAtIndex:indexPath.row];
        
        NSDictionary *body = [task documentAsDictionary];
        CDTTodo *todo = [CDTTodo fromDict:body];
        cell.textLabel.text = todo.description;
        if (todo.completed) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        return cell;
    }
}


@end
