//
//  ETHelpViewController.m
//  Polet prisliste
//
//  Created by Erlend Thune on 09.05.14.
//  Copyright (c) 2014 Erlend Thune. All rights reserved.
//

#import "ETHelpViewController.h"

@interface ETHelpViewController ()

@end

@implementation ETHelpViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (IBAction)helpDone:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSString *thePath = [[NSBundle mainBundle] pathForResource:@"HeartRateTrainingUserGuide" ofType:@"html"];

    // Replace the UIView (helpView) with a WKWebView
     WKWebView *webView = [[WKWebView alloc] initWithFrame:self.helpView.bounds];
     webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

     // Add the WKWebView to the helpView
     [self.helpView addSubview:webView];

     // Retain a reference to the WKWebView if needed
     self.helpView = webView;

    if (thePath) {
        
        [self.helpView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:thePath isDirectory:NO]]];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
