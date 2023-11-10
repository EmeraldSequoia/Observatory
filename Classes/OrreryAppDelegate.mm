//
//  OrreryAppDelegate.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/16/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

//#include <sys/sysctl.h>
#import "OrreryAppDelegate.h"
#import "MainViewController.h"
#import "EOClock.h"
#import "ESUtil.hpp"
#import "ECAudio.h"
#undef ECTRACE
#import "ECTrace.h"
#import "ESAstronomy.hpp"
#import "Utilities.h"
#import "EOBatteryAndDAL.h"
#import "ESWatchTime.hpp"

#include "ESUtil.hpp"
#include "ESThread.hpp"
#include "ESTime.hpp"
#include "ESNTPDriver.hpp"
#include "ESLocationTimeHelper.hpp"

static UIWindow *theWholeWindow;
static bool currentDAL;

@implementation OrreryAppDelegate


@synthesize theWindow;
@synthesize mainViewController;

- (void)setupDefaults {
    NSNumber *defaultUNTP = [NSNumber numberWithBool:YES];
    NSNumber *defaultULS = [NSNumber numberWithBool:YES];
    NSNumber *defaultDAL = [NSNumber numberWithBool:NO];
    NSNumber *defaultSSP = [NSNumber numberWithBool:NO];
    NSNumber *defaultPlanet = [NSNumber numberWithInt:ECPlanetSun];
    NSMutableDictionary *defaultsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					 defaultUNTP,	    @"EOUseNTP",
					 defaultULS,	    @"EOUseLocationServices",
					 defaultDAL,	    @"EODisableAutoLock",
 					 defaultSSP,	    @"EOShowSubsolarPoint",
					 defaultPlanet,	    @"EOPlanet",
					 nil ];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
}

+ (UIWindow *)theWholeWindow {
    return theWholeWindow;
}

- (void)showQuickStart {
    [theClock showQuickStartIfNecessaryInView:[mainViewController view]];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
//    [Utilities printAllFonts];

#if 0    
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    printf("hw.machine: '%s'\n", [results UTF8String]);
    free(answer);
#endif
    
    ESUtil::init();
    ESThread::inMainThread();  // may be required to initialize main thread
    ESTime::init(ESNTPMakerFlag);

    UIUserNotificationType types = UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [application registerUserNotificationSettings:mySettings];

    new ESLocationTimeHelper;

    traceEnter("didFinishLaunchingWithOptions");  // NOTE: This must appear *AFTER* ESTime::init

    [self setupDefaults];
    currentDAL = [[NSUserDefaults standardUserDefaults] boolForKey:@"EODisableAutoLock"];
    ESAstronomyManager::initializeStatics();
    tracePrintf("init-ing EOClock");
    theWholeWindow = theWindow;
    theClock = [[EOClock alloc] init];	    // must precede MainViewController init
    
    tracePrintf("init-ing MainViewController");
    MainViewController *aController;
    aController = [[MainViewController alloc] initWithNibName:@"MainView-iPad" bundle:nil];

    self.mainViewController = aController;
    theWindow.rootViewController = mainViewController;
    [aController release];
    
    tracePrintf("making theWindow visible");
    [theWindow makeKeyAndVisible];
    
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(showQuickStart) userInfo:nil repeats:false];
    
    //[theClock showQuickStartIfNecessaryInView:[mainViewController view]];  // must follow initialization of view *and* initialization of clock

    [EOBatteryAndDAL startup];
    [ECAudio setup];

    [self printLocalizedStrings];

    traceExit("didFinishLaunchingWithOptions");
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EOAlarmEnabled"]) {
	[ECAudio setupSilentSounds];
    }
    ESUtil::goingToSleep();
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    traceEnter ("applicationDidBecomeActive");
    if ([ECAudio ringing]) {
	[ECAudio stopRinging];
    }
    [ECAudio cancelSilentSounds];
    ESUtil::wakingUp();
    [[EOClock theClock] adjustAlarmTime];
    ESTime::resync(false/*!userRequested*/);
    traceExit("applicationDidBecomeActive");
}

- (void)applicationSignificantTimeChange:(UIApplication *)application {
    ESUtil::significantTimeChange();
    [theClock checkSanityHereAndNow:nil];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    ESUtil::enteringBackground();
    [[EOClock theClock] goingToBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    ESUtil::leavingBackground();
    [[EOClock theClock] goingToForeground];
    [[EOClock theClock] resetTZ];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // ESUtil::willTerminate();  // Change to ESUtil to support Android, halfway done and abandoned, removed this function, but I don't think it did anything useful for EO.
    [[NSUserDefaults standardUserDefaults] synchronize];  // make sure we get written to disk even if we just changed something
    tracePrintf("Emerald Orrery EOJ");
}

- (void)dealloc {
    [mainViewController release];
    [theWindow release];
    [theClock release];
    [super dealloc];
}

- (void)printLocalizedStrings {
#if PRINTLOCALIZEDSTRINGS
NSString *h0 = NSLocalizedStringWithDefaultValue(@"Help Text0",
nil,
[NSBundle mainBundle],
@"The main gold colored hands indicate the hours, minutes and seconds in the usual 12-hour format.  The thin central hand with the large white arrowhead indicates the time in 24-hour format.",
@"help message0");

NSString *h1 = NSLocalizedStringWithDefaultValue(@"Help Text1",
nil,
[NSBundle mainBundle],
@"The colored rings represent the times when each 'planet' is above the horizon.  The big one behind the others is for the Sun. The 11 colored arrows represent the times of astronomical twilight, nautical twilight, civil twilight, sunrise/sunset, the 'golden hour' and solar noon.",
@"help message1");

NSString *h15 = NSLocalizedStringWithDefaultValue(@"Help Text1.5",
nil,
[NSBundle mainBundle],
@"The small dial labeled 'Eclipse Simulator' has three icons in the outer ring, representing the Sun, Moon, and Earth's shadow, as they appear to rotate in the sky around the Earth, and two thin red lines indicating the nodes of the Moon's orbit (points where it intersects the plane of the ecliptic).  The area inside the ring is normally empty but near the time of a lunar or solar eclipse an animation of the eclipse will appear there.",
@"help message1.5");
    
NSString *h2 = NSLocalizedStringWithDefaultValue(@"Help Text2",
nil,
[NSBundle mainBundle],
@"Tap 'Set' to enter set mode.  Then tap one of the time units to move forward (blue) or backward (red) by that amount.  Tapping 'phase' moves forward or back to the next quarter phase of the Moon.",
@"help message2");

NSString *h3 = NSLocalizedStringWithDefaultValue(@"Help Text3",
nil,
[NSBundle mainBundle],
@"Press and hold any of these spots to advance continuously.  Slide your finger off the button before raising it to 'latch' the button and advance continuously.  Tap 'Reset' to return to the present time.",
@"help message3");

NSString *h4 = NSLocalizedStringWithDefaultValue(@"Help Text4",
nil,
[NSBundle mainBundle],
@"Tap the altitude or azimuth dials to switch which planet's values are displayed there.",
@"help message4");

NSString *h5 = NSLocalizedStringWithDefaultValue(@"Help Text5",
nil,
[NSBundle mainBundle],
@"The red dot on the Earth map marks the current location.  If it isn't what you expect you may want to set it manually using the controls above.  If your location and timezone don't match then the astronomical information will look weird.",
@"help message5");

NSString *h6 = NSLocalizedStringWithDefaultValue(@"Help Text6",
nil,
[NSBundle mainBundle],
@"To set the alarm time, first turn the alarm ON then tap the Set button that appears.  When you  return to the main screen a red indicator will appear marking the alarm time on the outside of the 24-hour dial.  When the alarm time is reached a sound will play for about 20 seconds (or you can silence it immediately by tapping anywhere on the screen).  The alarm will NOT sound if Emerald Observatory is not running.",
@"help message6");

NSString *h7 = NSLocalizedStringWithDefaultValue(@"Help Text7",
nil,
[NSBundle mainBundle],
@"Emerald Observatory keeps its time display synchronized via NTP to the international standard atomic clocks.  This requires an Internet connection and it may take a few seconds each time the app starts up to synchronize.  The indicator in the lower left corner blinks while the sync in in progress and turns steady green when its completed successfully or steady yellow if a sync was not possible.",
@"help message7");

NSString *h8 = NSLocalizedStringWithDefaultValue(@"Help Text8",
nil,
[NSBundle mainBundle],
@"Check our website at http://emeraldSequoia.com/eo/ for more details (tap our logo on the bottom of this page).  Don't hesitate to send mail if you have questions or problems.  Comments and suggestions are also welcome.",
@"help message8");

NSString *i0 = NSLocalizedStringWithDefaultValue(@"iTC description0",
				  nil,
				  [NSBundle mainBundle],
@"Emerald Observatory displays a wealth of astronomical information all on one screen, in a unique but understandable format.  Information includes:",
				  @"iTC description0; terms here should match those in the other strings");
NSString *i1 = NSLocalizedStringWithDefaultValue(@"iTC description1",
				  nil,
				  [NSBundle mainBundle],
@"  - Times of rise and set for the Sun, the Moon, and the 5 classical planets\n    - Times of the beginning and ending of twilight\n    - Heliocentric orrery (display of the planets in orbit around the Sun)\n    - Altitude and azimuth for the same bodies (one body at a time)\n    - Current phase and relative apparent size of the Moon\n    - Current regions of day and night on a world map\n    - The Equation of Time, solar time, UTC time, and sidereal time\n    - Month, day, year, and leap-year indicator",
				  @"iTC description1");
NSString *i1a = NSLocalizedString(@"    - Daily Alarm\n    - Solar noon indication\n    - Noon on top option\n    - Option to stay on only when plugged in", @"iTC What's New");
NSString *i1b = NSLocalizedString(@"    - Improved graphics\n    - Solar and Lunar Eclipse Simulator", @"iTC What's New 1.3");
NSString *i2 = NSLocalizedStringWithDefaultValue(@"iTC description2",
				  nil,
				  [NSBundle mainBundle],
@"Also:\n    - Displayed times are synchronized via NTP to atomic clock standard\n    - Uses iPad location, or the latitude and longitude may be set manually\n    - Daily alarm function",
				  @"iTC description2");
NSString *i3 = NSLocalizedStringWithDefaultValue(@"iTC description3",
				  nil,
				  [NSBundle mainBundle],
				  @"Settings are available to allow the display to stay on continuously.",
				  @"iTC description3; terms here should match those in the other strings");
NSString *i4 = NSLocalizedStringWithDefaultValue(@"iTC description4",
				  nil,
				  [NSBundle mainBundle],
@"Tap on the display to move time forward or backward by a minute, hour, day, month, year or century.  A detailed manual for the operation of Emerald Observatory can be found at the 'Emerald Sequoia LLC Web Site' listed below, at http://emeraldsequoia.com/eo/",
				  @"iTC description4; terms here should match those in the other strings");
NSString *i5 = NSLocalizedStringWithDefaultValue(@"iTC description5",
				  nil,
				  [NSBundle mainBundle],
@"If you are having any trouble with the application whatsoever, please see our FAQ on the support page listed below and then contact us through that page if your problem is not resolved. We take pride in responding promptly to all support email requests.",
				  @"iTC description; terms here should match those in the other strings");

NSString *k0 = NSLocalizedString(@"time,clock,astronomy,NTP,atomic,sunset,photo,planet,moon,alarm,sunrise,twilight,earth,lunar,UTC", @"iTC keywords");

NSString *eclipseStr0 = NSLocalizedString(@"No eclipse", @"label for when no eclipse is visible");
NSString *eclipseStr1 = NSLocalizedString(@"Total lunar eclipse", @"label for a Total lunar eclipse");
NSString *eclipseStr2 = NSLocalizedString(@"Total solar eclipse", @"label for a Total solar eclipse");
NSString *eclipseStr3 = NSLocalizedString(@"Partial lunar eclipse", @"label for a Partial lunar eclipse");
NSString *eclipseStr4 = NSLocalizedString(@"Partial solar eclipse", @"label for a Partial solar eclipse");
NSString *eclipseStr5 = NSLocalizedString(@"Annular solar eclipse", @"label for a Annular solar eclipse");
NSString *eclipseStr6 = NSLocalizedString(@"Below horizon", @"label for when the eclipse is below the horizon");
NSString *eclipseStr7 = NSLocalizedString(@"Eclipse Simulator", @"label for the Eclipse Simulator or Viewer or Window");
    
NSString *translationQueue0 = NSLocalizedString(@"Eclipse simulator motion reversed to match main display", @"possible first run note");
NSString *translationQueue1 = NSLocalizedString(@"Display JD in status bar", @"Label for option to enable JD in the status bar");
NSString *translationQueue2 = NSLocalizedString(@"Display Moon age in status bar", @"Label for option to display moon age in the status bar");
NSString *translationQueue3 = NSLocalizedString(@"%s JD (TT)", @"Format string for displaying JD (TT) in status bar (%s is JD formatted by app as a number)");
NSString *translationQueue4 = NSLocalizedString(@"%s JD (UT)", @"Format string for displaying JD (UT) in status bar (%s is JD formatted by app as a number)");
NSString *translationQueue5 = NSLocalizedString(@"%s days", @"Format string for displaying Moon age in status bar (%s is age formatted by app as a number)");
NSString *translationQueue6 = NSLocalizedString(@"%Off by", @"phrase to indicate the the clock is different from real time by an amount");
    
    if (0) {	// don't bother with Help
    printf("%s\n\n", [h0 UTF8String]);
    printf("%s\n\n", [h1 UTF8String]);
    printf("%s\n\n", [h2 UTF8String]);
    printf("%s\n\n", [h3 UTF8String]);
    printf("%s\n\n", [h4 UTF8String]);
    printf("%s\n\n", [h5 UTF8String]);
    printf("%s\n\n", [h6 UTF8String]);
    printf("%s\n\n", [h7 UTF8String]);
    printf("%s\n\n", [h8 UTF8String]);
    }
    printf("%s\n\n", [i0 UTF8String]);
    printf("%s\n", [i1 UTF8String]);
    printf("%s\n\n", [i1a UTF8String]);
    printf("%s\n\n", [i2 UTF8String]);
    printf("%s\n\n", [i3 UTF8String]);
    printf("%s\n\n", [i4 UTF8String]);
    printf("%s\n\n", [i5 UTF8String]);
    printf("%s\n\n", [k0 UTF8String]);
#endif
}

@end
