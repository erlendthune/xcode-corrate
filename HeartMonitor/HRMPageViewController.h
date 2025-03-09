//
//  PageViewController.h
//  HeartMonitor
//
//  Created by Erlend Thune on 25/02/2025.
//  Copyright © 2025 Razeware LLC. All rights reserved.
//

#ifndef HRMPageViewController_h
#define HRMPageViewController_h

@interface HRMPageViewController : UIPageViewController <UIPageViewControllerDelegate, UIPageViewControllerDataSource>

@property (strong, nonatomic) NSArray *pageContents;

@end

#endif /* PageViewController_h */
