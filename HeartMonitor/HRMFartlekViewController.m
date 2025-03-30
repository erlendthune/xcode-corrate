#import <Foundation/Foundation.h>
#import "HRMFartlekViewController.h"
#import "HRMViewController.h"

@implementation HRMFartlekViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor]; // Set background color
    self.stopFartlekButton.enabled = NO;
    self.initialized = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    self.warmupTime.text = [NSString stringWithFormat:@"%d", self.hrmController.fartlekWarmupMinutes];
    self.repetitions.text = [NSString stringWithFormat:@"%d", self.hrmController.fartlekRepetitions];
    self.lowerHrtLimit.text = [NSString stringWithFormat:@"%d", self.hrmController.fartlekLowHeartRate];
    self.upperHrtLimit.text = [NSString stringWithFormat:@"%d", self.hrmController.fartlekHighHeartRate];
    [self saveVariables];

    if (self.hrmController && !self.initialized) {
        self.initialized = YES;
        if(!self.hrmController.disclaimerPresented)
        {
            [self.hrmController showDisclaimer];
        }
    }
    if(self.hrmController.hrmDisplay == HRM_BPM && [self.lowerHeartRateUnitLabel.text isEqualToString:@"%"])
    {
        self.lowerHeartRateUnitLabel.text = @"bmp";
        self.upperHeartRateUnitLabel.text = @"bmp";
    }
    else if(self.hrmController.hrmDisplay == HRM_PERCENT && [self.lowerHeartRateUnitLabel.text isEqualToString:@"bmp"])
    {
        self.lowerHeartRateUnitLabel.text = @"%";
        self.upperHeartRateUnitLabel.text = @"%";
    }
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.view endEditing:YES];
 }

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
    [self saveVariables];
}

-(void)saveVariables
{
    self.warmupTimeValue = [self getIntValueFromString:self.warmupTime.text];
    self.repetitionsValue = [self getIntValueFromString:self.repetitions.text];
    self.lowerHrtLimitValue = [self getIntValueFromString:self.lowerHrtLimit.text];
    self.upperHrtLimitValue = [self getIntValueFromString:self.upperHrtLimit.text];
    self.hrmController.fartlekWarmupMinutes = self.warmupTimeValue;
    self.hrmController.fartlekRepetitions = self.repetitionsValue;
    self.hrmController.fartlekHighHeartRate = self.upperHrtLimitValue;
    self.hrmController.fartlekLowHeartRate = self.lowerHrtLimitValue;
    [self.hrmController save];
}

- (IBAction)startFartlek:(id)sender {
    if (self.repetitionsValue == 0) {
        [self alertMessage:@"Invalid repetitions" s:@"Repetitions must be greater than 0."];
        return;
    }
    if (self.lowerHrtLimitValue > self.upperHrtLimitValue) {
        [self alertMessage:@"Invalid heartrates" s:@"Lower heart rate limit must be lower than upper heart rate limit."];
        return;
    }
    if(!self.hrmController.deviceConnected)
    {
        [self alertMessage:@"No connection" s:@"Cannot start fartlek without a heart rate connection."];
        return;
    }
    
    self.stopFartlekButton.enabled = YES;
    self.startFartlekButton.enabled = NO;
    [self.hrmController startFartlek:self];
}
- (IBAction)stopFartLek:(id)sender {
    [self.hrmController stopFartlek:true];
}

- (void)stopFartlek
{
    self.startFartlekButton.enabled = YES;
    self.stopFartlekButton.enabled = NO;
    self.feedback.text = @"Fill in the variables above and press start.";
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

- (int) getIntValueFromString:(NSString*)s
{
    if([s length])
    {
        return [s intValue];
    }
    return 0;
}
@end
