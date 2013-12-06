//
//  CDTViewController.h
//  Project
//
//  Created by Michael Rhodes on 03/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CDTViewController : UITableViewController

@property (nonatomic, strong) IBOutlet UITextField *addTodoTextField;
-(IBAction)addTodoButtonTap:(id)sender;

@end
