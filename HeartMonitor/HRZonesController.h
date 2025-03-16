//
//  HRZonesController.h
//  Heart Rate Training
//
//  Created by Erlend Thune on 09/03/2025.
//  Copyright © 2025 Razeware LLC. All rights reserved.
//

#ifndef HRZonesController_h
#define HRZonesController_h
#import "HRMViewController.h"
@interface HRZonesController : UIViewController
@property (nonatomic, strong) HRMViewController *hrmController;

@property (weak, nonatomic) IBOutlet UILabel *maxBmpZone;
@property (weak, nonatomic) IBOutlet UILabel *anaerobicBmpZone;
@property (weak, nonatomic) IBOutlet UILabel *aerobicBmpZone;
@property (weak, nonatomic) IBOutlet UILabel *lowAerobicBmpZone;
@property (weak, nonatomic) IBOutlet UILabel *moderateBmpZone;
@end
#endif /* HRZonesController_h */
