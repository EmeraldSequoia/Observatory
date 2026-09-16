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
- (void)setupWindow:(UIWindow *)window;

@end

// Owns the window and forwards scene life-cycle events to OrreryAppDelegate's
// old application-level handlers, which UIKit no longer calls once scenes are adopted.
@interface OrrerySceneDelegate : UIResponder <UIWindowSceneDelegate> {
    UIWindow *window;
    bool     hasEnteredBackground;
}

@property (nonatomic, retain) UIWindow *window;

@end

