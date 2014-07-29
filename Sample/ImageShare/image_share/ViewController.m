//
//  ViewController.m
//  test_3
//
//  Created by Petro Tyurin on 7/23/14.
//  Copyright (c) 2014 Petro Tyurin. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                              UIImagePickerControllerDelegate>

@end

@implementation ViewController

#define DEFAULT_USER @"ptiurin"

//UICollectionViewDataSource
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section
{
    return [self.images count];
    //return 1;
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"Cell " forIndexPath:indexPath];
    cell.backgroundColor = [UIColor darkGrayColor];
    
    CGRect  viewRect = CGRectMake(0, 0, 100, 100);
    UIImageView *myImageView = [[UIImageView alloc] initWithFrame:viewRect];
    
    //NSLog(@"Index row: %d", indexPath.row);
    myImageView.image = self.images[indexPath.row];
    
    [cell.contentView addSubview:myImageView];
    
    return cell;
}

//UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // TODO: Select Item
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // TODO: Deselect item
}

//UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize retval = CGSizeMake(100, 100);
    return retval;
}
//returns spacing, headers and footers
- (UIEdgeInsets)collectionView:
(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(50, 20, 50, 20);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"Cell "];
    UIBarButtonItem *addBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAction)];
    UIBarButtonItem *deleteBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteDatastore)];
    UIBarButtonItem *connectBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Connect" style:UIBarButtonItemStylePlain target:self action:@selector(connectAction)];
    UIBarButtonItem *createBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Create DB" style:UIBarButtonItemStylePlain target:self action:@selector(createAction)];
    UIBarButtonItem *pushBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Push" style:UIBarButtonItemStylePlain target:self action:@selector(pushReplicateAction)];
    UIBarButtonItem *pullBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Pull" style:UIBarButtonItemStylePlain target:self action:@selector(pullReplicateAction)];
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:addBarButtonItem,
                                               deleteBarButtonItem, connectBarButtonItem, pushBarButtonItem,
                                               pullBarButtonItem, createBarButtonItem, nil];
    
    self.images = [[NSMutableArray alloc] init];
    [self initDatastore];
    [self loadDocs];
    [self loadDefaults];
}

// Init imagePickerController
-(void)addAction
{
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
	picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:nil];
}

// Pick an image from the phone
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
	//imageView.image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    
    UIImage *img = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    [self.images addObject:img];
    [self.collectionView reloadData];
    [self createDoc:img];
}

-(void)createDoc:(UIImage *)image
{
    // Create a document
    NSDictionary *doc = @{
        @"description": @"Buy milk",
        @"completed": @NO,
        @"type": @"com.cloudant.sync.example.task"
    };
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:doc];
     
    NSError *error;
    CDTDocumentRevision *rev1 = [self.ds createDocumentWithBody:body
    error:nil];
    
    
    NSData *data = UIImageJPEGRepresentation(image, 0.7);
    CDTAttachment *attachment = [[CDTUnsavedDataAttachment alloc] initWithData:data
                                                                          name:@"image"
                                                                          type:@"image/jpg"];
    
    CDTDocumentRevision *rev2 = [self.ds updateAttachments:@[attachment]
                                                           forRev:rev1
                                                           error:&error];
     if (error != NULL){
         NSLog(@"%@", error);
     }
}

// Load images stored in a local datastore
-(void)loadDocs
{
    NSArray *docs = self.ds.getAllDocuments;
    for (CDTDocumentRevision *rev in docs){
        CDTAttachment *retrievedAttachment = [self.ds attachmentNamed:@"image"
                                                                      forRev:rev
                                                                       error:nil];
        if (retrievedAttachment != NULL){
            NSLog(@"%@",rev.docId);
            NSData *attachmentData = [retrievedAttachment dataFromAttachmentContent];
            UIImage *image = [UIImage imageWithData:attachmentData];
            [self.images addObject:image];
        }
    }
    [self.collectionView reloadData];
}

- (void)initDatastore
{
    // Create a CDTDatastoreManager using application internal storage path
    NSError *outError = nil;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
    NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                               inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [documentsDir URLByAppendingPathComponent:@"cloudant-sync-datastore"];
    NSString *path = [storeURL path];
    
    self.manager =
    [[CDTDatastoreManager alloc] initWithDirectory:path error:&outError];
    
    self.ds = [self.manager datastoreNamed:@"my_datastore"
                                     error:&outError];
    if (outError != NULL){
        NSLog(@"%@", outError);
    }
}

-(void)deleteDatastore
{
    NSError *outError = nil;
    [self.manager deleteDatastoreNamed:@"my_datastore" error:nil];
    self.ds = [self.manager datastoreNamed:@"my_datastore"
                                     error:&outError];
    if (outError != NULL){
        NSLog(@"%@", outError);
    }
    
    [self.images removeAllObjects];
    [self.collectionView reloadData];
}

-(void)pushReplicateAction
{
    CDTReplicatorFactory *replicatorFactory =
    [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.manager];
    [replicatorFactory start];
    
    // username/password can be Cloudant API keys
    //TODO: don't commit quthentication info
    NSString *s = [NSString stringWithFormat:@"https://%@:%@@%@.cloudant.com/%@", self.APIKey,
                   self.APIPass, DEFAULT_USER, self.remoteDatabase];
    NSURL *remoteDatabaseURL = [NSURL URLWithString:s];

    // Create a replicator that replicates changes from the local
    // datastore to the remote database.
    CDTPushReplication *pushReplication = [CDTPushReplication replicationWithSource:self.ds
                                                                             target:remoteDatabaseURL];
    NSError *error;
    CDTReplicator *replicator = [replicatorFactory oneWay:pushReplication error:&error];
    //check error
    
    // Start the replication and wait for it to complete
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
}

-(void)pullReplicateAction
{
    CDTReplicatorFactory *replicatorFactory =
    [[CDTReplicatorFactory alloc] initWithDatastoreManager:self.manager];
    [replicatorFactory start];
    
    // username/password can be Cloudant API keys
    //TODO: don't commit quthentication info
    NSString *s = [NSString stringWithFormat:@"https://%@:%@@%@.cloudant.com/%@", self.APIKey,
                   self.APIPass, DEFAULT_USER, self.remoteDatabase];
    NSURL *remoteDatabaseURL = [NSURL URLWithString:s];
    
    // Create a replicator that replicates changes from the local
    // datastore to the remote database.
    CDTPullReplication *pullReplication = [CDTPullReplication replicationWithSource:remoteDatabaseURL
                                                                             target:self.ds];
    NSError *error;
    CDTReplicator *replicator = [replicatorFactory oneWay:pullReplication error:&error];
    //check error
    
    // Start the replication and wait for it to complete
    [replicator start];
    while (replicator.isActive) {
        [NSThread sleepForTimeInterval:1.0f];
        NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
    }
    
    [self loadDocs];
}

-(void)connectAction
{
    NSLog(@"connect button clicked");
}

-(void)createAction
{
    NSString *url = @"http://127.0.0.1:5000/";
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:[NSURL URLWithString:url]
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
                NSLog(@"DB: %@ created.\n", [json objectForKey:@"key"]);
                self.remoteDatabase = json[@"db name"];
                self.APIKey = json[@"key"];
                self.APIPass = json[@"password"];
                // Store authentication info on the phone
                [[NSUserDefaults standardUserDefaults] setObject:self.remoteDatabase forKey:@"db"];
                [[NSUserDefaults standardUserDefaults] setObject:self.APIKey forKey:@"key"];
                [[NSUserDefaults standardUserDefaults] setObject:self.APIPass forKey:@"pass"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }] resume];
}

-(void)loadDefaults
{
    self.remoteDatabase = [[NSUserDefaults standardUserDefaults] stringForKey:@"db"];
    self.APIKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"key"];
    self.APIPass = [[NSUserDefaults standardUserDefaults] stringForKey:@"pass"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
