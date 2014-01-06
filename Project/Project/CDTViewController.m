//
//  CDTViewController.m
//  Project
//
//  Created by Michael Rhodes on 03/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "CDTViewController.h"

#import "CDTAppDelegate.h"

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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Data managment


- (void)addTodoItem:(NSString*)item {
    NSDictionary *doc = @{@"description": item, @"completed": @NO};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:doc];
    
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

- (void)toggleTodoCheckedForRevision:(CDTDocumentRevision*)revision {
    NSMutableDictionary *body = [revision documentAsDictionary].mutableCopy;
    NSLog(@"Toggling checked status for %@", body[@"description"]);
    NSNumber *current = body[@"checked"];
    body[@"checked"] = [NSNumber numberWithBool:![current boolValue]];
    
    
    NSError *error;
    [self.datastore updateDocumentWithId:revision.docId
                                 prevRev:revision.revId
                                    body:[[CDTDocumentBody alloc] initWithDictionary:body]
                                   error:&error];
    
    if (error != nil) {
        NSLog(@"Error updating item: %@", error);
    }
}

- (void)reloadTasks {
    int count = self.datastore.documentCount;
    self.taskRevisions = [self.datastore getAllDocumentsOffset:0 limit:count descending:NO];
}


#pragma mark Properties

- (CDTDatastore *)datastore {
    CDTAppDelegate *delegate = (CDTAppDelegate *)[[UIApplication sharedApplication] delegate];
    return delegate.datastore;
}

#pragma mark Handlers

- (void)addTodoButtonTap:(NSObject *)sender {
    NSString *text = self.addTodoTextField.text;
    if (text.length == 0) { return; }  // don't create empty tasks
    NSLog(@"Adding task: %@", text);
    [self addTodoItem:text];
    [self reloadTasks];
    [self.tableView reloadData];
    self.addTodoTextField.text = @"";
}

#pragma mark UITableView delegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"Selected row at [%i, %i]", indexPath.section, indexPath.row);
    if (indexPath.section == 1) {
        // Get the revision, toggle checked status on the body
        // and save a new revision, passing the current revision
        // ID and rev.
        CDTDocumentRevision *revision = [self.taskRevisions objectAtIndex:indexPath.row];
        [self toggleTodoCheckedForRevision:revision];
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
        cell.textLabel.text = (NSString*)[body objectForKey:@"description"];
        NSNumber *checked = (NSNumber*)[body objectForKey:@"checked"];
        if ([checked boolValue]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        return cell;
    }
}


@end
