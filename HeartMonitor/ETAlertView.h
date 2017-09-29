//
//  ETAlertView.h
//  winelist
//
//  Created by Erlend Thune on 01.05.14.
//  Copyright (c) 2014 Erlend Thune. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HRMViewController.h"

@interface ETAlertView : UIView
- (id)init:(int)imgWidth imgHeight:(int)imgHeight noOfTimesUsed:(int)noOfTimesUsed mvc:(HRMViewController*) mvc;

@property (weak, nonatomic) NSTimer * timer;
@property (nonatomic) int noOfTimesUsed;
@property (nonatomic) int counter;
@property (strong, nonatomic) UILabel *label;
@property (weak, nonatomic) HRMViewController* mvc;
@end
