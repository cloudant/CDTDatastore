//
//  ViewController.m
//
//
//  Created by Petro Tyurin on 7/23/14.
//  Copyright (c) 2014 Petro Tyurin. All rights reserved.
//
#import "ViewController.h"

@interface ViewController () <UITextFieldDelegate, UICollectionViewDataSource,
                              UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate>

@end

@implementation ViewController

#define DEFAULT_USER @"ptiurin"

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section
{
    return [self.images count];
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"Cell "
                                                               forIndexPath:indexPath];
    
    CGRect  viewRect = CGRectMake(0, 0, 100, 100);
    UIImageView *myImageView = [[UIImageView alloc] initWithFrame:viewRect];
    
    myImageView.image = self.images[indexPath.row];
    
    [cell.contentView addSubview:myImageView];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
        didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
}

- (void)collectionView:(UICollectionView *)collectionView
        didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize retval = CGSizeMake(100, 100);
    return retval;
}

/** Returns spacing, headers and footers */
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout*)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section
{
    UIEdgeInsets insets = { .left = 40, .right = 40, .top = -40, .bottom = 100 };
    return insets;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.collectionView registerClass:[UICollectionViewCell class]
            forCellWithReuseIdentifier:@"Cell "];
    // Add image
    UIBarButtonItem *addBarButtonItem = [[UIBarButtonItem alloc]
                                         initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                              target:self
                                                              action:@selector(addAction)];
    // Delete local database
    UIBarButtonItem *deleteBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                 target:self
                                                                 action:@selector(deleteDatastore)];
    
    UIBarButtonItem *shareBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithTitle:@"Share"
                                                     style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(shareAction)];
    UIBarButtonItem *connectBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithTitle:@"Connect"
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(connectAction)];
    UIBarButtonItem *createBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithTitle:@"New"
                                                    style:UIBarButtonItemStylePlain
                                                   target:self
                                                   action:@selector(createAction)];
    UIBarButtonItem *pushBarButtonItem = [[UIBarButtonItem alloc]
                                          initWithTitle:@"Push"
                                                  style:UIBarButtonItemStylePlain
                                                 target:self
                                                 action:@selector(pushReplicateAction)];
    UIBarButtonItem *pullBarButtonItem = [[UIBarButtonItem alloc]
                                          initWithTitle:@"Pull"
                                                  style:UIBarButtonItemStylePlain
                                                 target:self
                                                 action:@selector(pullReplicateAction)];
    
    self.navigationItem.rightBarButtonItems = [[NSArray alloc]
                                               initWithObjects:addBarButtonItem,
                                                               deleteBarButtonItem,
                                                               connectBarButtonItem,
                                                               createBarButtonItem,
                                                               nil];
    // Add flexible space to center toolbar buttons
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                           target:nil
                                                           action:nil];
    [self.navigationController setToolbarHidden:NO];
    [self setToolbarItems:[[NSArray alloc] initWithObjects:flexibleSpace,
                                                           shareBarButtonItem,
                                                           pushBarButtonItem,
                                                           pullBarButtonItem,
                                                           flexibleSpace,
                                                           nil]];
    
    
    self.images = [[NSMutableArray alloc] init];
    [self initDatastore];
    [self loadDocs];
    [self loadDefaults];
}

/** Initialise imagePickerController to add new images */
- (void)addAction
{
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
	picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:nil];
}

/** Pick an image from the phone */
- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    [self.images addObject:img];
    [self.collectionView reloadData];
    [self createDoc:img];
}

/** Create a new document with given image as an attachment */
- (void)createDoc:(UIImage *)image
{
    NSError *error;
    // Create a document
    NSDictionary *doc = @{
        @"description": @"Buy milk",
        @"completed": @NO,
        @"type": @"com.cloudant.sync.example.task"
    };
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:doc];
    
    CDTDocumentRevision *rev1 = [self.ds createDocumentWithBody:body
                                                          error:&error];
    if (error != NULL) {
        NSLog(@"Document creation error: %@", error);
    }
    
    NSData *data = UIImageJPEGRepresentation(image, 0.7);
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:@"image"
                                                                          type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.ds updateAttachments:@[attachment]
                                                    forRev:rev1
                                                     error:&error];
     if (error != NULL) {
         NSLog(@"Attachment write error: %@", error);
     }
}

/** Load images stored in a local datastore */
- (void)loadDocs
{
    NSError *error;
    NSArray *docs = self.ds.getAllDocuments;
    for (CDTDocumentRevision *rev in docs){
        CDTAttachment *retrievedAttachment = [self.ds attachmentNamed:@"image"
                                                               forRev:rev
                                                                error:&error];
        if (error != NULL) {
            NSLog(@"Attachment read error: %@", error);
        } else if (retrievedAttachment != NULL) {
            NSLog(@"Doc retrieved: %@",rev.docId);
            NSData *attachmentData = [retrievedAttachment dataFromAttachmentContent];
            UIImage *image = [UIImage imageWithData:attachmentData];
            [self.images addObject:image];
        }
    }
    [self.collectionView reloadData];
}

/** Initialise local datastore */
- (void)initDatastore
{
    // Create a CDTDatastoreManager using application internal storage path
    NSError *error = nil;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
    NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                               inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [documentsDir URLByAppendingPathComponent:@"cloudant-sync-datastore"];
    NSString *path = [storeURL path];
    
    self.manager =
    [[CDTDatastoreManager alloc] initWithDirectory:path error:&error];
    
    self.ds = [self.manager datastoreNamed:@"my_datastore"
                                     error:&error];
    if (error != NULL) {
        NSLog(@"Error opening the local datastore: %@", error);
    }
}

/** Delete local datastore and create an empty one */
- (void)deleteDatastore
{
    NSError *error;
    [self.manager deleteDatastoreNamed:@"my_datastore" error:&error];
    if (error != NULL) {
        NSLog(@"Error deleting the datastore: %@", error);
    } else {
        self.ds = [self.manager datastoreNamed:@"my_datastore"
                                         error:&error];
        if (error != NULL) {
            NSLog(@"Error re-opening the datastore: %@", error);
        }
        
        [self.images removeAllObjects];
        [self.collectionView reloadData];
    }
}

/** Push changes to remote database */
- (void)pushReplicateAction
{
    CDTReplicatorFactory *replicatorFactory =
    [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.manager];
    [replicatorFactory start];
    
    NSString *s = [NSString stringWithFormat:@"https://%@:%@@%@.cloudant.com/%@", self.APIKey,
                   self.APIPass, DEFAULT_USER, self.remoteDatabase];
    NSURL *remoteDatabaseURL = [NSURL URLWithString:s];

    // Create a replicator that replicates changes from the local
    // datastore to the remote database.
    CDTPushReplication *pushReplication = [CDTPushReplication
                                           replicationWithSource:self.ds
                                                          target:remoteDatabaseURL];
    NSError *error;
    CDTReplicator *replicator = [replicatorFactory oneWay:pushReplication error:&error];
    if (error != NULL) {
        NSLog(@"Error pushing to the remote: %@", error);
    }
    
    // Start the replication and wait for it to complete
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
}

/** Pull changes from remote databse */
- (void)pullReplicateAction
{
    CDTReplicatorFactory *replicatorFactory =
    [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.manager];
    [replicatorFactory start];
    
    NSString *s = [NSString stringWithFormat:@"https://%@:%@@%@.cloudant.com/%@", self.APIKey,
                   self.APIPass, DEFAULT_USER, self.remoteDatabase];
    NSURL *remoteDatabaseURL = [NSURL URLWithString:s];
    
    // Create a replicator that replicates changes from the local
    // datastore to the remote database.
    CDTPullReplication *pullReplication = [CDTPullReplication
                                           replicationWithSource:remoteDatabaseURL
                                                          target:self.ds];
    NSError *error;
    CDTReplicator *replicator = [replicatorFactory oneWay:pullReplication error:&error];
    if (error != NULL) {
        NSLog(@"Error pulling from the remote: %@", error);
    }
    
    // Start the replication and wait for it to complete
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    [self loadDocs];
}

/** Prompt user to input a database name to connect */
- (void)connectAction
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connect to remote DB"
                                                    message:@"Enter the database name to connect"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Connect", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 1) {
        NSLog(@"Entered: %@",[[alertView textFieldAtIndex:0] text]);
        self.remoteDatabase = [[alertView textFieldAtIndex:0] text];
    }
    NSError *error;
    
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:5000/get_key"];
    
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration
                                                       defaultSessionConfiguration];
    sessionConfiguration.HTTPAdditionalHeaders = @{@"Content-Type"  : @"application/json"};
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"PUT";
    NSDictionary *dict = @{@"db":self.remoteDatabase};
    NSData *send_data = [NSJSONSerialization dataWithJSONObject:dict
                                                        options:kNilOptions
                                                          error:&error];
    if (error != NULL) {
        NSLog(@"Error constructing json: %@", error);
    }
    [request setHTTPBody:send_data];
    
    
    NSURLSessionDataTask *uploadTask = [session dataTaskWithRequest:request
                                                  completionHandler:^(NSData *data,
                                                                      NSURLResponse *response,
                                                                      NSError *error) {
        if (error != NULL) {
            NSLog(@"Got response %@ with error %@.\n", response, error);
        }
        NSString *auth_data = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        NSLog(@"DATA:\n%@\nEND DATA\n", auth_data);
        NSDictionary* json = [NSJSONSerialization
                              JSONObjectWithData:data
                              options:kNilOptions
                              error:&error];
        NSLog(@"key: %@ recieved.\n", [json objectForKey:@"key"]);
        self.APIKey = json[@"key"];
        self.APIPass = json[@"password"];
        // Store authentication info on the phone
        [[NSUserDefaults standardUserDefaults] setObject:self.APIKey forKey:@"key"];
        [[NSUserDefaults standardUserDefaults] setObject:self.APIPass forKey:@"pass"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    [uploadTask resume];
}

/** Create a new remote database */
- (void)createAction
{
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:5000/"];
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data,
                                                                    NSURLResponse *response,
                                                                    NSError *error) {
        // handle response
        NSLog(@"Got response %@ with error %@.\n", response, error);
        NSString *auth_data = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        NSLog(@"DATA:\n%@\nEND DATA\n", auth_data);
        NSDictionary* json = [NSJSONSerialization
                              JSONObjectWithData:data
                              options:kNilOptions
                              error:&error];
        NSLog(@"DB: %@ created.\n", json[@"db_name"]);
        self.remoteDatabase = json[@"db_name"];
        self.APIKey = json[@"key"];
        self.APIPass = json[@"password"];
        // Store authentication info on the phone
        [[NSUserDefaults standardUserDefaults] setObject:self.remoteDatabase forKey:@"db"];
        [[NSUserDefaults standardUserDefaults] setObject:self.APIKey forKey:@"key"];
        [[NSUserDefaults standardUserDefaults] setObject:self.APIPass forKey:@"pass"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    [dataTask resume];
}

/** Copy the databse name to the clipboard */
- (void)shareAction
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.remoteDatabase;
}

/** Load authentication data from local storage */
- (void)loadDefaults
{
    self.remoteDatabase = [[NSUserDefaults standardUserDefaults] stringForKey:@"db"];
    self.APIKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"key"];
    self.APIPass = [[NSUserDefaults standardUserDefaults] stringForKey:@"pass"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
