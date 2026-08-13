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
- (id)init:(int)imgWidth imgHeight:(int)imgHeight mvc:(HRMViewController*) mvc;

@property (weak, nonatomic) NSTimer * timer;
@property (strong, nonatomic) UIButton *okButton;
@property (strong, nonatomic) UILabel *label;
@property (strong, nonatomic) UILabel *headLine;
@property (weak, nonatomic) HRMViewController* mvc;
@end

