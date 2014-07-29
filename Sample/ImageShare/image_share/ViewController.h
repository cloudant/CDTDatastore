//
//  ViewController.h
//  test_3
//
//  Created by Petro Tyurin on 7/23/14.
//  Copyright (c) 2014 Petro Tyurin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CloudantSync.h>

@interface ViewController : UIViewController < UIImagePickerControllerDelegate, UINavigationControllerDelegate >

@property(nonatomic, weak) IBOutlet UICollectionView *collectionView;

@property CDTDatastoreManager *manager;

@property CDTDatastore *ds;

@property NSMutableArray *images;

@property NSString *remoteDatabase;

@property NSString *APIKey;

@property NSString *APIPass;

@end
