//
//  ViewController.m
//  test_3
//
//  Created by Petro Tyurin on 7/23/14.
//  Copyright (c) 2014 Petro Tyurin. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@end

@implementation ViewController

//UICollectionViewDataSource
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section
{
    return 2; // Guaranteed to be random. Chosen by a fair dice.
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView
{
    return 2;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"Cell " forIndexPath:indexPath];
    cell.backgroundColor = [UIColor darkGrayColor];
    
    CGRect  viewRect = CGRectMake(0, 0, 100, 100);
    UIImageView *myImageView = [[UIImageView alloc] initWithFrame:viewRect];
    myImageView.image = [UIImage imageNamed:@"image.jpg"];
    
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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"Cell "];
    UIBarButtonItem *addBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAction)];
    UIBarButtonItem *connectBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Connect" style:UIBarButtonItemStylePlain target:self action:@selector(connectAction)];
    UIBarButtonItem *pushBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Push" style:UIBarButtonItemStylePlain target:self action:@selector(connectAction)];
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:addBarButtonItem, connectBarButtonItem, pushBarButtonItem, nil];
    
    [self initDatastore];
}

-(void)addAction
{
    // Create a document
    NSDictionary *doc = @{
                          @"description": @"Buy milk",
                          @"completed": @NO,
                          @"type": @"com.cloudant.sync.example.task"
                          };
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:doc];
    
    NSError *error;
    CDTDocumentRevision *revision = [self.ds createDocumentWithBody:body
                                                                error:&error];
    if (error != NULL){
        NSLog(@"%@", error);
    }
    NSLog(@"add button clicked");
}

-(void)connectAction
{
    NSLog(@"connect button clicked");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
