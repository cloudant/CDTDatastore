//
//  CDTReplicateController.h
//  Project
//
//  Created by Michael Rhodes on 08/01/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CloudantSync.h>

@interface CDTReplicateController : UIViewController<CDTReplicatorDelegate>

@property (nonatomic,strong) IBOutlet UITextView *logView;

-(IBAction)pullButtonTap:(id)sender;
-(IBAction)pushButtonTap:(id)sender;

@end
