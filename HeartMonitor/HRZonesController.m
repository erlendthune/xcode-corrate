//
//  HRZonesController.m
//  Heart Rate Training
//
//  Created by Erlend Thune on 09/03/2025.
//  Copyright © 2025 Razeware LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Foundation/Foundation.h>
#import "HRZonesController.h"

@implementation HRZonesController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.hrmController) {
        if(self.hrmController.heartRateMax == UNSET_HR_MAX)
        {
            self.maxBmpZone.text = @"-";
            self.anaerobicBmpZone.text = @"-";
            self.aerobicBmpZone.text = @"-";
            self.lowAerobicBmpZone.text = @"-";
            self.moderateBmpZone.text = @"-";
        }
        else
        {
            self.maxBmpZone.text = [NSString stringWithFormat:@"%d", self.hrmController.heartRateMax];
            self.anaerobicBmpZone.text = [NSString stringWithFormat:@"%d", self.hrmController.heartRateMax * 90 / 100];
            self.aerobicBmpZone.text = [NSString stringWithFormat:@"%d", self.hrmController.heartRateMax * 80 / 100];
            self.lowAerobicBmpZone.text = [NSString stringWithFormat:@"%d", self.hrmController.heartRateMax * 70 / 100];
            self.moderateBmpZone.text = [NSString stringWithFormat:@"%d", self.hrmController.heartRateMax * 60 / 100];
        }
    }
}

- (IBAction)vo2Max:(id)sender {
    [self alertMessage:@"VO2 Max" s:@"Your heart is working at its maximum capacity. You will quickly run out of oxygen and your muscles will fill with lactic acid. You are burning nearly only carbohydrates."];
}

- (IBAction)anaerobic:(id)sender {
    [self alertMessage:@"Anaerobic" s:@"You are spending more oxygen than is available from your lungs. Your muscles are therefore gradually generating lactic acid. You cannot keep on like this forever. You are burning mostly carbohydrates."];
}

- (IBAction)aerobic:(id)sender {
    [self alertMessage:@"Aerobic" s:@"Your lungs provide enough oxygen and you burn a mix of carbohydrates and fat."];
}

- (IBAction)weightControl:(id)sender {
    [self alertMessage:@"Weight control" s:@"Your lungs provide enough oxygen and you burn mostly fat."];
}

- (IBAction)moderate:(id)sender {
    [self alertMessage:@"Moderate activity" s:@"Your lungs provide enough oxygen and you burn mostly fat. This is an easy and comfortable zone to exercise in."];
}

- (void)alertMessage:(NSString *)title s:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil]; // The handler is nil because no additional action is needed.
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
