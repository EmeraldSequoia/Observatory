//
//  OrreryAppDelegate.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/16/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MainViewController, EOClock, EOLocationManager;

@interface OrreryAppDelegate : NSObject <UIApplicationDelegate> {
    IBOutlet UIWindow	*theWindow;
    MainViewController	*mainViewController;
    EOClock		*theClock;
}

@property (nonatomic, retain) IBOutlet UIWindow *theWindow;
@property (nonatomic, retain) MainViewController *mainViewController;

+ (UIWindow *)theWholeWindow;
- (void)printLocalizedStrings;

@end

