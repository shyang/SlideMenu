//
//  SlideMenuController.h
//  SlideMenu
//
//  Created by shaohua on 9/29/13.
//
//

#import <UIKit/UIKit.h>

@interface SlideMenuController : UIViewController

@property (nonatomic, readonly) UIViewController *selectedViewController;

@property (nonatomic, readonly) NSArray<NSArray<UIViewController *> *> *viewControllers;

/*
 two-level of viewControllers
 */
- (void)setViewControllers:(NSArray<NSArray<UIViewController *> *> *)viewControllers;

@end
