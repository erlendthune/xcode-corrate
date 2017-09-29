//
//  ETAlertView.m
//  winelist
//
//  Created by Erlend Thune on 01.05.14.
//  Copyright (c) 2014 Erlend Thune. All rights reserved.
//

#import "ETAlertView.h"

@implementation ETAlertView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (id)init:(int)imgWidth imgHeight:(int)imgHeight noOfTimesUsed:(int)noOfTimesUsed mvc:(HRMViewController*) mvc
{
    CGRect rect = CGRectMake(0, 0, imgWidth, imgHeight);
    
    self = [super initWithFrame:rect];
    if (self) {
        self.mvc = mvc;
        
        self.noOfTimesUsed = noOfTimesUsed;
        self.counter = 0;
        self.mvc.nagscreenOnDisplay = true;

        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = 10.0;
        self.layer.borderWidth = 1.0;
        self.backgroundColor = [UIColor whiteColor];
        self.layer.borderColor = [[UIColor blackColor] CGColor];
        
//        int maxWidth = [[UIScreen mainScreen ]bounds].size.width;
        int fontSize = self.frame.size.height/15;
        CGRect rect = CGRectMake(fontSize, 0, imgWidth-fontSize*2, fontSize*6);
        self.label =  [[UILabel alloc] initWithFrame: rect];
        self.label.layer.cornerRadius = 10.0;
        
        self.label.font = [UIFont systemFontOfSize:fontSize];
        
        self.label.backgroundColor = [UIColor clearColor];
        //        self.label.text = @"2+2="; //etc...
        self.label.textAlignment = NSTextAlignmentCenter;
        [self UpdateLabelText];

        self.label.numberOfLines = 5;
//        self.label.adjustsFontSizeToFitWidth = YES;
        [self addSubview:self.label];
        
        // Add gesture recognizers
//        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(isTapped:)]];
        
        self.timer = [NSTimer scheduledTimerWithTimeInterval: 0.2 target:self selector:@selector(updateCountdown) userInfo:nil repeats: YES];

    }
    return self;
}

- (void)addOkButton
{
    int fontSize = self.frame.size.height/15;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.layer.cornerRadius = 10.0;
    button.layer.borderWidth = 1.0;
    button.titleLabel.textColor = [UIColor whiteColor];
    button.titleLabel.font = [UIFont fontWithName: @"Helvetica" size: fontSize];

//    [button addTarget:self action:@selector(aMethod:) forControlEvents:UIControlEventTouchUpInside];
    [button addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(aMethod:)]];

    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [[button layer] setBorderWidth:2.0f];
    button.layer.borderColor = [UIColor blackColor].CGColor;
    [button setTitle:@"Ok" forState:UIControlStateNormal];
    float x = self.frame.size.width-fontSize*4;
    float y = fontSize*8;
    button.frame = CGRectMake(x,y , fontSize*3, fontSize*1.5);
    [self addSubview:button];

    UIButton *button2 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button2.layer.cornerRadius = 10.0;
    button2.layer.borderWidth = 1.0;
    [button2 setTitleColor:[UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:1.0] forState:UIControlStateNormal];
    [[button2 layer] setBorderWidth:2.0f];
    button2.layer.borderColor = [UIColor blackColor].CGColor;
    button2.titleLabel.font = [UIFont fontWithName: @"Helvetica" size: fontSize];
    
//    [button2 addTarget:self action:@selector(buyMethod:) forControlEvents:UIControlEventTouchUpInside];
    [button2 addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(buyMethod:)]];
    [button2 setTitle:@"Purchase" forState:UIControlStateNormal];
    button2.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button2.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    float x2 = fontSize;
    float y2 = fontSize*8;
    button2.frame = CGRectMake(x2,y2 , fontSize*5, fontSize*1.5);
    [self addSubview:button2];

    UIButton *button3 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button3.layer.cornerRadius = 10.0;
    button3.layer.borderWidth = 1.0;
    [button3 setTitleColor:[UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:1.0] forState:UIControlStateNormal];
    //    button2.backgroundColor = [UIColor yellowColor];
    [[button3 layer] setBorderWidth:2.0f];
    button3.layer.borderColor = [UIColor blackColor].CGColor;
    button3.titleLabel.font = [UIFont fontWithName: @"Helvetica" size: fontSize];
    button3.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button3.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    
    //    [button2 addTarget:self action:@selector(buyMethod:) forControlEvents:UIControlEventTouchUpInside];
    [button3 addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(restorePurchaseMethod:)]];
    [button3 setTitle:@"Restore purchase" forState:UIControlStateNormal];
    float x3 = fontSize;
    float y3 = fontSize*10.5;
    button3.frame = CGRectMake(x3,y3 , fontSize*9, fontSize*1.5);
    [self addSubview:button3];

}

- (void)buyMethod:(UIButton*)button
{
    NSLog(@"Button  clicked.");
    self.mvc.nagscreenOnDisplay = false;
    [self.mvc purchase];
    [self removeFromSuperview];
}
- (void)restorePurchaseMethod:(UIButton*)button
{
    NSLog(@"Restore purchase button clicked.");
    self.mvc.nagscreenOnDisplay = false;
    [self.mvc restorePurchase];
    [self removeFromSuperview];
}



- (void)aMethod:(UIButton*)button
{
    NSLog(@"Button  clicked.");
    self.mvc.nagscreenOnDisplay = false;
    [self removeFromSuperview];
}

#pragma mark - Gesture recognizer handlers
- (void)isTapped:(UITapGestureRecognizer *)recognizer
{
//    [self.mvc answerQuestion:self];
}


-(void)UpdateLabelText
{
    NSString *s = nil;
    if(self.mvc.price)
    {
       s = [NSString stringWithFormat:@"You have used the app for free %d times. You can purchase it for %@", self.counter, self.mvc.price];
    }
    else
    {
        s = [NSString stringWithFormat:@"You have used the app for free %d times.", self.counter];
    }
    
    self.label.text = s;
}

-(void) updateCountdown
{
    self.counter++;
    [self UpdateLabelText];
   
    if(self.noOfTimesUsed == self.counter)
    {
        [self.timer invalidate];
        self.timer = nil;
        [self addOkButton];
    }
}



/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
