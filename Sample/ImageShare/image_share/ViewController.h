//
//  ViewController.h
//  test_3
//
//  Created by Petro Tyurin on 7/23/14.
//  Copyright (c) 2014 Petro Tyurin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CloudantSync.h>

@interface ViewController : UIViewController

@property(nonatomic, weak) IBOutlet UICollectionView *collectionView;

@property CDTDatastoreManager *manager;

@property CDTDatastore *ds;

@end
