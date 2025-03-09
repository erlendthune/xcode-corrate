//
//  HRMFartlekController.h
//  HeartMonitor
//
//  Created by Erlend Thune on 25/02/2025.
//  Copyright © 2025 Razeware LLC. All rights reserved.
//

#ifndef HRMFartlekController_h
#define HRMFartlekController_h
#import "HRMViewController.h"

@interface HRMFartlekViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *lowerHrtLimit;
@property (nonatomic, assign) int lowerHrtLimitValue;
@property (weak, nonatomic) IBOutlet UITextField *repetitions;
@property (nonatomic, assign) int repetitionsValue;
@property (nonatomic, strong) HRMViewController *hrmController;

@property (weak, nonatomic) IBOutlet UIButton *startFartlekButton;
@property (weak, nonatomic) IBOutlet UIButton *stopFartlekButton;
@property (weak, nonatomic) IBOutlet UITextView *feedback;
@property (weak, nonatomic) IBOutlet UITextField *warmupTime;
@property (nonatomic, assign) int warmupTimeValue;
@property (weak, nonatomic) IBOutlet UITextField *upperHrtLimit;
@property (nonatomic, assign) int upperHrtLimitValue;
@end
#endif /* HRMFartlekController_h */
