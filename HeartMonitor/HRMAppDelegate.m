//
//  HRMAppDelegate.m
//  HeartMonitor
//
//  Created by Main Account on 12/13/13.
//  Copyright (c) 2013 Razeware LLC. All rights reserved.
//

#import "HRMAppDelegate.h"
#import "HRMAPHelper.h"
@import AVFoundation;
@implementation HRMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.

    //AVAudioSessionCategoryAmbient
    //AVAudioSessionCategoryOptionMixWithOthers
    //AVAudioSessionCategoryOptionDuckOthers
    NSError *setCategoryError = nil;
    AVAudioSession *aSession = [AVAudioSession sharedInstance];
    
    
    BOOL success = [aSession
                    setCategory: AVAudioSessionCategoryPlayback
                    withOptions: AVAudioSessionCategoryOptionMixWithOthers
                    error: &setCategoryError];
    
    // handle the error in setCategoryError
    if (!success)
    {
        NSLog(@"AudioSetup error");
    }
    
    success = [aSession setMode:AVAudioSessionModeDefault error:&setCategoryError];
    if (!success)
    {
        NSLog(@"AVAudioSessionModeDefault error");
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMediaServicesReset)
                                                 name:AVAudioSessionMediaServicesWereResetNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioHardwareRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    [HRMAPHelper sharedInstance];
    return YES;
}
- (void)handleAudioSessionInterruption:(NSNotification*)notification {
    
    NSNumber *interruptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
    NSNumber *interruptionOption = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
    
    switch (interruptionType.unsignedIntegerValue) {
        case AVAudioSessionInterruptionTypeBegan:{
            NSLog(@"AVAudioSessionInterruptionTypeBegan");
            // • Audio has stopped, already inactive
            // • Change state of UI, etc., to reflect non-playing state
        } break;
        case AVAudioSessionInterruptionTypeEnded:{
            // • Make session active
            // • Update user interface
            // • AVAudioSessionInterruptionOptionShouldResume option
            if (interruptionOption.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume) {
                // Here you should continue playback.
                //                [player play];
                NSLog(@"AVAudioSessionInterruptionOptionShouldResume");
            }
        } break;
        default:
            NSLog(@"handleAudioSessionInterruption default");
            break;
    }
}
- (void)handleMediaServicesReset {
    NSLog(@"handleMediaServicesReset");
    // • No userInfo dictionary for this notification
    // • Audio streaming objects are invalidated (zombies)
    // • Handle this notification by fully reconfiguring audio
}
- (void)audioHardwareRouteChanged:(NSNotification *)notification {
    NSLog(@"audioHardwareRouteChanged");
    // Your tests on the Audio Output changes will go here
    NSInteger routeChangeReason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue];
    if (routeChangeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
    {
        NSLog(@"The old device is unavailable == headphones have been unplugged");
    }
}
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
