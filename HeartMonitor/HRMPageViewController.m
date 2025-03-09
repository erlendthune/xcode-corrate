//
//  HRMPageViewController.m
//  Heart Rate Training
//
//  Created by Erlend Thune on 25/02/2025.
//  Copyright © 2025 Razeware LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HRMPageViewController.h"
#import "HRMFartlekViewController.h"
@implementation HRMPageViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.dataSource = self;
    self.delegate = self; // Add this to update dots
    
    self.pageContents = @[@"Page1", @"Page2", @"Page3"]; // Storyboard IDs
    
    UIViewController *firstVC = [self viewControllerAtIndex:0];
    if (firstVC) {
        [self setViewControllers:@[firstVC]
                       direction:UIPageViewControllerNavigationDirectionForward
                        animated:YES
                      completion:nil];
    }
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
    return self.pageContents.count; // Number of dots
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    return [self currentPageIndex];
}

- (NSInteger)currentPageIndex {
    UIViewController *currentVC = self.viewControllers.firstObject;
    return currentVC.view.tag;
}

// Helper method to get a view controller
- (UIViewController *)viewControllerAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.pageContents.count) {
        return nil;
    }

    UIViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:self.pageContents[index]];
    vc.view.tag = index;
    return vc;
}

// Go to the previous page
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerBeforeViewController:(UIViewController *)viewController {
    NSInteger index = viewController.view.tag;
    return [self viewControllerAtIndex:index - 1];
}

// Go to the next page
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
        viewControllerAfterViewController:(UIViewController *)viewController {
    NSInteger index = viewController.view.tag;
    UIViewController *nextVC = [self viewControllerAtIndex:index + 1];
    
    // Check if the next view controller is of type HRMFartlekViewController
    if ([nextVC isKindOfClass:[HRMFartlekViewController class]]) {
        HRMFartlekViewController *fartlekVC = (HRMFartlekViewController *)nextVC;
        
        // Get the first view controller (HRMViewController) from the navigation stack
        HRMViewController *hrmVC = (HRMViewController *)self.viewControllers[0];
        
        // Set hrmController to the first view controller
        fartlekVC.hrmController = hrmVC;
    }
    
    return nextVC;
}


@end
