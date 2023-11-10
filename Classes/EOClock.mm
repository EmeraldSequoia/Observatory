//
//  EOClock.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/16/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#include "ESPlatform.h"

#import "Constants.h"
#import "ESPlatform.h"
#import "EOClock.h"
#import "EOBaseView.h"
#import "OrreryAppDelegate.h"
#import "MainViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "Constants.h"
#import "ESWatchTime.hpp"
#import "ESTimeLocAstroEnvironment.hpp"
#import "ESThread.hpp"
#import "ESAstronomy.hpp"
#import "EOScheduledView.h"
#import "EOHandView.h"
#import "EOHandTriangleView.h"
#import "EOHandAlarmView.h"
#import "EOHandBreguetView.h"
#import "EOHandNeedleView.h"
#import "EORingView.h"
#import "EOHandImageView.h"
#import "EOEclipseRingImageView.h"
#import "EOEclipseView.h"
#import "EOMoonAgeView.h"
#import "EOMoonView.h"
#import "EOEarthView.h"
#import "EOShuffleView.h"
#import "ECErrorReporter.h"
#import "ESTime.hpp"
#import "ECAudio.h"
#import "ESCalendar.hpp"
#import "ESErrorReporter.hpp"
#import "ESLocation.hpp"
#undef ECTRACE
#import "ECTrace.h"

#include "ESUtil.hpp"

static EOClock	    *theClock = NULL;
static bool	    aboutToReorient = false;
static ESWatchTime  *alarmTime = NULL;

static double	    centerX, centerY;

static NSDateFormatter	*dateFormatter;
static NSDateFormatter	*bigDateFormatter;
static NSDateFormatter	*bigDate2Formatter;
static NSDateFormatter	*utcDateFormatter;
static NSDateFormatter	*tzFormatter;
double fullWidth,fullHeight;

static const int    EOClockUpdate = 20;	// how many updates(ticks) per second
// static const int    EOButtonUpdate = 5;	// how many button repeats per second

static const ESTimeInterval EOLRECHECKTIME = 3600;
// static const ESTimeInterval EOLTIMEOUT     = 120;
static const double         EOLGOODERROR   = 140;

static int demoCycle = 0;
static double demoLat = 0, demoLng = 0;

static double lastWarnedLong = -200;
static ESTimeZone *lastWarnedTZ = NULL;

static NSString *
ESLocationAsString(ESLocation *location) {
    double _latitudeDegrees = location->latitudeDegrees();
    double _longitudeDegrees = location->longitudeDegrees();
    int latd = floor(fabs(_latitudeDegrees));
    int latm = floor((fabs(_latitudeDegrees) - latd)*60);
    double lats = (fabs(_latitudeDegrees) - latd - latm/60.0)*3600;
    NSString *ns = 
        _latitudeDegrees >= 0
        ? NSLocalizedString(@"N",@"one character abbreviation for 'north'")
        : NSLocalizedString(@"S",@"one character abbreviation for 'south'");
    int longd = floor(fabs(_longitudeDegrees));
    int longm = floor((fabs(_longitudeDegrees) - longd)*60);
    double longs = (fabs(_longitudeDegrees) - longd - longm/60.0)*3600;
    NSString *ew = _longitudeDegrees >= 0
        ? NSLocalizedString(@"E",@"one character abbreviation for 'east'")
        : NSLocalizedString(@"W",@"one character abbreviation for 'west'");
    return [NSString stringWithFormat:@"%d° %d' %2.0f\" %@, %d° %d' %3.1f\" %@", latd, latm, lats, ns, longd, longm, longs, ew];
}

@interface EOClock (EOClockPrivate)

- (void)buttonRepeater;
- (void)moveClockWidgetsForOrientation:(UIInterfaceOrientation)newOrientation newSize:(CGSize)newSize;
- (void)notifyTimeAdjustment;

@end

class ClockTimeSyncObserver : public ESTimeSyncObserver {
  public:
                            ClockTimeSyncObserver(EOClock *clock)
    :   ESTimeSyncObserver(ESThread::currentThread()),
        _clock(clock)
    {
    }
    void                    syncValueChanged()
    {
        [_clock notifyTimeAdjustment];
    }

  private:
    EOClock *_clock;
};

class ClockLocationObserver : public ESLocationObserver {
  public:
                            ClockLocationObserver(EOClock *clock)
    :   ESLocationObserver(EOLGOODERROR, EOLRECHECKTIME),
        _clock(clock)
    {
        assert(_clock);
    }

    virtual void            newLocationAvailable(ESLocation *location) {
        [_clock locationUpdate];
    }

  private:
    EOClock                 *_clock;
};

typedef enum eoseason {
    spring,
    summer,
    fall,
    winter} EOSeason;

@implementation EOClock

@synthesize time, env, noonOnTop, lastOrientation, setMode, dateLabel, finishingHelp;

- (EOSeason)seasonForHereAndNow {
    bool north = env->location()->latitudeDegrees() >= 0;		    // equator counts as north
    ESAstronomyManager *astro = env->astronomyManager();
    astro->setupLocalEnvironmentForThreadFromActionButton(true, time);
    double pa = astro->planetEclipticLongitude(ECPlanetSun);
    EOSeason ret;
    if (pa > M_PI*3/2)
	ret = north ? winter : summer;
    else if (pa > M_PI)
	ret = north ? fall : spring;
    else if (pa > M_PI/2)
	ret = north ? summer : winter;
    else
	ret = north ? spring : fall;
    astro->cleanupLocalEnvironmentForThreadFromActionButton(true);
    return ret;
}

// First-run quick-start alert part 1 of 2 start
static NSString *firstVersionRun = NULL;
static NSString *thisVersion = NULL;
static bool isNewbie = false;
static int shouldShowQuickStart = false;

-(void)showQuickStartIfNecessaryInView:(UIView *)parentView {
    if ([ECErrorReporter errorShowing] || !shouldShowQuickStart) {
	return;
    }
    NSBundle *mainBundle = [NSBundle mainBundle];
    ESAssert(thisVersion != NULL);
    NSString *versionSummaryString = NSLocalizedString(@"This app will be removed from the store on Nov 1 2023.\n\nPlease read the Details via the button below.", @"Version 2.3.5 first-run alert summary");
    NSString *quickStartButtonText = NSLocalizedString(@"Details", @"Details about Emerald Sequoia shutdown");

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"WARNING", @"WARNING")
                                                                   message:[NSString stringWithFormat:versionSummaryString, thisVersion]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    // Details
    UIAlertAction* quickStartAction = [UIAlertAction actionWithTitle:quickStartButtonText
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) { 
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://emeraldsequoia.com/esblog/2022/12/21/emerald-sequoias-future/"] options:@{} completionHandler:NULL];
    }];
    [alert addAction:quickStartAction];
    // Later
    UIAlertAction* laterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Later", @"First-run alert button to skip release notes for now")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) { 
        // Do nothing
    }];
    [alert addAction:laterAction];
    // Never
    UIAlertAction* neverAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Never", @"First-run alert button to permanently skip release notes")
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) { 
        // set the default, don't show again
        [[NSUserDefaults standardUserDefaults] setObject:thisVersion forKey:@"EOVersionMsg"];
        [[NSUserDefaults standardUserDefaults] synchronize];  // make sure we get written to disk (helpful for poor developers)
    }];
    [alert addAction:neverAction];

    OrreryAppDelegate *appDelegate = (OrreryAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate) {
        MainViewController *mainViewController = appDelegate.mainViewController;
        if (mainViewController) {
            [mainViewController presentViewController:alert animated:YES completion:nil];
        }
    }
}
// First-run quick-start alert part 1 of 2 end

@class UILocalNotification;
static UILocalNotification *localNotification;

+ (void)removeExistingLocalNotification {
    UIApplication *application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(scheduledLocalNotifications)]) {
	for (UILocalNotification *notification in [application scheduledLocalNotifications]) {
	    //printf("Found local notification at startup, removing %s\n", [[[notification fireDate] description] UTF8String]);
	    [application cancelLocalNotification:notification];
	}
    }
}

+ (void)setupLocalNotificationForAlarmStateEnabled:(bool)enabled {
    // Remove any existing local notification
    UIApplication* app = [UIApplication sharedApplication];
    bool useLocalNotifications = [UIApplication instancesRespondToSelector:@selector(scheduleLocalNotification:)];
    if (useLocalNotifications && localNotification) {
	//printf("Clearing local notification at %s\n", [[[localNotification fireDate] description] UTF8String]);
	[app cancelLocalNotification:localNotification];
	[localNotification release];
	localNotification = NULL;
    }

    // if (alarm enabled)
    if (enabled && useLocalNotifications) {
	Class classForUILocalNotification = NSClassFromString(@"UILocalNotification");
	if (classForUILocalNotification) {
	    localNotification = [[classForUILocalNotification alloc] init];
	    localNotification.repeatInterval = NSCalendarUnitDay;
	    localNotification.timeZone = ESCalendar_nsTimeZone(ESCalendar_localTimeZone());
	}
	localNotification.fireDate = [NSDate dateWithTimeIntervalSinceReferenceDate:ESTime::sysTimeForNTPTime(alarmTime->currentTime())];
	//printf("Setting up local notification at iPhone time %s\n",
	//       [[localNotification.fireDate description] UTF8String]);
	localNotification.soundName = @"Chime10.wav";
	localNotification.alertBody = [NSString stringWithFormat:@"%@ %@",
                                       NSLocalizedString(@"Alarm:", @"label for enable alarm clock switch"),
                                       NSLocalizedString(@"Observatory", @"App display name")];
	[app scheduleLocalNotification:localNotification];
    }	
}

/*
 Methods invoked in response to undo notifications
 */
- (bool)screenIsMirrored {
    NSArray *scrs = [UIScreen screens];
    NSUInteger scrcnt = [scrs count];
    if (scrcnt > 1) {
	if (scrcnt > 2) {
	    printf("%lu screens!\n", (unsigned long)scrcnt);
	}
	UIScreen *screenOne = [scrs objectAtIndex:1];
	if (screenOne.mirroredScreen == [UIScreen mainScreen]) {
	    return YES;
	}
    }
    return NO;
}

- (void)setStatusBar:(NSNotification *)notification {
    OrreryAppDelegate *appDelegate = (OrreryAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate) {
        MainViewController *mainViewController = appDelegate.mainViewController;
        if (mainViewController) {
            mainViewController.statusBarHidden = !finishingHelp && ([self screenIsMirrored] || setMode);
        }
    }
}

- (EOClock *)init {
    //printf("Locale identifier: %s\n", [[[NSLocale autoupdatingCurrentLocale] localeIdentifier] UTF8String]);
    if ((self = [super init])) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults stringForKey:@"EONoonOnTop"] == NULL) {
	    [defaults setObject:@"Yes" forKey:@"EONoonOnTop"];
	}

	// First-run quick-start alert part 2 of 2 start
	firstVersionRun = [defaults objectForKey:@"EOFirstVersionRun"];
	thisVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	//printf("this version %s\n", [thisVersion UTF8String]);
	if (!firstVersionRun) {
	    // NB from Steve 7 Dec 2010 -- the following block of code doesn't do what it wants to do; it wants to find a pref
	    // that doesn't exist if the user hasn't run any version of EO at all, but which does exist if the user has
	    // run an older (1.0 or 1.1) version.  But unfortunately at this point in the code flow, setupDefaults has
	    // been called in the app delegate and the given pref will always exist even if this is a first run.  Thus
	    // no one will be a newbie as we interpret it.

	    // See if this user has run EO before.
	    NSString *initString = [defaults objectForKey:@"EOUseNTP"];		// this pref has existed since Day One
	    if (initString) {
		firstVersionRun = @"1.1";  // The last version which didn't set EOFirstVersionRun, in case that isn't set
	    } else {
		firstVersionRun = thisVersion;
	    }
	    [defaults setObject:firstVersionRun forKey:@"EOFirstVersionRun"];
	    [defaults synchronize];
	}
	//printf("firstVersionRun version %s\n", [firstVersionRun UTF8String]);
	isNewbie = [firstVersionRun compare:thisVersion] == NSOrderedSame;
	shouldShowQuickStart = false;
	NSString *lastVersion = [defaults objectForKey:@"EOVersionMsg"];
	//printf("lastVersion %s\n", [lastVersion UTF8String]);
	if (lastVersion) {
	    if (thisVersion) {
		if ([thisVersion compare:lastVersion] != NSOrderedSame) {
                    if ([thisVersion compare:@"1.4.1"] == NSOrderedSame &&
                        ([lastVersion compare:@"1.4"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3.8"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3.7"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3.6"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3.5"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3.4"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3.3"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3.2"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3.1"] == NSOrderedSame ||
                         [lastVersion compare:@"1.3"] == NSOrderedSame)) {
                        // skip equivalent upgrade(s)
                    } else {
                        shouldShowQuickStart = true;
                    }
		}
	    }
	} else {
	    shouldShowQuickStart = true;
	}
	// First-run quick-start alert part 2 of 2 end

        // set up alarm
	time = new ESWatchTime;
	env = new ESTimeLocAstroEnvironment(ESCalendar_localTimeZoneName().c_str(), true/*observingIPhoneTime*/);
	ESTimeZone *estz = env->estz();
	ESDateComponents today;
	ESCalendar_localDateComponentsFromTimeInterval(ESTime::currentTime(), estz, &today);
	if ([[NSUserDefaults standardUserDefaults] stringForKey:@"EOAlarmInitialized"] == NULL) {
	    today.hour = 0;
	    today.minute = 0;
	    [[NSUserDefaults standardUserDefaults] setObject:@"Yes" forKey:@"EOAlarmInitialized"];
	} else {
	    ESWatchTime tmp;
	    tmp.restoreStateForWatch("EOAlarmTime");
	    ESDateComponents saved;
	    ESCalendar_localDateComponentsFromTimeInterval(tmp.currentTime(), estz, &saved);
	    today.hour = saved.hour;
	    today.minute = saved.minute;
	}
	today.seconds = 0;
	[EOClock removeExistingLocalNotification];
	alarmTime = new ESWatchTime(ESCalendar_timeIntervalFromLocalDateComponents(estz, &today));
        [self adjustAlarmTime];
	[EOClock setupLocalNotificationForAlarmStateEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"EOAlarmEnabled"]];

	centerX = [UIScreen mainScreen].applicationFrame.size.width/2;
	centerY = [UIScreen mainScreen].applicationFrame.size.height/2;
	lastOrientation = (UIInterfaceOrientation)UIDeviceOrientationUnknown;
	subviews = [[NSMutableArray alloc] initWithCapacity:40];
	dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"EEE, yyyy MMM dd  HH:mm:ss zzz (ZZZ)"];
	tzFormatter = [[NSDateFormatter alloc] init];
	[tzFormatter setDateFormat:@"zzz"];
	bigDateFormatter = [[NSDateFormatter alloc] init];
	[bigDateFormatter setDateFormat:@"MMM dd"];
	bigDate2Formatter = [[NSDateFormatter alloc] init];
	[bigDate2Formatter setDateFormat:@"EEEE"];
	utcDateFormatter = [[NSDateFormatter alloc] init];
	[utcDateFormatter setDateFormat:@"EEE dd"];
	[utcDateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	sanityTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(checkSanityHereAndNow:) userInfo:NULL repeats:NO];

        ESLocation *location = env->location();
        locationObserver = new ClockLocationObserver(self);
        location->addObserver(locationObserver);

        timeSyncObserver = new ClockTimeSyncObserver(self);
        ESTime::registerTimeSyncObserver(timeSyncObserver);
	noonOnTop = [[NSUserDefaults standardUserDefaults] boolForKey:@"EONoonOnTop"];

	// set up to receive notifications when mirroring is enabled
	NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
	[dnc addObserver:self selector:@selector(setStatusBar:) name:UIScreenDidConnectNotification object:NULL];
	[dnc addObserver:self selector:@selector(setStatusBar:) name:UIScreenDidDisconnectNotification object:NULL];
    }
    ESAssert(!theClock);
    theClock = self;
    return self;
}

- (void)adjustAlarmTime {
    while (alarmTime->currentTime() < ESTime::currentTime()) {
        alarmTime->advanceByDays(1, env/*usingEnv*/);
    }
    ESAssert(alarmTime->currentTime() > ESTime::currentTime());
    alarmTime->saveStateForWatch("EOAlarmTime");
}

+ (EOClock *)theClock {
    return theClock;
}

//// the main clock timer

- (void)addSubview:(UIView *)sub {
    ESAssert(![subviews containsObject:sub]);
    [subviews addObject:sub];
    [view addSubview:sub];
    [sub release];
}

- (void)setupTimerAndDateLabel {
    ESAssert(theTimer == NULL);	    // do this only once
    theTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/EOClockUpdate target:self selector:@selector(tick) userInfo:NULL repeats:true];
    dateLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0, -20, fullWidth, 20)] autorelease];
    dateLabel.font = [UIFont boldSystemFontOfSize:14];
    dateLabel.textAlignment = NSTextAlignmentCenter;
    dateLabel.backgroundColor = [UIColor clearColor];
    dateLabel.textColor = [UIColor whiteColor];
    [view addSubview:dateLabel];
}

ESTimeInterval lastButtonPress = 0;
BOOL timeChanged = false;

- (void)doJumps {
    if (ESSystemTimeBase::currentSystemTime() - lastButtonPress < 0.75) { // Wait at least 1.5 seconds before repeating
	return;
    }
    if (minuteStep != 0) {
	time->advanceBySeconds(60*minuteStep);
	timeChanged = true;
    }
    if (hourStep != 0) {
	time->advanceBySeconds(3600*hourStep);
	timeChanged = true;
    }
    if (dayStep != 0) {
	time->advanceByDays(dayStep, env/*usingEnv*/);
	timeChanged = true;
    }
    if (monthStep != 0) {
	time->advanceByMonths(monthStep, env/*usingEnv*/);
	timeChanged = true;
    }
    if (yearStep != 0) {
	time->advanceByYears(yearStep, env/*usingEnv*/);
	timeChanged = true;
    }
    if (centStep != 0) {
	time->advanceByYears(centStep*100, env/*usingEnv*/);
	timeChanged = true;
    }
    if (lunarStep != 0) {
	ESAstronomyManager *astro = env->astronomyManager();
	astro->setupLocalEnvironmentForThreadFromActionButton(false, time);
	if (lunarStep == -1) {
	    time->setToFrozenDateInterval(astro->prevMoonPhase());
	} else {
	    time->setToFrozenDateInterval(astro->nextMoonPhase());
	}
	astro->cleanupLocalEnvironmentForThreadFromActionButton(false);
	//	[time advanceBySeconds:29.530589 * 3600 * 24];	// 1.0 did a lunar month
	timeChanged = true;
    }
    if (!time->isCorrect() && !aboutToReorient) {
	dateLabel.text = [NSString stringWithFormat:@"%@  <%s>  %@",
			  [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:time->currentTime()]],
			  time->representationOfDeltaOffsetUsingEnv(env).c_str(),
                          ESLocationAsString(env->location())];
	dateLabel.textColor = [UIColor colorWithRed:.75 green:0 blue:0 alpha:1];
    } else if (resetBool && !aboutToReorient) {
	dateLabel.text = [NSString stringWithFormat:@"%@  --  %@",
			  [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:time->currentTime()]],
                          ESLocationAsString(env->location())];
	dateLabel.textColor = [UIColor whiteColor];
    }
    //[view backgroundCheck];
}

static int ticks = 0;

- (UIColor *)NTPStatusColor {
//  if ([ECOptions purpleZone]) {
//      return ECmagenta;
//  }
    ESTimeSourceStatus status = ESTime::currentStatus();
    switch (status) {
      case ESTimeSourceStatusOff:                   // No synchronization is being done
        return [UIColor clearColor];
      case ESTimeSourceStatusSynchronized:          // We're good
      case ESTimeSourceStatusNoNetSynchronized:     // We were synchronized before but the net wasn't available when the user asked for a resync
      case ESTimeSourceStatusFailedSynchronized:    // We were synchronized before but we failed when the user asked for a resync
        return [UIColor greenColor];
      case ESTimeSourceStatusPollingRefining:       // We were kind of good (failedRefining) and the user has asked for a resync and we're trying
      case ESTimeSourceStatusPollingSynchronized:   // We're good but the user has asked for a resync and we're trying
      case ESTimeSourceStatusRefining:              // We've gotten some packets but they aren't good enough to say we're good
        return ((ticks % EOClockUpdate) > EOClockUpdate/2) ? [UIColor  greenColor] : [UIColor clearColor];
      case ESTimeSourceStatusPollingUnsynchronized: // We know nothing but we're trying
      case ESTimeSourceStatusFailedRefining:        // We got some packets so we're kind of synchronized but not completely good
      case ESTimeSourceStatusNoNetRefining:         // We had some packets before but the net wasn't available when we tried to refine
        return ((ticks % EOClockUpdate) > EOClockUpdate/2) ? [UIColor yellowColor] : [UIColor clearColor];
      case ESTimeSourceStatusFailedUnynchronized:   // We were unsynchronized before and we failed the last time we tried
      case ESTimeSourceStatusUnsynchronized:        // We know nothing
      case ESTimeSourceStatusNoNetUnsynchronized:   // We were unsynchronized before but the net wasn't available when the user asked for a resync
        return [UIColor yellowColor];
      default:
        assert(false);
    }
}

- (void)updateLabelsSeasonsAlarmDSTAndStatusIndicator {
#ifndef CAPTUREDEFAULTS
    NSDate *currentDate = time->currentDate();
    if ([[[NSLocale autoupdatingCurrentLocale] localeIdentifier] caseInsensitiveCompare:@"ja_JP"] == NSOrderedSame) {
	bigDate.text = [[bigDateFormatter stringFromDate:currentDate] stringByAppendingString:@"日"];
    } else {
	bigDate.text = [bigDateFormatter stringFromDate:currentDate];
    }
    bigDate2.text = [bigDate2Formatter stringFromDate:currentDate];
    utcdayLabel.text = [utcDateFormatter stringFromDate:currentDate];
    tzLabel.text = [tzFormatter stringFromDate:currentDate];
    yearLabel.text = [NSString stringWithFormat:@"%d", time->yearNumberUsingEnv(env)];
    yearLabel.textColor = time->eraNumberUsingEnv(env) == 0 ? [UIColor redColor] : [UIColor whiteColor];
    int yearNumber = time->yearNumberUsingEnv(env);
    int eraNumber = time->eraNumberUsingEnv(env);
    int leapPhase;
    if (eraNumber && yearNumber >= 1582) { // Gregorian
	leapPhase = yearNumber % 400 == 0 ?  400 : 
		    yearNumber % 100 == 0 ?  100 :
		    yearNumber %   4 == 0 ?    4 :
		    yearNumber %   4 == 1 ?    1 :
		    yearNumber %   4 == 2 ?    2 :
					       3;
    } else { 
	if (eraNumber) { // Julian
	    leapPhase = yearNumber %   4 == 0 ? 4 :
			yearNumber %   4 == 1 ? 1 :
			yearNumber %   4 == 2 ? 2 :
					        3;
	} else { // proleptic Julian
	    yearNumber -= 1;
	    leapPhase = yearNumber %   4 == 0 ? 4 :
			yearNumber %   4 == 1 ? 1 :
			yearNumber %   4 == 2 ? 2 :
					        3;
	}
    }
    if (leapPhase == 4) {
	leapLabel.text = NSLocalizedString(@"leap", @"term for years with Feb 29 as in: '2012 is a leap year'");
	leapLabel.hidden = NO;
    } else if (leapPhase == 100) {
	leapLabel.text = NSLocalizedString(@"not leap", @"term for years without Feb 29 as in '2010 is not a leap year'");
	leapLabel.hidden = NO;
    } else if (leapPhase == 400) {
	leapLabel.text = [NSString stringWithFormat:NSLocalizedString(@"leap (%d)", @"term for years with Feb 29"), leapPhase];
	leapLabel.hidden = NO;
    } else {
	leapLabel.hidden = YES;
	//leapLabel.text = [NSString stringWithFormat:@"(%d)", leapPhase];
    }
#endif
    NTPStatusLabel.textColor = [self NTPStatusColor];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EOAlarmEnabled"]) {
	if (alarmHand.hidden) {
	    alarmHand.hidden = NO;
	}
	if (ESTime::currentTime() > alarmTime->currentTime()) {
	    [ECAudio startRinging:10];
	    snoozeBut.hidden = NO;
	    alarmTime->advanceByDays(1, env/*usingEnv*/);
	    alarmTime->saveStateForWatch("EOAlarmTime");
	}
	if (![ECAudio ringing] && !snoozeBut.hidden) {
	    snoozeBut.hidden = YES;
	}
    } else {
	if (!alarmHand.hidden) {
	    alarmHand.hidden = YES;
	    snoozeBut.hidden = YES;
	}
    }
#ifdef SEASONS
#ifndef CAPTUREDEFAULTS
    EOSeason sn = [self seasonForHereAndNow];
    springIcon.alpha = sn == spring ? 1 : .25;
    summerIcon.alpha = sn == summer ? 1 : .25;
    fallIcon.alpha   = sn == fall   ? 1 : .25;
    winterIcon.alpha = sn == winter ? 1 : .25;
#endif
#endif
#ifdef DSTINDICATORS
#ifndef CAPTUREDEFAULTS
    bool isDSTnow = time->isDSTUsingEnv(env);
    double now = time->currentTime();
    double nextDST = time->nextDSTChangeUsingEnv(env);
    double prevDST = time->prevDSTChangePrecisely(false, env/*usingEnv*/);
    if ((now - prevDST) < 3600*12) {
	springDSTIndicator.alpha = isDSTnow;
	fallDSTIndicator.alpha = !isDSTnow;
    } else if ((nextDST - now) < 3600*12) {
	springDSTIndicator.alpha = !isDSTnow;
	fallDSTIndicator.alpha = isDSTnow;
    } else {
	springDSTIndicator.alpha = 0;
	fallDSTIndicator.alpha = 0;
    }
#endif
#endif
}

static bool inBackground = false;
static bool firstAfterComingToForeground = true;

- (void)goingToBackground {
    inBackground = true;
}

- (void)goingToForeground {
    inBackground = false;
    firstAfterComingToForeground = true;
    [self notifyTimeAdjustment];
}

- (void)tick {
    // update a few special parts
    ++ticks;
    
    [self updateLabelsSeasonsAlarmDSTAndStatusIndicator];	// must do this even when asleep (for alarms)

    if (setMode) {
	[self doJumps];
    }

    if (!inBackground) {
	// now get each part to redraw itself if its target time is reached
	for (EOScheduledView *v in subviews) {
	    [v tick:timeChanged];
	}
	timeChanged = false;
    }
    firstAfterComingToForeground = false;
}

- (void)notifyTimeAdjustment {
    if (!setMode) {
	[self resetTargets];
    }
    [EOClock setupLocalNotificationForAlarmStateEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"EOAlarmEnabled"]];
}

- (void)resetTargets {
    for (EOScheduledView *v in subviews) {
	[v resetTarget];
    }
}

- (void)resetTZ {
    ESCalendar_localTimeZoneChanged();	// resets to device's current zone
    env->setTimeZone(ESCalendar_localTimeZone());
    [tzFormatter setTimeZone:ESCalendar_nsTimeZone(ESCalendar_localTimeZone())];
    lastWarnedTZ = NULL;
    lastWarnedLong = -200;
}

- (void)buttonActionDn:(id)sender {
    lastButtonPress = 0; // Make sure we take this one
    if (sender == dayBut) {	    // xxxButs are the red (go backward) ones; xxxBugB are the blue (go forward) ones
	dayStep = -1;
	time->stop();
	[self doJumps];
    } else if (sender == yearBut) {
	yearStep = -1;
	time->stop();
	[self doJumps];
    } else if (sender == centBut) {
	centStep = -1;
	time->stop();
	[self doJumps];
    } else if (sender == monBut) {
	monthStep = -1;
	time->stop();
	[self doJumps];
    } else if (sender == lunarBut) {
	lunarStep = -1;
	time->stop();
	[self doJumps];
    } else if (sender == hourBut) {
	hourStep = -1;
	time->stop();
	[self doJumps];
    } else if (sender == minuteBut) {
	minuteStep = -1;
	time->stop();
	[self doJumps];
    } else if (sender == dayButB) {
	dayStep = 1;
	time->stop();
	[self doJumps];
    } else if (sender == centButB) {
	centStep = 1;
	time->stop();
	[self doJumps];
    } else if (sender == yearButB) {
	yearStep = 1;
	time->stop();
	[self doJumps];
    } else if (sender == monButB) {
	monthStep = 1;
	time->stop();
	[self doJumps];
    } else if (sender == lunarButB) {
	lunarStep = 1;
	time->stop();
	[self doJumps];
    } else if (sender == hourButB) {
	hourStep = 1;
	time->stop();
	[self doJumps];
    } else if (sender == minuteButB) {
	minuteStep = 1;
	time->stop();
	[self doJumps];
    } else if (sender == snoozeBut) {
	[ECAudio stopRinging];
    } else if (sender == azBut || sender == altBut) {
	ECPlanetNumber p = azHand.planet;
        if (sender == azBut) {
            p = (ECPlanetNumber)((int)p - 1);  // Thanks, compiler! This makes it *much* more readable than p--!
            if (p == ECPlanetEarth) {
                p = (ECPlanetNumber)((int)p - 1);
            } else if (p < 0) {
                p = ECPlanetSaturn;
            }
        } else {
            p = (ECPlanetNumber)((int)p + 1);
            if (p == ECPlanetEarth) {
                p = (ECPlanetNumber)((int)p + 1);
            } else if (p > ECPlanetSaturn) {
                p = ECPlanetSun;
            }
        }
	altHand.planet = p;
	azHand.planet = p;
	[[NSUserDefaults standardUserDefaults] setInteger:p forKey:@"EOPlanet"];
	azLabel.text = [Utilities nameOfPlanetWithNumber:p];
    	altLabel.text = [Utilities nameOfPlanetWithNumber:p];
	[azHand resetTarget];
    	[altHand resetTarget];
    } else if (sender == demoBut) {
	ESDateComponents comps;
	double newLat =0, newLng = 0;
	const char *newTzName = NULL;
	if (demoLng == 0) {
	    demoLat = env->location()->latitudeDegrees();
	    demoLng = env->location()->longitudeDegrees();
	}
	switch (demoCycle) {
	    case 0:	// partial solar
		comps.era = 1;
		comps.year = 2012;
		comps.month = 5;
		comps.day = 20;
		comps.hour = 18;
		comps.minute = 54;
		comps.seconds = 39.5;
		newLat = 40;
		newLng = -120;
		newTzName = "America/Los_Angeles";
		break;
	    case 1:	// partial lunar
		comps.era = 1;
		comps.year = 2010;
		comps.month = 6;
		comps.day = 26;
		comps.hour = 4;
		comps.minute = 58;
		comps.seconds = 5;
		newLat = 30;
		newLng = -120;
		newTzName = "America/Los_Angeles";
		break;
	    case 2:	// total lunar
		comps.era = 1;
		comps.year = 2010;
		comps.month = 12;
		comps.day = 21;
		comps.hour = 0;
		comps.minute = 25;
		comps.seconds = 10;
		newLat = 20;
		newLng = -120;
		newTzName = "America/Los_Angeles";
		break;
	    case 3:	// total solar
		comps.era = 1;
		comps.year = 2017;
		comps.month = 8;
		comps.day = 21;
		comps.hour = 10;
		comps.minute = 20;
		comps.seconds = 15;
		newLat = 44.66;
		newLng = -121;
		newTzName = "America/Los_Angeles";
		break;
	    case 4:	// annular solar
		comps.era = 1;
		comps.year = 2010;
		comps.month = 1;
		comps.day = 15;
		comps.hour = 12;
		comps.minute = 37;
		comps.seconds = 46;
		newLat = (1+37.4/60);
		newLng = (69+17.4/60);
		newTzName = "Asia/Kolkata";
#ifndef CAPTURESPECIALS
		demoCycle = -1;		// wrap around next time
#endif
		break;
#ifdef CAPTURESPECIALS
	    case 5:	// hands in good position
		comps.era = 1;
		comps.year = 2010;
		comps.month = 12;
		comps.day = 16;
		comps.hour = 13;
		comps.minute = 50;
		comps.seconds = 24.3;
		newLat = 38;
		newLng = -122;
		newTzName = "America/Los_Angeles";
		break;
	    case 6:	// planets in good position
		comps.era = 1;
		comps.year = 1988;
		comps.month = 12;
		comps.day = 4;
		comps.hour = 20;
		comps.minute = 27;
		comps.seconds = 12;
		newLat = 38;
		newLng = -122;
		newTzName = "America/Los_Angeles";
		break;
            case 7: // Slobodan's misalignment test
                comps.era = 1;
                comps.year = 2012;
                comps.month = 6;
                comps.day = 22;
                comps.hour = 20;
                comps.minute = 52;
                comps.seconds = 0;
                newLat = 37.206;
                newLng = -121.954;
                newTzName = "America/Los_Angeles";
                demoCycle = -1;
                break;
#endif
	    default:
		ESAssert(false);
	}
	++demoCycle;
	ESCalendar_setLocalTimeZone(newTzName);
	env->setTimeZone(ESCalendar_localTimeZone());
	[tzFormatter setTimeZone:ESCalendar_nsTimeZone(ESCalendar_localTimeZone())];
        env->location()->setToUserLocation(newLat, newLng, 0/*accuracyInMeters*/);
	ESTimeInterval t = ESCalendar_timeIntervalFromLocalDateComponents(ESCalendar_localTimeZone(), &comps);
	time->setToFrozenDateInterval(t);
	timeChanged = true;
    } else if (sender == resetBut) {
	time->stop();
	if (setMode) {
	    time->resetToLocal();
	    [self resetTargets];
	    setMode = false;
	    demoBut.hidden = true;
	    centBut.hidden = true;
	    yearBut.hidden = true;
	    dayBut.hidden = true;
	    monBut.hidden = true;
	    lunarBut.hidden = true;
	    hourBut.hidden = true;
	    minuteBut.hidden = true;
	    centButB.hidden = true;
	    yearButB.hidden = true;
	    dayButB.hidden = true;
	    monButB.hidden = true;
	    lunarButB.hidden = true;
	    hourButB.hidden = true;
	    minuteButB.hidden = true;
	    //resetBut.titleLabel.font = [UIFont fontWithName:@"Arial" size:18];
	    resetBut.titleLabel.textColor = [UIColor colorWithRed:.75 green:0 blue:0 alpha:1];
	    [resetBut setTitle:NSLocalizedString(@"Set", @"Set (verb)") forState:UIControlStateNormal];
	    demoCycle = 0;
	    if (demoLng != 0) {
		[self resetTZ];
                env->location()->setToUserLocation(demoLat, demoLng, 0/*accuracyInMeters*/);	// must be after setting of timezone
		demoLat = demoLng = 0;
	    }
	} else {
	    setMode = true;
#ifndef NDEBUG
	    demoBut.hidden = false;
#endif
	    yearBut.hidden = false;
	    centBut.hidden = false;
	    dayBut.hidden = false;
	    monBut.hidden = false;
	    lunarBut.hidden = false;
	    hourBut.hidden = false;
	    minuteBut.hidden = false;
	    centButB.hidden = false;
	    yearButB.hidden = false;
	    dayButB.hidden = false;
	    monButB.hidden = false;
	    lunarButB.hidden = false;
	    hourButB.hidden = false;
	    minuteButB.hidden = false;
	    [resetBut setTitle:NSLocalizedString(@"Reset", @"label for the button that reverses the action of 'Set'") forState:UIControlStateNormal];
            [self doJumps];     // update it NOW, not one second from now
	    //resetBut.titleLabel.font = [UIFont fontWithName:@"Arial" size:14];
	    resetBut.titleLabel.textColor = [UIColor whiteColor];
	}
	resetBool = false;
	centStep = yearStep = dayStep = hourStep = monthStep = lunarStep = minuteStep = 0;
	[self setStatusBar:NULL];
        dateLabel.hidden = !setMode;
    } else if (sender == NTPStatusBut) {
        ESTime::resync(true/*userRequested*/);
    } else {
	ESAssert(false);
    }
    lastButtonPress = ESSystemTimeBase::currentSystemTime();
}

- (void)buttonActionUp:(id)sender {
    if (sender == dayBut || sender == dayButB) {
	dayStep = 0;
    } else if (sender == centBut || sender == centButB) {
	centStep = 0;
    } else if (sender == yearBut || sender == yearButB) {
	yearStep = 0;
    } else if (sender == monBut || sender == monButB) {
	monthStep = 0;
    } else if (sender == lunarBut || sender == lunarButB) {
	lunarStep = 0;
    } else if (sender == hourBut || sender == hourButB) {
	hourStep = 0;
    } else if (sender == minuteBut || sender == minuteButB) {
	minuteStep = 0;
    } else if (sender == resetBut) {
//	time->resetToLocal();
//	[self resetTargets];
//	resetBool = yearBool = dayBool = hourBool = monthBool = lunarBool = minuteBool = false;
    } else if (sender == azBut || sender == altBut || sender == snoozeBut) {
	// do nothing
    } else if (sender == NTPStatusBut || sender == demoBut) {
	// do nothing
    } else {
	ESAssert(false);
    }
}

static NSTimer *sanityTimer = NULL;

- (void)checkSanityHereAndNow:(id)foo {
    ESLocation *location = env->location();
    [self checkSanityForTimezone:ESCalendar_localTimeZone()
                        latitude:location->latitudeDegrees()
		       longitude:location->longitudeDegrees()];
}

- (void)checkSanityForTimezone:(ESTimeZone *)tz latitude:(double)lat longitude:(double)lng {	    // in degrees
    if ([ECErrorReporter errorShowing]) {
	return;
    }
    sanityTimer = NULL;	    // no need for another one
    if (lat == 0 && lng == 0 && theClock != NULL) {	// hack: don't warn on the first run
	[[ECErrorReporter theErrorReporter] reportWarning:[NSString stringWithFormat:NSLocalizedString(@"Your location\n\n%@\n\nappears to be invalid.  Turn 'Use Location Services' ON or enter a valid latitude and longitude.", @"Invalid location warning message"),
                                                           ESLocationAsString(env->location())]];
	return;
    }
    ESTimeInterval now = ESTime::currentTime();
    if (fabs(ESTime::skewForReportingPurposesOnly()) > TOOBIGSKEW || (fabs(lng - lastWarnedLong) < 1.0 && tz == lastWarnedTZ)) {
	//tracePrintf("checkSanityForTimezone: big skew or same bad place as previously");
	return;
    }
    float tzCenter = (ESCalendar_tzOffsetForTimeInterval(tz, now)/3600 - (ESCalendar_isDSTAtTimeInterval(tz, now) ? 1.0 : 0.0)) * 15;
    double delta = fabs(lng - tzCenter);
    if (delta > 180) {
	delta = 360 - delta;
    }
    if (delta > 25 && !(lat == 0 && lng == 0)) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", @"Warning")
                                    message:NSLocalizedStringWithDefaultValue(@"tz-pos warning",
                                                                              NULL,
                                                                              [NSBundle mainBundle],
                                                                              @"Your location and timezone appear mismatched; see the timezone label above the 6 o'clock position and the red dot on the world map.  You may need to change your timezone in the Settings app (General / Date & Time), or you may need to wait for the device to determine its timezone and location.  You can force a location update by toggling the 'Use Location Services' switch or set the location manually.",
                                                                              @"timezone / position mismatch warning message")
                                    preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* detailsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Show details", @"Details")
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action) {
                [ECErrorReporter setErrorShowing:false];
                if (!lastWarnedTZ) {
                    return;  // This case happens, not sure how, and would otherwise cause a crash below.
                }
                ESTimeInterval now = ESTime::currentTime();
                bool isDSTNow = ESCalendar_isDSTAtTimeInterval(lastWarnedTZ, now);
                double tzOffset = ESCalendar_tzOffsetForTimeInterval(lastWarnedTZ, now);
                float tzCenter = ((tzOffset - (isDSTNow ? 1.0 : 0.0)) / 3600.0) * 15;
                NSString *ew = tzCenter == 0 ? @" " : tzCenter < 0 ? NSLocalizedString(@"W", @"one character abbreviation for 'west'") : NSLocalizedString(@"E", @"one character abbreviation for 'east'");
                [[ECErrorReporter theErrorReporter] reportWarning:[NSString stringWithFormat:NSLocalizedString(@"Your timezone:\n\n%@ (%@)\noffset %d:%02d, centered at %d%s\n\ndoesn't match your location:\n\n%0.5f, %0.5f\n(± %.0f meters)", @"detailed timezone/position warning message"),
                                                                   [NSString stringWithUTF8String:ESCalendar_timeZoneLocalizedName(lastWarnedTZ, isDSTNow)],
                                                                   [NSString stringWithUTF8String:ESCalendar_abbrevName(lastWarnedTZ).c_str()],
                                                                   (int)rint(tzOffset/3600),
                                                                   abs(((int)rint(tzOffset)) % 60)/60,
                                                                   (int)fabsf(tzCenter),
                                                                   [ew UTF8String],
                                                                   env->location()->latitudeDegrees(),
                                                                   env->location()->longitudeDegrees(),
                                                                   env->location()->accuracyInMeters()]];
            }];
        [alert addAction:detailsAction];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * action) {}];
        [alert addAction:defaultAction];

        OrreryAppDelegate *appDelegate = (OrreryAppDelegate *)[[UIApplication sharedApplication] delegate];
        if (appDelegate) {
            MainViewController *mainViewController = appDelegate.mainViewController;
            if (mainViewController) {
                [mainViewController presentViewController:alert animated:YES completion:nil];
            }
        }

	[ECErrorReporter setErrorShowing:true];
	//tracePrintf("checkSanityForTimezone: gave warning");
	lastWarnedLong = lng;
	lastWarnedTZ = tz;
    } else {
	//tracePrintf("checkSanityForTimezone: OK");
	lastWarnedLong = -200;
	lastWarnedTZ = NULL;
    }
}

- (void)locationUpdate {
    [self resetTargets];
    ESLocation *location = env->location();
    [self checkSanityForTimezone:ESCalendar_localTimeZone() latitude:location->latitudeDegrees() longitude:location->longitudeDegrees()];
}

- (UIButton *)createButtonAtX:(double)x Y:(double)y width:(double)w height:(double)h highlight:(bool)hl text:(NSString *)text color:(UIColor *)clr {
    UIButton *but = [UIButton buttonWithType:UIButtonTypeCustom];
    but.frame = CGRectMake(centerX + (x-w/2), centerY - (y+h/2), w, h);
    [but addTarget:self action:@selector(buttonActionUp:) forControlEvents:UIControlEventTouchUpInside];
    [but addTarget:self action:@selector(buttonActionDn:) forControlEvents:UIControlEventTouchDown];
    but.showsTouchWhenHighlighted = hl;
    [but setTitle:text forState:UIControlStateNormal];;
    but.titleLabel.font = [UIFont fontWithName:@"Arial" size:14];
    but.titleLabel.textAlignment = NSTextAlignmentCenter;
    if (clr) {
	[but setTitleColor:clr forState:UIControlStateNormal];
    }
    [view addSubview:but];
    but.hidden = true;
    return but;
}

- (UIButton *)createImagedButtonAtX:(double)x Y:(double)y width:(double)w height:(double)h highlight:(bool)hl text:(NSString *)text color:(UIColor *)clr {
    UIButton *but = [self createButtonAtX:x Y:y width:w height:h highlight:hl text:text color:clr];
    [but setBackgroundImage:[UIImage imageNamed:@"butt.png"] forState:UIControlStateNormal];
    return but;
}

- (UILabel *)createLabelAtX:(double)x Y:(double)y width:(double)w height:(double)h font:(UIFont *)fnt fontSize:(double)sz {
    UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(centerX + (x-w/2), centerY - (y+h/2), w, h)];
    lab.textAlignment = NSTextAlignmentCenter;
    lab.font = [fnt fontWithSize:sz];
    lab.textColor = [UIColor whiteColor];
    lab.backgroundColor = [UIColor clearColor];
    [view addSubview:lab];
    [lab release];
    return lab;
}

- (UILabel *)createLabelAtX:(double)x Y:(double)y width:(double)w height:(double)h fontSize:(double)sz {
    return [self createLabelAtX:x Y:y width:w height:h font:[UIFont fontWithName:@"Arial" size:(sz)] fontSize:sz];
}

//// scaling for iPhone

+ (CGPoint)clockCenter {
    return CGPointMake(centerX, centerY);
}

//// static widget drawing

+ (void)setupTextTransform:(CGContextRef)context forRect:(CGRect)rect {
    CGAffineTransform transform;  // without transforming, text shows up mirrored about the center of the rect
    // x' = ax + cy + tx
    // y' = bx + dy + ty
    transform.a = 1;
    transform.b = 0;
    transform.c = 0;
    transform.d = -1;
    transform.tx = 0;
    transform.ty = 2 * CGRectGetMidY(rect);
    CGContextConcatCTM(context, transform);
}

#if 0
- (void)fontMetrics:(NSString *)text
     withContext:(CGContextRef)context
	withFont:(UIFont *)aFont {
    CGSize s = [text sizeWithFont:aFont];
    printf("'%s': fontName=%s, s.height=%.1f, ascender=%.1f, descender=%.1f, capHeight=%.1f, leading=%1.f, pointSize=%.1f\n",
	   text UTF8String], [aFont.fontName UTF8String], s.height, aFont.ascender, aFont.descender, aFont.capHeight, aFont.leading, aFont.pointSize);
}
#endif

+ (void)drawText:(NSString *)text
	  inRect:(CGRect)rect
     withContext:(CGContextRef)context
	withFont:(UIFont *)aFont
	   color:(UIColor *)color {
    CGContextSaveGState(context);
    [self setupTextTransform:context forRect:rect];

    static NSParagraphStyle *ourStyle = nil;
    if (!ourStyle) {
        assert([NSThread isMainThread]);
        NSMutableParagraphStyle *mutableStyle = [[NSMutableParagraphStyle alloc] init];
        mutableStyle.alignment = NSTextAlignmentCenter;
        mutableStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
        ourStyle = mutableStyle;
    }
    // [color set];
    // Deprecated iOS 7:  [text drawInRect:rect withFont:aFont lineBreakMode:UILineBreakModeMiddleTruncation alignment:UITextAlignmentCenter];
    if (text) {
        [text drawInRect:rect withAttributes:@{NSFontAttributeName:aFont, NSParagraphStyleAttributeName:ourStyle, NSForegroundColorAttributeName:color}];
    }

    CGContextRestoreGState(context);
}

+ (void)drawCircularText:(NSString *)str inRect:(CGRect)rect radius:(double)radius angle:(double)angle offset:(double)offsetAngle withContext:(CGContextRef)context withFont:(UIFont *)fnt color:(UIColor *)color demi:(bool)demi {
    CGContextSaveGState(context);
//    CGContextTranslateCTM(context, rect.size.width/2, rect.size.height/2);
//    CGContextTranslateCTM(context, CGRectGetMidX(boundsOnScreen), CGRectGetMidY(boundsOnScreen));
    NSUInteger n = [str length];
    if (n<1) {
	return;
    }
    // compute total angular length
    double len = 0;
    NSString *letter;
    CGSize s;
    double spaceing = 0;	// tried s.height * some factor but zero seems best
    for (int i=0; i<n; i++) {
	letter = [str substringWithRange:NSMakeRange(i, 1)];
	// Deprecated iOS 7:  s = [letter sizeWithFont:fnt];
        s = [letter sizeWithAttributes:@{NSFontAttributeName:fnt}];
	len += -2*M_PI*((s.width+spaceing*2)/(2*M_PI*radius));
    }
    angle = fmod(angle,2*M_PI);
    CGContextRotateCTM(context, -angle+offsetAngle);
    if (demi && angle > M_PI/2 && angle < 3*M_PI/2) {
	CGContextRotateCTM(context, M_PI+offsetAngle+len/2);
	radius -= .75;		// "demiTweak"
    } else {
	CGContextRotateCTM(context, offsetAngle-len/2);
    }

    for (int i=0; i<n; i++) {
	letter = [str substringWithRange:NSMakeRange(i, 1)];
	// Deprecated iOS 7:  s = [letter sizeWithFont:fnt];
        s = [letter sizeWithAttributes:@{NSFontAttributeName:fnt}];
	if (demi && angle > M_PI/2 && angle < 3*M_PI/2) {
	    CGContextRotateCTM(context, 2*M_PI*((s.width/2+spaceing)/(2*M_PI*radius)));
	    CGRect r = CGRectMake(-s.width/2, -radius, s.width, s.height);
	    [EOClock drawText:letter inRect:r withContext:context withFont:fnt color:color];
	    CGContextRotateCTM(context, 2*M_PI*((s.width/2+spaceing)/(2*M_PI*radius)));
	} else {
	    CGContextRotateCTM(context, -2*M_PI*((s.width/2+spaceing)/(2*M_PI*radius)));
	    CGRect r = CGRectMake(-s.width/2, radius-s.height, s.width, s.height);
	    [EOClock drawText:letter inRect:r withContext:context withFont:fnt color:color];
	    CGContextRotateCTM(context, -2*M_PI*((s.width/2+spaceing)/(2*M_PI*radius)));
	}
    }
    CGContextRestoreGState(context);
}

+ (void)drawDialNumbersUpright:(CGContextRef)context x:(double)x y:(double)y text:(NSString *)text font:(UIFont *)font color:(UIColor *)color radius:(double)radius {
    ESAssert (font || text == NULL);
    CGContextSaveGState(context);
    
    // break the comma delimited text into an array of labels
    NSArray *labels = [text componentsSeparatedByString:@","];
    NSUInteger n = [labels count];
    if (n<1) {
	return;
    }
    
    [color set];		// text needs both stroke and fill
    NSString *label;
    int i;
    for (i=0; i<n; i++) {
	// draw the number
	label = [labels objectAtIndex:i];
	// Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
        CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	double h = radius - sqrt(s.width * s.width + s.height * s.height)/2;
	double th = -(((double)i)/n)*twoPi + halfPi;
	CGRect r = CGRectMake(x + h * cos(th)-s.width/2, y + h * sin(th)-s.height/2, s.width, s.height);
	[EOClock drawText:label inRect:r withContext:context withFont:font color:color];
	CGContextStrokePath(context);	  // [steve 2012/12/22: This is a no-op, right?]
    }
    CGContextRestoreGState(context);
}

+ (void)drawDialNumbersDemiRadial:(CGContextRef)context x:(double)x y:(double)y text:(NSString *)text font:(UIFont *)font color:(UIColor *)color radius:(double)radius radius2:(double)radius2 {
    ESAssert (font || text == NULL);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, x, y);

    // break the comma delimited text into an array of labels
    NSArray *labels = [text componentsSeparatedByString:@","];
    NSUInteger n = [labels count];
    if (n<=1) {			// if text is empty there's still one label
	return;
    }

    NSString *label;
    // draw radial text:
    for (int i=0; i<n; i++) {
	if (i > n/4 && i < 3*n/4) {
	    // done in following loop
	} else {
	    label = [labels objectAtIndex:i];
            // Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
            CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	    CGRect rect = CGRectMake(-s.width/2, radius - s.height, s.width, s.height);
	    [color set];
	    [EOClock drawText:[labels objectAtIndex:i] inRect:rect withContext:context withFont:font color:color];
	}
	CGContextStrokePath(context);
	CGContextRotateCTM(context, -M_PI*2/n);
    }
    // draw antiradial text:
    CGContextRotateCTM(context, M_PI);
    for (int i=0; i<n; i++) {
	if (i > n/4 && i < 3*n/4) {
	    label = [labels objectAtIndex:i];
            // Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
            CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	    CGRect rect = CGRectMake(-s.width/2, -radius2, s.width, s.height);
	    [color set];
	    [EOClock drawText:[labels objectAtIndex:i] inRect:rect withContext:context withFont:font color:color];
	} else {
	    // done in previous loop
	}
	CGContextStrokePath(context);
	CGContextRotateCTM(context, -M_PI*2/n);
    }

    CGContextRestoreGState(context);
}

+ (void)drawZodiacDialDemiRadial:(CGContextRef)context x:(double)x y:(double)y font:(UIFont *)font color:(UIColor *)color radius:(double)radius radius2:(double)radius2 {
    ESAssert (font);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, x, y);
    
    const double *zodiacCenters = ESAstronomyManager::zodiacCentersDegrees();
    const double *zodiacEdges = ESAstronomyManager::zodiacEdgesDegrees();;

    // break the comma delimited text into an array of labels
    NSArray *labels = [NSLocalizedString(@"Pisces,Aries,Taurus,Gemini,Cancer,Leo,Virgo,Libra,Scorpius,Sagittarius,Capricornus,Aquarius", @"constellations of the zodiac") componentsSeparatedByString:@","];
    
    [color set];
    NSString *label;
    int n = 12;
    // draw radial text:
    for (int i=0; i<n; i++) {
	if (i >= n/4 && i < 3*n/4) {
	    // done in following loop
	} else {
	    CGContextRotateCTM(context, zodiacCenters[i]*twoPi/360);
	    label = [labels objectAtIndex:i];
            // Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
            CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	    CGRect rect = CGRectMake(-s.width/2, radius - s.height, s.width, s.height);
	    [EOClock drawText:[labels objectAtIndex:i] inRect:rect withContext:context withFont:font color:color];
	    CGContextRotateCTM(context, -zodiacCenters[i]*twoPi/360);
	}
	CGContextStrokePath(context);
    }
    // draw antiradial text:
    CGContextRotateCTM(context, M_PI);
    for (int i=0; i<n; i++) {
	if (i >= n/4 && i < 3*n/4) {
	    CGContextRotateCTM(context, zodiacCenters[i]*twoPi/360);
	    label = [labels objectAtIndex:i];
            // Deprecated iOS 7:  CGSize s = [label sizeWithFont:font];
            CGSize s = [label sizeWithAttributes:@{NSFontAttributeName:font}];
	    CGRect rect = CGRectMake(-s.width/2, -radius2, s.width, s.height);
	    [EOClock drawText:[labels objectAtIndex:i] inRect:rect withContext:context withFont:font color:color];
	    CGContextRotateCTM(context, -zodiacCenters[i]*twoPi/360);
	} else {
	    // done in previous loop
	}
	CGContextStrokePath(context);
    }
    // draw edges:
    CGContextRotateCTM(context, -M_PI);
    CGContextSetLineWidth(context, 2);
    for (int i=0; i<n; i++) {
	CGContextRotateCTM(context, zodiacEdges[i]*twoPi/360);
	CGContextMoveToPoint(context, 0, radius-4);
	CGContextAddLineToPoint(context, 0, radius-11);
	CGContextRotateCTM(context, -zodiacEdges[i]*twoPi/360);
	CGContextStrokePath(context);
    }
    
    CGContextRestoreGState(context);
}

+ (void)drawTicks:(CGContextRef)context x:(double)x y:(double)y n:(int)n innerRadius:(double)innerRadius outerRadius:(double)outerRadius width:(double)width color:(UIColor *)color angle1:(double)angle1 angle2:(double)angle2 noFives:(BOOL)noFives {
    CGContextSaveGState(context);
    CGContextSetLineWidth(context, width);
    [color set];
    for (int i=0; i<n; i++) {
	if (noFives && ((i % 5) == 0)) {
	    continue;
	}
	double th = (((double)i)/n)*twoPi;
	if ((angle1 <= th && th <= angle2) || (th == 0 && angle2 == twoPi)) {
	    th = halfPi - th;
	    CGContextMoveToPoint   (context, x + outerRadius * cos(th), y + outerRadius * sin(th));
	    CGContextAddLineToPoint(context, x + innerRadius * cos(th), y + innerRadius * sin(th));
	}
    }
    CGContextStrokePath(context);	
    CGContextRestoreGState(context);
}

+ (void)drawTicks:(CGContextRef)context x:(double)x y:(double)y n:(int)n innerRadius:(double)innerRadius outerRadius:(double)outerRadius width:(double)width color:(UIColor *)color angle1:(double)angle1 angle2:(double)angle2 {
    [self drawTicks:context x:x y:y n:n innerRadius:innerRadius outerRadius:outerRadius	width:width color:color angle1:angle1 angle2:angle2 noFives:NO];
}

+ (void)drawTicks:(CGContextRef)context x:(double)x y:(double)y n:(int)n innerRadius:(double)innerRadius outerRadius:(double)outerRadius width:(double)width color:(UIColor *)color {
    [self drawTicks:context x:x y:y n:n innerRadius:innerRadius outerRadius:outerRadius	width:width color:color angle1:0 angle2:twoPi noFives:NO];
}

+ (void)drawTicksNoFives:(CGContextRef)context x:(double)x y:(double)y n:(int)n innerRadius:(double)innerRadius outerRadius:(double)outerRadius width:(double)width color:(UIColor *)color {
    [self drawTicks:context x:x y:y n:n innerRadius:innerRadius outerRadius:outerRadius	width:width color:color angle1:0 angle2:twoPi noFives:YES];
}


//// //// //// clockSetup

static UIColor	*fwdColor;
static UIColor	*bckColor;
static double bmw;
static double bmh;
static double ChandraR;
static double headerHeight;
static double headerLineWidth;
static double BMX;
static double EVX;
static double EVY;
static double ChandraY;
static double BMY;
static double ChandraX;
static double riseSetUpdate;
static double planetUpdate;
static double eclipseUpdate;
static double blueMarbleUpdate;
static double moonViewUpdate;
static double extHandUpdate;
static double dateW;
static double dateH;
static double mainR;
static double ringMasterScale;
static double moonMasterScale;
static double earthMasterScale;
static double mainX;
static double logoH;
static double mainY;
static double mainFontSize;
static double zodiacFontSize;
static double smallZodiacFontSize;
static double tickHeight;
static double plR;
static double sunRingWidth;
static double subdialFontSize;
static double orbitInc;
static double subOffset;
static double subR;
static double sunD;
static double zD;
static double UTCX;
static double UTCY;
static double solarX;
static double solarY;
static double sidX;
static double sidY;
static double zR;
static double alarmLen;
static double alarmTailR;
static double h24Len;
static double h24Wid;
static double minLen;
static double h12Len;
static double secLen;
static double sunRiseSetLen;
static double sunRiseSetWidth;
static double sunRiseSetArrow;
static double alarmArrow;
static double h24Arrow;
static double len2;
static double alarmLen2;
static UIColor *hour24Color;
static UIColor *hour12Color;
static UIColor *minuteColor;
static UIColor *secondColor;
static UIColor *alarmColor;
static UIColor *risesetColor;
static UIColor *snoonColor;
static UIColor *smidColor;
static UIColor *goldenColor;
static UIColor *twilightColor;
static UIColor *twilightArmColor;
static double plR2;
static double extDialOffX;
static double extDialOffY;
static double extDialR;
static double altR;
static double altX;
static double altY;
static double extFontSize;
static double yearFontSize;
static double eclipseFontSize;
static double eclipseHorizonFontSize;
static double azR;
static double azX;
static double azY;
static double eclipseR1;
static double eclipseR2;
static double eclipseX;
static double eclipseY;
static double eclipseStatusX;
static double eclipseStatusY;
static double eclipseHorizonX;
static double eclipseHorizonY;
static double demoButtonOffsetY;
static double EOTR;
static double EOTX;
static double EOTY;
static double fDSTX;
static double fDSTY;
static double sDSTX;
static double sDSTY;
static double EOTFontSize;
static double planetW;
static double planetH;
static double NTPStatusX, NTPStatusY, NTPStatusSize;
static double tzX;
static double tzY;
static double tzW;
static double utcdayX,utcdayY;
static double logoX;
static double logoY;
static double bdX;
static double bdY;
static double bdX2;
static double bdY2;
static double bdX3;
static double bdX4;
static double bdY3;
static double resetX;
static double resetY;
static double advButtonX;
static double advButtonY;
static double advButtonWidth;
static double advButtonHeight;
static double advMinuteButtonOffsetX;
static double advHourButtonOffsetX;
static double advDayButtonOffsetX;
static double advPhaseButtonOffsetX;
static double advMonthButtonOffsetX;
static double advCentButtonOffsetX;
static double advYearButtonOffsetX;
static double backMinuteButtonOffsetX;
static double backHourButtonOffsetX;
static double backDayButtonOffsetX;
static double backPhaseButtonOffsetX;
static double backMonthButtonOffsetX;
static double backCentButtonOffsetX;
static double backYearButtonOffsetX;

- (void)initializeConstantsForOrientation:(UIInterfaceOrientation)orientation {
    headerLineWidth = 2;
    bmw = 300;
    bmh = bmw/2;
    headerHeight = bmh;
    dateH = headerHeight/2;
    dateW = EOSCREENWIDTH/2 - (bmw/2 + headerLineWidth*3);
    ChandraR = bmh/2;
    mainR = 365;
    NTPStatusSize = 12;
    NTPStatusX = -EOSCREENWIDTH/2  + NTPStatusSize;
    NTPStatusY = -(EOSCREENHEIGHT-EOSTATICSTATUSBARHEIGHT)/2 + NTPStatusSize;
    tzW = 150;
    tzX = 0;
    tzY = -272;
    advButtonWidth = 45;
    advButtonHeight = 40;
    advMinuteButtonOffsetX = -advButtonWidth;
    advHourButtonOffsetX = -advButtonWidth*2;
    advDayButtonOffsetX = -advButtonWidth*3;
    advPhaseButtonOffsetX = -advButtonWidth*4;
    advMonthButtonOffsetX = -advButtonWidth*5;
    advYearButtonOffsetX = -advButtonWidth*6;
    advCentButtonOffsetX = -advButtonWidth*7;
    backMinuteButtonOffsetX = advButtonWidth;
    backHourButtonOffsetX = advButtonWidth*2;
    backDayButtonOffsetX = advButtonWidth*3;
    backPhaseButtonOffsetX = advButtonWidth*4;
    backMonthButtonOffsetX = advButtonWidth*5;
    backYearButtonOffsetX = advButtonWidth*6;
    backCentButtonOffsetX = advButtonWidth*7;
    if (UIInterfaceOrientationIsPortrait(orientation)) {
	advButtonX = 0;
	advButtonY = 327;
	fullWidth = 768;
	fullHeight = 1024;
	mainX = 0;
	mainY = -(headerHeight + headerLineWidth*2) / 2;
	ringMasterScale = 1.0;
	moonMasterScale = 1.0;
	earthMasterScale = 1.0;
	NTPStatusY = -502 + NTPStatusSize;
	NTPStatusX = -384 + NTPStatusSize;
	logoX = 0;
	logoY = -(EOSCREENHEIGHT-EOSTATICSTATUSBARHEIGHT-19)/2;
	BMX = 0;
	ChandraY = (EOSCREENHEIGHT-EOSTATICSTATUSBARHEIGHT)/2 - (ChandraR) - headerLineWidth -1;
	BMY = ChandraY;
	ChandraX = -EOSCREENWIDTH/2 + (EOSCREENWIDTH-bmw)/4;
	bdX = bmw/2+dateW/2+headerLineWidth*2;
	bdY = BMY+headerHeight/4-headerLineWidth;
	bdX2 = bmw/2+dateW/2+headerLineWidth*2;
	bdY2 = BMY-headerHeight/4+headerLineWidth;
	bdX3 = bdX;
	bdY3 = BMY;
	bdX4 = bdX+90;
	extDialOffX = 305;
	extDialOffY = 348;
	altX = mainX-extDialOffX;
	altY = mainY+extDialOffY;
	azX = mainX-extDialOffX;
	azY = mainY-extDialOffY;
	eclipseX = mainX+extDialOffX;
	eclipseY = mainY+extDialOffY;
	EOTX = mainX+extDialOffX;
	EOTY = mainY-extDialOffY;
	fDSTX = mainX-142;
	fDSTY = mainY-341;
	sDSTX = mainX-225;
	sDSTY = mainY-292;
	resetX = BMX;
	resetY = BMY-headerHeight/2-22;
    } else {	 // layout parameters for landscape:
	advButtonX = 0;
	advButtonY = 347;
	fullWidth = 1024;
	fullHeight = 768;
	mainX = 0; // use "-(headerHeight + headerLineWidth*2) / 2" for same position relative to Home button
	mainY = -13;
	ringMasterScale = 0.9;
	moonMasterScale = 1.2;
	earthMasterScale = 0.9;
	tzY += (headerHeight + headerLineWidth*2) / 2;
	NTPStatusY = -(EOSCREENWIDTH-EOSTATICSTATUSBARHEIGHT)/2 + NTPStatusSize;
	NTPStatusX = -EOSCREENHEIGHT/2 + NTPStatusSize;
	logoX = 0;
	//logoY = -EOSCREENWIDTH/2 + logoH + 5;
	logoY = -(EOSCREENWIDTH-EOSTATICSTATUSBARHEIGHT-19)/2 + 2;
	BMX = EOSCREENHEIGHT/2 - bmw*earthMasterScale/2 - headerLineWidth;
	BMY = EOSCREENWIDTH/2  - bmh*earthMasterScale/2 - EOSTATICSTATUSBARHEIGHT/2 - 2;
	ChandraX = -EOSCREENHEIGHT/2 + ChandraR + 55;
	ChandraY = EOSCREENWIDTH/2 - EOSTATICSTATUSBARHEIGHT - ChandraR - 55 + EOSTATICSTATUSBARHEIGHT;
	bdX2 = -333;
	bdY2 = -EOSCREENWIDTH/2 + dateH/2;
	bdX = -bdX2;
	bdY = bdY2;
	bdX3 = bdX;
	bdY3 = bdY+24+10.5;
	bdX4 = bdX+65;
	extDialOffX = 420;
	extDialOffY =  50;
	fDSTX = mainX-127;
	fDSTY = mainY-306;
	sDSTX = mainX-200;
	sDSTY = mainY-262;
	altX = mainX-extDialOffX;
	altY = mainY+extDialOffY;
	azX = mainX-extDialOffX;
	azY = mainY-extDialOffY*3.5;
	EOTX = mainX+extDialOffX;
	EOTY = mainY-extDialOffY*3.5;
	eclipseX = mainX+extDialOffX;
	eclipseY = mainY+extDialOffY;
	resetX = 0;
	resetY = EOSCREENWIDTH/2 - EOSTATICSTATUSBARHEIGHT - 17;
    }
    EVX = BMX + centerX;
    EVY = BMY + centerY;
    
    riseSetUpdate = 3600;
    planetUpdate = 3600;
    eclipseUpdate = 30;
    blueMarbleUpdate = 60;
    moonViewUpdate = 60;
    extHandUpdate = 60;

    logoH = 29;
    mainFontSize = 32;
    zodiacFontSize = 36;
    smallZodiacFontSize = 11;
    tickHeight = mainFontSize/2.5;
    plR = mainR-mainFontSize-1;
    sunRingWidth = 64;
    subdialFontSize = 10;
    orbitInc = 40;
    subOffset = 149;	// == earth Radius; approximately (plR - sunRingWidth)/4
    subR = (orbitInc - 1) * 2 - 5;
    sunD = 100;
    zD = 526;

    UTCX = mainX;
    UTCY = mainY+subOffset*ringMasterScale;
    utcdayX = mainX;
    utcdayY = UTCY - 39;
    solarX = mainX -subOffset*ringMasterScale * cos(pi/6);
    solarY = mainY -subOffset*ringMasterScale * sin(pi/6);
    sidX = -solarX;
    sidY = solarY;

    eclipseStatusX = eclipseX;
    eclipseStatusY = eclipseY;
    eclipseHorizonX = eclipseX;
    eclipseHorizonY = eclipseY;

    zR = plR-60;
    plR2 = plR - 52 - 26;
    
    h24Len = mainR-tickHeight*.37;
    h24Wid = h24Arrow/1.8/sqrt(3);
    minLen = zR - zodiacFontSize/2;
    h12Len = minLen *.75;
    secLen = minLen * 1.05;
    sunRiseSetLen = h24Len; //plR + 52 - sunRingWidth;
    sunRiseSetWidth = 1;
    sunRiseSetArrow = 18;
    alarmTailR = 8;
    alarmLen = mainR+alarmTailR*2+1;
    alarmLen2 = mainR+alarmTailR*2+1;
    alarmArrow = 0;
    h24Arrow = 25;
    len2 = zR-5;
    hour24Color = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:.85];
    hour12Color = [UIColor colorWithRed:0xfa/256.0 green:0xb7/256.0 blue:0.0 alpha:1];
    minuteColor = [UIColor colorWithRed:1 green:0xc1/256.0 blue:0x25/256.0 alpha:1];
    secondColor = [UIColor colorWithRed:1 green:0xd9/256.0 blue:0x9a/256.0 alpha:1];
    alarmColor  = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];
    snoonColor = [UIColor colorWithRed:1.0 green:1.0 blue:0 alpha:.75];
    smidColor = [UIColor colorWithRed:0 green:0 blue:1.0 alpha:.75];
    risesetColor  = [UIColor colorWithRed:1.0 green:.50 blue:.00 alpha:.75];
    goldenColor   = [UIColor colorWithRed:1.0 green:.80 blue:.00 alpha:.75];
    twilightColor = [UIColor colorWithRed:0.0 green:.50 blue:.50 alpha:.75];
    twilightArmColor = [UIColor colorWithRed:0.3 green:.60 blue:.60 alpha:1];
    extDialR = 60;
    
    extFontSize = 10;
    yearFontSize = 20;
    eclipseFontSize = 10;
    eclipseHorizonFontSize = 10;
    altR = extDialR;
    azR = altR;
    eclipseR2 = altR + 3;
    eclipseR1 = eclipseR2 - 14;
    demoButtonOffsetY = eclipseR2 + 15;
    EOTR = altR;
    EOTFontSize = 8;
    planetW = 50;
    planetH = 15;
    
    fwdColor = [UIColor colorWithRed:.75 green:0 blue:0 alpha:1];
    bckColor = [UIColor colorWithRed:0 green:.75 blue:1 alpha:1];
    
}

static void setFrameForViewAtZeroRotation(UIView       *view,
                                          const CGRect *frame) {
    CATransform3D currentXform = view.layer.transform;
    view.layer.transform = CATransform3DMakeRotation(0,0,0,1);
    view.frame = *frame;
    view.layer.transform = currentXform;
}

- (void)reorientSubView:(UIView *)subview toOrientation:(UIInterfaceOrientation)newOrientation offsetBy:(CGPoint)centerOffset {
    // stevep 2011 Jun 29: The convention here is that we maintain correctness after each of reorientSubView and resizeSubView
    // even if an orientation change results in a call to both of them.  This is slightly more code to execute but easier to verify.
    // In the event that both a reorientSubView and a resizeSubView are required, then in resizeSubView (which happens after this,
    // though I don't think that matters), the frame is recalculated in that method and possibly (probably) moved in addition to
    // being scaled, to account for the different rounding in effect for the different size.

    // First calculate the actual view "center" (really zero point) being requested
    double viewCenterX;
    double viewCenterY;
    if (UIInterfaceOrientationIsLandscape(newOrientation)) {
	viewCenterX = centerX + centerOffset.x;
	viewCenterY = centerY - centerOffset.y;
    } else {
	// Gack.  How could this be right...   FIX FIX
	CGFloat yOffset = centerOffset.y;
	if (yOffset != 0) {
	    yOffset += 77;
	}
	viewCenterY = centerY+(headerHeight + headerLineWidth*2) / 2 - yOffset;
	viewCenterX = centerX + centerOffset.x;
    }

    // Then the "requestedFrame" appropriately:
    if ([subview respondsToSelector:@selector(requestedFrame)]) {
        CGRect requestedFrame = [(id)subview requestedFrame];
        requestedFrame.origin.x = viewCenterX - requestedFrame.size.width / 2;
        requestedFrame.origin.y = viewCenterY - requestedFrame.size.height / 2;
        [(id)subview setRequestedFrame:requestedFrame];

        // Finally obtain the rounded out frame corresponding to the requested frame at the given scale
        CGPoint zeroOffset;
        CGRect roundedOutFrame;
        roundOutFrameToIntegralBoundaries(&requestedFrame, [(id)subview masterScale], &roundedOutFrame, &zeroOffset);
        [(id)subview setZeroOffset:zeroOffset];
        setFrameForViewAtZeroRotation(subview, &roundedOutFrame);
        [subview setNeedsDisplay];
    } else {  // But if it's not one of "our" views, just center it
        subview.center = CGPointMake(viewCenterX, viewCenterY);
    }
}

- (void)resizeSubView:(UIView *)subview masterScale:(double)newMasterScale {
    // See comment for reorientSubView above.  We require that the zero point (nominally but not exactly the center of the
    // view) be correct after resizing.
    CGRect roundedOutFrame;
    CGRect requestedFrame = [(id)subview requestedFrame];
    CGPoint zeroOffset = [(id)subview zeroOffset];
    roundOutFrameToIntegralBoundaries(&requestedFrame, newMasterScale, &roundedOutFrame, &zeroOffset);
    setFrameForViewAtZeroRotation(subview, &roundedOutFrame);
    [(id)subview setZeroOffset:zeroOffset];
    [(id)subview setMasterScale:newMasterScale];
    [subview setNeedsDisplay];
}

- (void)reCreateMainDial {
    UIInterfaceOrientation newOrientation = [Utilities currentOrientation];
    if (ringsAndPlanetsBackView) {
	[subviews removeObject:ringsAndPlanetsBackView];
	[ringsAndPlanetsBackView removeFromSuperview];
    }
    noonOnTop = [[NSUserDefaults standardUserDefaults] boolForKey:@"EONoonOnTop"];
    [self initializeConstantsForOrientation:UIInterfaceOrientationPortrait];
    ringsAndPlanetsBackView = [[EORingsAndPlanetsShuffleView alloc] initAtCenter:CGPointMake(mainX, mainY)
									    sunD:sunD
                                                                              zD:zD
									   mainR:mainR
									    subR:subR
									      zR:zR
								      tickHeight:tickHeight
								       utcOffset:CGPointMake(UTCX - mainX, UTCY - mainY)
								     solarOffset:CGPointMake(solarX - mainX, solarY - mainY)
								  siderealOffset:CGPointMake(sidX - mainX, sidY - mainY)
									  secLen:secLen
									    plR2:plR2
									orbitInc:orbitInc
								    mainFontSize:mainFontSize
								 subdialFontSize:subdialFontSize
								  zodiacFontSize:zodiacFontSize
							     smallZodiacFontSize:smallZodiacFontSize
								       noonOnTop:noonOnTop];
    [self addSubview:ringsAndPlanetsBackView];
    [view sendSubviewToBack:ringsAndPlanetsBackView];

    [self initializeConstantsForOrientation:newOrientation];
    [self reorientSubView:ringsAndPlanetsBackView toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
    [self resizeSubView:ringsAndPlanetsBackView masterScale:ringMasterScale];
    
    [self resetTargets];
}

static const char *cyrillicLangauges[] = {
    "rus", "ru",
    "ukr", "uk",
    "abk", "ab",
    "ava", "av",
    "aze", "az",
    "bak", "ba",
    "bel", "be",
    "bua",
    "bul", "bg",
    "che", "ce",
    "chv", "cv",
    "kaa",
    "kaz", "kk",
    "kir", "ky",
    "kur", "ku",
    "lez",
    "mac", "mk",
    "mol", "ro",
    "mon", "mn",
    "oss", "os",
    "sah",
    "sel",
    "src",
    "tat", "tt",
    "tgk", "tg",
    "tuk", "tk",
    "tyv", 
    "uig", "ug",
    "uzb", "uz",
};
static const int numCyrillicLanguages = sizeof (cyrillicLangauges) / sizeof(char *);

static bool languageIsCyrillic(const char *languageCode) {
    const char **ptr = cyrillicLangauges;
    const char **last = cyrillicLangauges + numCyrillicLanguages;
    while (ptr < last) {
        if (strcmp(languageCode, *ptr++) == 0) {
            return true;
        }
    }
    return false;
}

static bool localeIsCyrillic() {
    static bool cacheValue = false;
    static bool initialized = false;
    if (!initialized) {
        cacheValue = languageIsCyrillic([[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] UTF8String]);
        initialized = true;
    }
    return cacheValue;
}

- (void)createClockWidgets {
    traceEnter("createClockWidgets");
    ESAssert(moonView == NULL);		// come here only once

//UIInterfaceOrientation saveOrientation = lastOrientation;
//lastOrientation = UIInterfaceOrientationPortrait;
//[self initializeConstantsForOrientation:lastOrientation];

    // Background views first
    [self reCreateMainDial];

    logoView = [[EOLogoShuffleView alloc] initAtCenter:CGPointMake(logoX, logoY) logoWidth:200 logoHeight:19];
    [self addSubview:logoView];

    earthBackView = [[EOEarthBackShuffleView alloc] initAtCenter:CGPointMake(EVX, EVY) mapWidth:300 mapHeight:150];
    [self addSubview:earthBackView];

    altitudeDialView = [[EOAltitudeDialShuffleView alloc] initAtCenter:CGPointMake(altX, altY) altR:altR extFontSize:extFontSize planetW:planetW planetH:planetH];
    [self addSubview:altitudeDialView];

    azimuthDialView = [[EOAzimuthDialShuffleView alloc] initAtCenter:CGPointMake(azX, azY) azR:azR extFontSize:extFontSize planetW:planetW planetH:planetH];
    [self addSubview:azimuthDialView];

    eclipseDialView = [[EOEclipseDialShuffleView alloc] initAtCenter:CGPointMake(eclipseX, eclipseY) eclipseR1:eclipseR1 eclipseR2:eclipseR2];
    [self addSubview:eclipseDialView];

    eotDialView = [[EOEOTDialShuffleView alloc] initAtCenter:CGPointMake(EOTX, EOTY) EOTR:EOTR EOTFontSize:EOTFontSize];
    [self addSubview:eotDialView];

    // Not clear why the following should be necessary...
    [self reorientSubView:logoView toOrientation:lastOrientation offsetBy:CGPointMake(logoX, logoY)];
    [self reorientSubView:earthBackView toOrientation:lastOrientation offsetBy:CGPointMake(BMX,BMY)];
    [self resizeSubView:earthBackView masterScale:earthMasterScale];
    [self reorientSubView:altitudeDialView toOrientation:lastOrientation offsetBy:CGPointMake(altX, altY)];
    [self reorientSubView:azimuthDialView toOrientation:lastOrientation offsetBy:CGPointMake(azX, azY)];
    [self reorientSubView:eclipseDialView toOrientation:lastOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
    [self reorientSubView:eotDialView toOrientation:lastOrientation offsetBy:CGPointMake(EOTX, EOTY)];

    //////////// big Moon
    moonView = [[EOMoonView alloc] initWithName:@"moon300.png" x:ChandraX y:ChandraY radiusAtPerigee:ChandraR update:moonViewUpdate];
    [self addSubview:moonView];
    [self resizeSubView:moonView masterScale:moonMasterScale];
    lunarBut  = [self createButtonAtX:advButtonX + advPhaseButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"phase", @"short abbreviation for phase of the Moon") color:fwdColor];
    lunarButB = [self createButtonAtX:advButtonX + backPhaseButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"phase", @"short abbreviation for phase of the Moon") color:bckColor];
    
    // Earth images with terminator widget
    earthView = [[EOEarthView alloc] initWithX:EVX y:EVY width:bmw height:bmh update:blueMarbleUpdate];
    [self addSubview:earthView];
    [self reorientSubView:earthView toOrientation:lastOrientation offsetBy:CGPointMake(BMX, BMY)];  // This shouldn't be necessary, but it is
    [self resizeSubView:earthView masterScale:earthMasterScale];
    hourBut  = [self createButtonAtX:advButtonX + advHourButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"hour", @"short abbreviation for hour") color:fwdColor];
    hourButB  = [self createButtonAtX:advButtonX + backHourButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"hour", @"short abbreviation for hour") color:bckColor];
    
    /////////// digital date
    //printf("Available locale ids:\n");
    //for (NSString *id in [NSLocale availableLocaleIdentifiers]) {
    //    printf("  %s\n", [id UTF8String]);
    //}
    
    // printf("language code %s, %s Cyrillic\n", [[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] UTF8String], localeIsCyrillic() ? "IS" : "IS NOT");

    UIFont *fnt = localeIsCyrillic() ? [UIFont systemFontOfSize:48] : [UIFont fontWithName:@"Heiti J" size:48];
    if (fnt==NULL) {
	fnt = [UIFont fontWithName:@"Arial" size:48];
    }
    // month/day
    bigDate =  [self createLabelAtX:bdX Y:BMY+headerHeight/4-headerLineWidth width:dateW height:headerHeight/2 font:fnt fontSize:48];
    // weekday
    bigDate2 = [self createLabelAtX:bdX2 Y:bdY2 width:dateW height:headerHeight/2 font:fnt fontSize:48];
    bigDate2.adjustsFontSizeToFitWidth = true;
    // year/leap
    yearLabel = [self createLabelAtX:bdX3 Y:bdY3 width:yearFontSize*6 height:yearFontSize font:fnt fontSize:yearFontSize];
    leapLabel = [self createLabelAtX:bdX4 Y:bdY3 width:yearFontSize*3 height:yearFontSize/2 fontSize:yearFontSize/2];
    // eclipse
    eclipseStatusLabel = [self createLabelAtX:eclipseStatusX Y:eclipseStatusY width:eclipseR1*2 height:20 fontSize:eclipseFontSize];
#ifndef CAPTUREDEFAULTS
    [eclipseStatusLabel setText:NSLocalizedString(@"Eclipse Simulator", @"label for the Eclipse Simulator or Viewer or Window")];
#endif
    eclipseStatusLabel.adjustsFontSizeToFitWidth = YES;

    // buttons
    monBut  = [self createButtonAtX:advButtonX + advMonthButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"mon", "short abbreviation for month") color:fwdColor];
    monButB  = [self createButtonAtX:advButtonX + backMonthButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"mon", "short abbreviation for month") color:bckColor];
    dayBut  = [self createButtonAtX:advButtonX + advDayButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"day", "short abbreviation for day") color:fwdColor];
    dayButB  = [self createButtonAtX:advButtonX + backDayButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"day", "short abbreviation for day") color:bckColor];
    
    ////////// NTP Status "light"
    NTPStatusLabel = [self createLabelAtX:NTPStatusX Y:NTPStatusY width:NTPStatusSize height:NTPStatusSize fontSize:NTPStatusSize];
    NTPStatusLabel.text = @"◉";
    [view addSubview:NTPStatusLabel];
    NTPStatusBut = [self createButtonAtX:NTPStatusX Y:NTPStatusY width:NTPStatusSize*2 height:NTPStatusSize*2 highlight:true text:@"" color:NULL];
    [view addSubview:NTPStatusBut];
#ifndef NDEBUG
    NTPStatusBut.hidden = false;
#endif
#ifdef CAPTURESPECIALS
    NTPStatusBut.hidden = false;
#endif
    
    // tz label
    tzLabel = [self createLabelAtX:tzX Y:tzY width:tzW height:14 fontSize:14];
    tzLabel.textColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.75];
    
    // UTC day label
    utcdayLabel = [self createLabelAtX:utcdayX Y:utcdayY width:tzW height:14 fontSize:10];
    utcdayLabel.textColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.75];
    
    // planet hands: what makes it an Orrery :-)
    saturnHand = [[EOHandImageView alloc] initWithKind:EOSaturn name:@"saturn.png" x:mainX y:mainY radius:plR2 update:planetUpdate];
    [self addSubview:saturnHand];
    jupiterHand = [[EOHandImageView alloc] initWithKind:EOJupiter name:@"jupiter.png" x:mainX y:mainY radius:plR2-orbitInc update:planetUpdate];
    [self addSubview:jupiterHand];
    marsHand = [[EOHandImageView alloc] initWithKind:EOMars name:@"mars.png" x:mainX y:mainY radius:plR2-orbitInc*2 update:planetUpdate];
    [self addSubview:marsHand];
    earthHand = [[EOHandImageView alloc] initWithKind:EOEarth name:@"earth.png" x:mainX y:mainY radius:plR2-orbitInc*3 update:planetUpdate];
    [self addSubview:earthHand];
    moonHand = [[EOHandImageView alloc] initWithKind:EOMoon name:@"moon75.png" x:earthHand.width/2 y:-earthHand.length/2 radius:22 update:planetUpdate];
    [earthHand addSubview:moonHand];
    [subviews addObject:moonHand];
    [moonHand release];
    venusHand = [[EOHandImageView alloc] initWithKind:EOVenus name:@"venus.png" x:mainX y:mainY radius:plR2-orbitInc*4 update:planetUpdate];
    [self addSubview:venusHand];
    mercuryHand = [[EOHandImageView alloc] initWithKind:EOMercury name:@"mercury.png" x:mainX y:mainY radius:plR2-orbitInc*5 update:planetUpdate];
    [self addSubview:mercuryHand];

    // Set/Reset button
    resetBut = [self createButtonAtX:resetX Y:resetY width:advButtonWidth+24 height:advButtonHeight highlight:true text:NSLocalizedString(@"Set", "Set (verb)") color:[UIColor whiteColor]];
    resetBut.hidden = false;
#ifdef CAPTUREDEFAULTS
    resetBut.hidden = true;
#endif
    resetBut.titleLabel.adjustsFontSizeToFitWidth = YES;
    //resetBut.titleLabel.font = [UIFont fontWithName:@"Arial" size:18];

#ifdef INNER_SUBDIALS
    // inner subdial hands
    utcHourHand = [[[EOHandTriangleView alloc] initWithKind:EOUTCHours   length:subR*.55 width:5 x:UTCX y:UTCY update:1 strokeColor:[UIColor lightGrayColor] fillColor:[UIColor grayColor]] autorelease];
    [self addSubview:utcHourHand];
    utcMinuteHand = [[[EOHandTriangleView alloc] initWithKind:EOUTCMinutes length:subR*.75 width:4 x:UTCX y:UTCY update:.5 strokeColor:[UIColor lightGrayColor] fillColor:[UIColor grayColor]] autorelease];
    [self addSubview:utcMinuteHand];
    utcSecondHand = [[[EOHandTriangleView alloc] initWithKind:EOSeconds    length:subR*.85 width:3 x:UTCX y:UTCY update:.1 strokeColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:0.5] fillColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:0.75]] autorelease];
    [self addSubview:utcSecondHand];
    solarHourHand = [[[EOHandTriangleView alloc] initWithKind:EOSolarHours   length:subR*.55 width:5 x:solarX y:solarY update:1 strokeColor:[UIColor lightGrayColor] fillColor:[UIColor grayColor]] autorelease];
    [self addSubview:solarHourHand];
    solarMinuteHand = [[[EOHandTriangleView alloc] initWithKind:EOSolarMinutes length:subR*.75 width:4 x:solarX y:solarY update:.5 strokeColor:[UIColor lightGrayColor] fillColor:[UIColor grayColor]] autorelease];
    [self addSubview:solarMinuteHand];
    solarSecondHand = [[[EOHandTriangleView alloc] initWithKind:EOSolarSeconds length:subR*.85 width:3 x:solarX y:solarY update:.1 strokeColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:0.5] fillColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:0.75]] autorelease];
    [self addSubview:solarSecondHand];
    siderealHourHand = [[[EOHandTriangleView alloc] initWithKind:EOSiderealHours   length:subR*.55 width:5 x:sidX y:sidY update:1 strokeColor:[UIColor lightGrayColor] fillColor:[UIColor grayColor]] autorelease];
    [self addSubview:siderealHourHand];
    siderealMinuteHand = [[[EOHandTriangleView alloc] initWithKind:EOSiderealMinutes length:subR*.75 width:4 x:sidX y:sidY update:.5 strokeColor:[UIColor lightGrayColor] fillColor:[UIColor grayColor]] autorelease];
    [self addSubview:siderealMinuteHand];
    siderealSecondHand = [[[EOHandTriangleView alloc] initWithKind:EOSiderealSeconds length:subR*.85 width:3 x:sidX y:sidY update:.1 strokeColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:0.5] fillColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:0.75]] autorelease];
    [self addSubview:siderealSecondHand];
#endif

    // planet rise/set arcs
    sunRing = [[[EORingView alloc] initWithPlanet:ECPlanetSun     outerRadius:plR innerRadius:plR-sunRingWidth x:mainX y:mainY update:riseSetUpdate dayColor:[UIColor colorWithRed:0xfc/256. green:0xfc/256. blue:0xa9/256. alpha:1] nightColor:[UIColor clearColor]] autorelease];
    [self addSubview:sunRing];
    saturnRing = [[[EORingView alloc] initWithPlanet:ECPlanetSaturn  outerRadius:plR-2 innerRadius:plR-10 x:mainX y:mainY update:riseSetUpdate dayColor:[UIColor colorWithRed:0xa9/256. green:0xfc/256. blue:0xfc/256. alpha:1] nightColor:[UIColor clearColor]] autorelease];
    [self addSubview:saturnRing];
    jupiterRing = [[[EORingView alloc] initWithPlanet:ECPlanetJupiter outerRadius:plR-12 innerRadius:plR-20 x:mainX y:mainY update:riseSetUpdate dayColor:[UIColor colorWithRed:0xa9/256. green:0xfc/256. blue:0xa9/256. alpha:1] nightColor:[UIColor clearColor]] autorelease];
    [self addSubview:jupiterRing];
    marsRing = [[[EORingView alloc] initWithPlanet:ECPlanetMars    outerRadius:plR-22 innerRadius:plR-30 x:mainX y:mainY update:riseSetUpdate dayColor:[UIColor colorWithRed:0xfc/256. green:0xa9/256. blue:0xfc/256. alpha:1] nightColor:[UIColor clearColor]] autorelease];
    [self addSubview:marsRing];
    venusRing = [[[EORingView alloc] initWithPlanet:ECPlanetVenus   outerRadius:plR-32 innerRadius:plR-40 x:mainX y:mainY update:riseSetUpdate dayColor:[UIColor colorWithRed:0xff/256. green:0xff/256. blue:0xff/256. alpha:1] nightColor:[UIColor clearColor]] autorelease];
    [self addSubview:venusRing];
    mercuryRing = [[[EORingView alloc] initWithPlanet:ECPlanetMercury outerRadius:plR-42 innerRadius:plR-50 x:mainX y:mainY update:riseSetUpdate dayColor:[UIColor colorWithRed:0xfc/256. green:0xa9/256. blue:0xa9/256. alpha:1] nightColor:[UIColor clearColor]] autorelease];
    [self addSubview:mercuryRing];
    moonRing = [[[EORingView alloc] initWithPlanet:ECPlanetMoon    outerRadius:plR-52 innerRadius:plR-60 x:mainX y:mainY update:riseSetUpdate dayColor:[UIColor colorWithRed:0xa9/256. green:0xa9/256. blue:0xfc/256. alpha:1] nightColor:[UIColor clearColor]] autorelease];
    [self addSubview:moonRing];
    
    // central hands
    alarmHand = [[[EOHandAlarmView alloc] initWithKind:EOAlarms			length:alarmLen length2:alarmLen2 width:.75 x:mainX y:mainY update:3600   strokeColor:alarmColor fillColor:NULL armStrokeColor:alarmColor arrowLength:alarmArrow tailRadius:alarmTailR] autorelease];
    [self addSubview:alarmHand];
    hour24Hand = [[[EOHandView alloc] initWithKind:EO24Hours			length:h24Len length2:0 width: .75 x:mainX y:mainY update:1   strokeColor:hour24Color fillColor:NULL armStrokeColor:hour24Color arrowLength:h24Arrow arrowWidth:h24Wid] autorelease];
    //hour24Hand.contentMode = UIViewContentModeRedraw;
    [self addSubview:hour24Hand];
    hour12Hand = [[[EOHandBreguetView alloc] initWithKind:EO12Hours		length:h12Len width:30 x:mainX y:mainY update:10     strokeColor:[UIColor whiteColor] fillColor:hour12Color centerRadius:12] autorelease];
    [self addSubview:hour12Hand];
    minuteHand = [[[EOHandBreguetView alloc] initWithKind:EOMinutes		length:minLen width:25 x:mainX y:mainY update:.25    strokeColor:[UIColor whiteColor] fillColor:minuteColor centerRadius:8] autorelease];
    [self addSubview:minuteHand];
    secondHand = [[[EOHandNeedleView alloc] initWithKind:EOSeconds		length:secLen width: 2 x:mainX y:mainY update:1.0/EOClockUpdate strokeColor:secondColor ballRadius:6] autorelease];
    [self addSubview:secondHand];
   
    // twilight hands
    sunriseHand = [[[EOHandView alloc] initWithKind:EOSunrise			length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:risesetColor fillColor:NULL armStrokeColor:risesetColor arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:sunriseHand];
    sunsetHand = [[[EOHandView alloc] initWithKind:EOSunset			length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:risesetColor fillColor:NULL armStrokeColor:risesetColor arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:sunsetHand];
    goldenHourEndHand = [[[EOHandView alloc] initWithKind:EOGoldenHourEnd		length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:goldenColor fillColor:NULL armStrokeColor:[UIColor darkGrayColor] arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:goldenHourEndHand];
    [sunRing addDelegate:goldenHourEndHand];
    civilTwilightBeginHand = [[[EOHandView alloc] initWithKind:EOCivilTwilightBegin	length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:twilightColor fillColor:NULL armStrokeColor:twilightArmColor arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:civilTwilightBeginHand];
    [sunRing addDelegate:civilTwilightBeginHand];
    nauticalTwilightBeginHand = [[[EOHandView alloc] initWithKind:EONauticalTwilightBegin	length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:twilightColor fillColor:NULL armStrokeColor:twilightArmColor arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:nauticalTwilightBeginHand];
    [sunRing addDelegate:nauticalTwilightBeginHand];
    astronomicalTwilightBeginHand = [[[EOHandView alloc] initWithKind:EOAstronomicalTwilightBegin	length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:twilightColor fillColor:NULL armStrokeColor:twilightArmColor arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:astronomicalTwilightBeginHand];
    [sunRing addDelegate:astronomicalTwilightBeginHand];
    goldenHourBeginHand = [[[EOHandView alloc] initWithKind:EOGoldenHourBegin		length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:goldenColor fillColor:NULL armStrokeColor:[UIColor darkGrayColor] arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:goldenHourBeginHand];
    [sunRing addDelegate:goldenHourBeginHand];
    civilTwilightEndHand = [[[EOHandView alloc] initWithKind:EOCivilTwilightEnd		length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:twilightColor fillColor:NULL armStrokeColor:twilightArmColor arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:civilTwilightEndHand];
    [sunRing addDelegate:civilTwilightEndHand];
    nauticalTwilightEndHand = [[[EOHandView alloc] initWithKind:EONauticalTwilightEnd	length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:twilightColor fillColor:NULL armStrokeColor:twilightArmColor arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:nauticalTwilightEndHand];
    [sunRing addDelegate:nauticalTwilightEndHand];
    astronomicalTwilightEndHand = [[[EOHandView alloc] initWithKind:EOAstronomicalTwilightEnd	length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:twilightColor fillColor:NULL armStrokeColor:twilightArmColor arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:astronomicalTwilightEndHand];
    [sunRing addDelegate:astronomicalTwilightEndHand];
    snoonHand = [[[EOHandView alloc] initWithKind:EOSolarNoon	length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:snoonColor fillColor:NULL armStrokeColor:[UIColor darkGrayColor] arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:snoonHand];
    [sunRing addDelegate:snoonHand];
    smidHand = [[[EOHandView alloc] initWithKind:EOSolarMidnight	length:sunRiseSetLen length2:len2 width:sunRiseSetWidth x:mainX y:mainY update:riseSetUpdate strokeColor:smidColor fillColor:NULL armStrokeColor:[UIColor darkGrayColor] arrowLength:sunRiseSetArrow] autorelease];
    [self addSubview:smidHand];
    [sunRing addDelegate:smidHand];
    
    // external subdials
    altHand = [[[EOHandTriangleView alloc] initWithKind:EOAltitude length:altR*.90 width:3   x:altX y:altY update:extHandUpdate strokeColor:[UIColor lightGrayColor] fillColor:NULL] autorelease];
    altHand.planet = (ECPlanetNumber)[[NSUserDefaults standardUserDefaults] integerForKey:@"EOPlanet"];
    [self addSubview:altHand];
    altLabel = [self createLabelAtX:altX Y:altY+altR/2-planetH/2 width:planetW height:planetH fontSize:extFontSize];
#ifndef CAPTUREDEFAULTS
    altLabel.text = [Utilities nameOfPlanetWithNumber:altHand.planet];
#endif
    altBut = [self createButtonAtX:altX Y:altY width:altR*2 height:altR*2 highlight:true text:NULL color:NULL];
    altBut.hidden = false;
    
    azHand = [[[EOHandTriangleView alloc] initWithKind:EOAzimuth length:azR*.90 width:3   x:azX y:azY update:extHandUpdate strokeColor:[UIColor lightGrayColor] fillColor:NULL] autorelease];
    [self addSubview:azHand];
    azHand.planet = altHand.planet;
    azLabel = [self createLabelAtX:azX Y:azY+azR/2-planetH/2 width:planetW height:planetH fontSize:extFontSize];
#ifndef CAPTUREDEFAULTS
    azLabel.text = [Utilities nameOfPlanetWithNumber:azHand.planet];
#endif
    azBut = [self createButtonAtX:azX Y:azY width:azR*2 height:azR*2 highlight:true text:NULL color:NULL];
    azBut.hidden = false;

#ifdef EOHEADING
    northHand = [[[EOHandTriangleView alloc] initWithKind:EONorth length:azR  width:2   x:azX y:azY update:.5 strokeColor:[UIColor redColor] fillColor:NULL] autorelease];
    [self addSubview:northHand];
#endif
    
#ifdef DSTINDICATORS
    springDSTIndicator = [[EOSimpleImageShuffleView alloc] initAtCenter:CGPointMake(sDSTX, sDSTY) srcImageName:@"springForward.png"];
    fallDSTIndicator = [[EOSimpleImageShuffleView alloc] initAtCenter:CGPointMake(fDSTX, fDSTY) srcImageName:@"fallBack.png"];
    [self addSubview:springDSTIndicator];
    [self addSubview:fallDSTIndicator];
    [self reorientSubView:springDSTIndicator toOrientation:lastOrientation offsetBy:CGPointMake(sDSTX, sDSTY)];
    [self reorientSubView:fallDSTIndicator toOrientation:lastOrientation offsetBy:CGPointMake(fDSTX, fDSTY)];
#endif
    
#ifdef SEASONS
    // season icons
#define seasonIconOffset 20
    springIcon = [[EOSimpleImageShuffleView alloc] initAtCenter:CGPointMake(yearX+seasonIconOffset, yearY-seasonIconOffset) srcImageName:@"spring.png"];
    summerIcon = [[EOSimpleImageShuffleView alloc] initAtCenter:CGPointMake(yearX+seasonIconOffset, yearY+seasonIconOffset) srcImageName:@"summer.png"];
    fallIcon   = [[EOSimpleImageShuffleView alloc] initAtCenter:CGPointMake(yearX-seasonIconOffset, yearY+seasonIconOffset) srcImageName:@"fall.png"];
    winterIcon = [[EOSimpleImageShuffleView alloc] initAtCenter:CGPointMake(yearX-seasonIconOffset, yearY-seasonIconOffset) srcImageName:@"winter.png"];
    [self addSubview:springIcon];
    [self addSubview:summerIcon];
    [self addSubview:fallIcon];
    [self addSubview:winterIcon];
    [self reorientSubView:springIcon toOrientation:lastOrientation offsetBy:CGPointMake(yearX+seasonIconOffset, yearY-seasonIconOffset)];
    [self reorientSubView:summerIcon toOrientation:lastOrientation offsetBy:CGPointMake(yearX+seasonIconOffset, yearY+seasonIconOffset)];
    [self reorientSubView:fallIcon   toOrientation:lastOrientation offsetBy:CGPointMake(yearX-seasonIconOffset, yearY+seasonIconOffset)];
    [self reorientSubView:winterIcon toOrientation:lastOrientation offsetBy:CGPointMake(yearX-seasonIconOffset, yearY-seasonIconOffset)];
#endif

#if 0
    yearHand = [[[EOHandTriangleView alloc] initWithKind:EOLeapYear length:yearR*.90 width:3   x:yearX y:yearY update:3600 strokeColor:[UIColor lightGrayColor] fillColor:NULL] autorelease];
    [self addSubview:yearHand];
#endif

    //moonAgeView = [[EOMoonAgeView alloc] initWithOuterRadius:eclipseR2 innerRadius:eclipseR1 x:eclipseX y:eclipseY update:planetUpdate];
    //[self addSubview:moonAgeView];

    eclipseView = [[EOEclipseView alloc] initWithMoonImageName:@"moon300.png"
						  sunImageName:@"sunEclipse.png"
					  earthShadowImageName:@"earthShadow.png"
					   totalSolarImageName:@"totalEclipse.png"
				     earthShadowRadiusFraction:(118.0/120.0)  // 1-pix border on each side
					     sunRadiusFraction:(68.0/316.0)
							     x:eclipseX
							     y:eclipseY
						    viewRadius:eclipseR1
					   moonRadiusAtPerigee:20
							update:eclipseUpdate];
    [self addSubview:eclipseView];
    eclipseHorizonLabel = [self createLabelAtX:eclipseHorizonX Y:eclipseHorizonY width:100 height:20 fontSize:eclipseHorizonFontSize];
    [eclipseHorizonLabel setHidden:true];
    [eclipseHorizonLabel setText:NSLocalizedString(@"Below horizon", "label for when the eclipse is below the horizon")];
    eclipseHorizonLabel.adjustsFontSizeToFitWidth = YES; 
    [eclipseView setStatusLabel:eclipseStatusLabel horizonLabel:eclipseHorizonLabel];
    demoBut = [self createButtonAtX:eclipseX Y:eclipseY-demoButtonOffsetY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"Demo", "label for eclipse demonstration button") color:[UIColor lightGrayColor]];

#ifndef CAPTUREDEFAULTS
    eclipseRingSunHand = [[EOEclipseRingImageView alloc] initWithKind:EOEclipseRingSun name:@"eclipseRingSun.png" radius:eclipseR2+4 x:eclipseX y:eclipseY update:planetUpdate];
    eclipseRingSunHand.hidden = true;
    [self addSubview:eclipseRingSunHand];
    eclipseRingMoonHand = [[EOEclipseRingImageView alloc] initWithKind:EOEclipseRingMoon name:@"eclipseRingMoon.png" radius:eclipseR1-1 x:eclipseX y:eclipseY update:planetUpdate];
    eclipseRingMoonHand.hidden = true;
    [self addSubview:eclipseRingMoonHand];
    eclipseRingEarthShadowHand = [[EOEclipseRingImageView alloc] initWithKind:EOEclipseRingEarthShadow name:@"eclipseRingEarthShadow.png" radius:eclipseR1-1 x:eclipseX y:eclipseY update:planetUpdate];
    eclipseRingEarthShadowHand.hidden = true;
    [self addSubview:eclipseRingEarthShadowHand];
    eclipseRingAscNodeHand = [[EOEclipseRingImageView alloc] initWithKind:EOEclipseRingAscNode name:@"eclipseRingAscNode.png" radius:(eclipseR1 + eclipseR2)/2 x:eclipseX y:eclipseY update:planetUpdate];
    eclipseRingAscNodeHand.hidden = true;
    [self addSubview:eclipseRingAscNodeHand];
    eclipseRingDesNodeHand = [[EOEclipseRingImageView alloc] initWithKind:EOEclipseRingDesNode name:@"eclipseRingDesNode.png" radius:(eclipseR1 + eclipseR2)/2 x:eclipseX y:eclipseY update:planetUpdate];
    eclipseRingDesNodeHand.hidden = true;
    [self addSubview:eclipseRingDesNodeHand];
#endif

    yearBut  = [self createButtonAtX:advButtonX + advYearButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"year", "short abbreviation for year") color:fwdColor];
    yearButB = [self createButtonAtX:advButtonX + backYearButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"year", "short abbreviation for year") color:bckColor];
    centBut  = [self createButtonAtX:advButtonX + advCentButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"cent", "short abbreviation for century") color:fwdColor];
    centButB = [self createButtonAtX:advButtonX + backCentButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"cent", "short abbreviation for century") color:bckColor];
    
    eotHand = [[[EOHandTriangleView alloc] initWithKind:EOEOTMinutes length:EOTR*.90 width:3   x:EOTX y:EOTY update:extHandUpdate strokeColor:[UIColor lightGrayColor] fillColor:NULL] autorelease];
    [self addSubview:eotHand];
    minuteBut  = [self createButtonAtX:advButtonX + advMinuteButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"min", "short abbreviation for minute") color:fwdColor];
    minuteButB = [self createButtonAtX:advButtonX + backMinuteButtonOffsetX Y:advButtonY width:advButtonWidth height:advButtonHeight highlight:true text:NSLocalizedString(@"min", "short abbreviation for minute") color:bckColor];
    
    snoozeBut = [self createButtonAtX:0 Y:0 width:1024 height:1024 highlight:true text:NULL color:NULL];
    snoozeBut.hidden = true;
    
    //lastOrientation = saveOrientation;
//[self initializeConstantsForOrientation:lastOrientation];
//[self moveClockWidgetsForOrientation:lastOrientation];

    [self setupTimerAndDateLabel];
    [self updateLabelsSeasonsAlarmDSTAndStatusIndicator];
    
    tracePrintf1("%lu views", (unsigned long)[subviews count]);
    traceExit("createClockWidgets");
}

// Can be placed in an animation block...
- (void)moveClockWidgetsForOrientation:(UIInterfaceOrientation)newOrientation newSize:(CGSize)newSize {
    // now get all parts to update themselves to the new orientation
    if (newOrientation != lastOrientation) {
        double newCenterX = newSize.width / 2;
        double newCenterY = newSize.height / 2;
        printf("moveClockWidgets center %f %f\n", newCenterX, newCenterY);
	centerX = newCenterX;
	centerY = newCenterY;

	[self reorientSubView:ringsAndPlanetsBackView toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:logoView toOrientation:newOrientation offsetBy:CGPointMake(logoX, logoY)];
	[self reorientSubView:altitudeDialView toOrientation:newOrientation offsetBy:CGPointMake(altX, altY)];
	[self reorientSubView:azimuthDialView toOrientation:newOrientation offsetBy:CGPointMake(azX, azY)];
	[self reorientSubView:eclipseDialView toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
	[self reorientSubView:eotDialView toOrientation:newOrientation offsetBy:CGPointMake(EOTX, EOTY)];
	[self reorientSubView:earthBackView toOrientation:newOrientation offsetBy:CGPointMake(BMX, BMY)];

	[self reorientSubView:utcdayLabel toOrientation:newOrientation offsetBy:CGPointMake(utcdayX, utcdayY+(UIDeviceOrientationIsLandscape(newOrientation)?3
                                                                                                              :0))];
	[self reorientSubView:tzLabel toOrientation:newOrientation offsetBy:CGPointMake(tzX, tzY+(UIDeviceOrientationIsLandscape(newOrientation)?6:0))];
	[self reorientSubView:NTPStatusLabel toOrientation:newOrientation offsetBy:CGPointMake(NTPStatusX, NTPStatusY)];
        [self reorientSubView:NTPStatusBut toOrientation:newOrientation offsetBy:CGPointMake(NTPStatusX, NTPStatusY)];
        
	[self reorientSubView:earthView toOrientation:newOrientation offsetBy:CGPointMake(BMX, BMY)];
	[self reorientSubView:moonView toOrientation:newOrientation offsetBy:CGPointMake(ChandraX, ChandraY)];
	[self reorientSubView:bigDate toOrientation:newOrientation offsetBy:CGPointMake(bdX, bdY)];
	[self reorientSubView:bigDate2 toOrientation:newOrientation offsetBy:CGPointMake(bdX2, bdY2)];
	[self reorientSubView:yearLabel toOrientation:newOrientation offsetBy:CGPointMake(bdX3, bdY3)];
	[self reorientSubView:leapLabel toOrientation:newOrientation offsetBy:CGPointMake(bdX4, bdY3)];
	[self reorientSubView:eclipseStatusLabel toOrientation:newOrientation offsetBy:CGPointMake(eclipseStatusX, eclipseStatusY)];
	[self reorientSubView:eclipseHorizonLabel toOrientation:newOrientation offsetBy:CGPointMake(eclipseHorizonX, eclipseHorizonY)];
	
	[self reorientSubView:minuteBut toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + advMinuteButtonOffsetX, advButtonY)];
	[self reorientSubView:hourBut toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + advHourButtonOffsetX, advButtonY)];
	[self reorientSubView:lunarBut toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + advPhaseButtonOffsetX, advButtonY)];
	[self reorientSubView:dayBut toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + advDayButtonOffsetX, advButtonY)];
	[self reorientSubView:monBut toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + advMonthButtonOffsetX, advButtonY)];
	[self reorientSubView:yearBut toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + advYearButtonOffsetX, advButtonY)];
	[self reorientSubView:centBut toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + advCentButtonOffsetX, advButtonY)];
	[self reorientSubView:minuteButB toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + backMinuteButtonOffsetX, advButtonY)];
	[self reorientSubView:hourButB toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + backHourButtonOffsetX, advButtonY)];
	[self reorientSubView:lunarButB toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + backPhaseButtonOffsetX, advButtonY)];
	[self reorientSubView:dayButB toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + backDayButtonOffsetX, advButtonY)];
	[self reorientSubView:monButB toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + backMonthButtonOffsetX, advButtonY)];
	[self reorientSubView:yearButB toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + backYearButtonOffsetX, advButtonY)];
	[self reorientSubView:centButB toOrientation:newOrientation offsetBy:CGPointMake(advButtonX + backCentButtonOffsetX, advButtonY)];
	[self reorientSubView:demoBut toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY-demoButtonOffsetY)];
	
	[self reorientSubView:utcHourHand toOrientation:newOrientation offsetBy:CGPointMake(UTCX, UTCY)];
	[self reorientSubView:utcMinuteHand toOrientation:newOrientation offsetBy:CGPointMake(UTCX, UTCY)];
	[self reorientSubView:utcSecondHand toOrientation:newOrientation offsetBy:CGPointMake(UTCX, UTCY)];
	[self reorientSubView:solarHourHand toOrientation:newOrientation offsetBy:CGPointMake(solarX, solarY)];
	[self reorientSubView:solarMinuteHand toOrientation:newOrientation offsetBy:CGPointMake(solarX, solarY)];
	[self reorientSubView:solarSecondHand toOrientation:newOrientation offsetBy:CGPointMake(solarX, solarY)];
	[self reorientSubView:siderealHourHand toOrientation:newOrientation offsetBy:CGPointMake(sidX, sidY)];
	[self reorientSubView:siderealMinuteHand toOrientation:newOrientation offsetBy:CGPointMake(sidX, sidY)];
	[self reorientSubView:siderealSecondHand toOrientation:newOrientation offsetBy:CGPointMake(sidX, sidY)];
	[self reorientSubView:azHand toOrientation:newOrientation offsetBy:CGPointMake(azX, azY)];
#ifdef EOHEADING
	[self reorientSubView:northHand toOrientation:newOrientation offsetBy:CGPointMake(azX, azY)];
#endif
	[self reorientSubView:altHand toOrientation:newOrientation offsetBy:CGPointMake(altX, altY)];
//	[self reorientSubView:yearHand toOrientation:newOrientation offsetBy:CGPointMake(yearX, yearY)];
	[self reorientSubView:eclipseView toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
	//[self reorientSubView:moonAgeView toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
	[self reorientSubView:eclipseRingSunHand toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
	[self reorientSubView:eclipseRingMoonHand toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
	[self reorientSubView:eclipseRingEarthShadowHand toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
	[self reorientSubView:eclipseRingAscNodeHand toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
	[self reorientSubView:eclipseRingDesNodeHand toOrientation:newOrientation offsetBy:CGPointMake(eclipseX, eclipseY)];
	[self reorientSubView:eotHand toOrientation:newOrientation offsetBy:CGPointMake(EOTX, EOTY)];
	[self reorientSubView:azBut toOrientation:newOrientation offsetBy:CGPointMake(azX, azY)];
	[self reorientSubView:altBut toOrientation:newOrientation offsetBy:CGPointMake(altX, altY)];
	[self reorientSubView:snoozeBut toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:azLabel toOrientation:newOrientation offsetBy:CGPointMake(azX, azY+altR/2-planetH/2)];
	[self reorientSubView:altLabel toOrientation:newOrientation offsetBy:CGPointMake(altX, altY+altR/2-planetH/2)];
	
	[self reorientSubView:sunRing toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:moonRing toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:mercuryRing toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:venusRing toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:marsRing toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:jupiterRing toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:saturnRing toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];

	[self reorientSubView:alarmHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:hour24Hand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:sunriseHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:sunsetHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:goldenHourEndHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:civilTwilightBeginHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:nauticalTwilightBeginHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:astronomicalTwilightBeginHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:goldenHourBeginHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:civilTwilightEndHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:nauticalTwilightEndHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:astronomicalTwilightEndHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:snoonHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:smidHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	
	[self reorientSubView:hour12Hand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:minuteHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:secondHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];

	[self reorientSubView:saturnHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:jupiterHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:marsHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:earthHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:venusHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];
	[self reorientSubView:mercuryHand toOrientation:newOrientation offsetBy:CGPointMake(mainX, mainY)];

	[self reorientSubView:resetBut toOrientation:newOrientation offsetBy:CGPointMake(resetX, resetY)];

#ifdef SEASONS
	[self reorientSubView:springIcon toOrientation:newOrientation offsetBy:CGPointMake(yearX-seasonIconOffset, yearY+seasonIconOffset)];
	[self reorientSubView:summerIcon toOrientation:newOrientation offsetBy:CGPointMake(yearX+seasonIconOffset, yearY+seasonIconOffset)];
	[self reorientSubView:fallIcon   toOrientation:newOrientation offsetBy:CGPointMake(yearX+seasonIconOffset, yearY-seasonIconOffset)];
	[self reorientSubView:winterIcon toOrientation:newOrientation offsetBy:CGPointMake(yearX-seasonIconOffset, yearY-seasonIconOffset)];
#endif
#ifdef DSTINDICATORS
	[self reorientSubView:springDSTIndicator toOrientation:newOrientation offsetBy:CGPointMake(sDSTX, sDSTY)];
	[self reorientSubView:fallDSTIndicator toOrientation:newOrientation offsetBy:CGPointMake(fDSTX, fDSTY)];
	[self resizeSubView:springDSTIndicator masterScale:ringMasterScale];
	[self resizeSubView:fallDSTIndicator masterScale:ringMasterScale];
#endif
	[self resizeSubView:ringsAndPlanetsBackView masterScale:ringMasterScale];
	[self resizeSubView:earthBackView masterScale:earthMasterScale];
	[self resizeSubView:earthView masterScale:earthMasterScale];
	[self resizeSubView:moonView masterScale:moonMasterScale];
	[self resizeSubView:sunRing masterScale:ringMasterScale];
	[self resizeSubView:moonRing masterScale:ringMasterScale];
	[self resizeSubView:mercuryRing masterScale:ringMasterScale];
	[self resizeSubView:venusRing masterScale:ringMasterScale];
	[self resizeSubView:marsRing masterScale:ringMasterScale];
	[self resizeSubView:jupiterRing masterScale:ringMasterScale];
	[self resizeSubView:saturnRing masterScale:ringMasterScale];
	[self resizeSubView:hour24Hand masterScale:ringMasterScale];
	[self resizeSubView:alarmHand masterScale:ringMasterScale];
	[self resizeSubView:sunriseHand masterScale:ringMasterScale];
	[self resizeSubView:sunsetHand masterScale:ringMasterScale];
	[self resizeSubView:goldenHourEndHand masterScale:ringMasterScale];
	[self resizeSubView:civilTwilightBeginHand masterScale:ringMasterScale];
	[self resizeSubView:nauticalTwilightBeginHand masterScale:ringMasterScale];
	[self resizeSubView:astronomicalTwilightBeginHand masterScale:ringMasterScale];
	[self resizeSubView:goldenHourBeginHand masterScale:ringMasterScale];
	[self resizeSubView:civilTwilightEndHand masterScale:ringMasterScale];
	[self resizeSubView:nauticalTwilightEndHand masterScale:ringMasterScale];
	[self resizeSubView:astronomicalTwilightEndHand masterScale:ringMasterScale];
	[self resizeSubView:snoonHand masterScale:ringMasterScale];
	[self resizeSubView:smidHand masterScale:ringMasterScale];
	[self resizeSubView:hour12Hand masterScale:ringMasterScale];
	[self resizeSubView:minuteHand masterScale:ringMasterScale];
	[self resizeSubView:secondHand masterScale:ringMasterScale];
#ifdef INNER_SUBDIALS
	[self resizeSubView:utcHourHand masterScale:ringMasterScale];
	[self resizeSubView:utcMinuteHand masterScale:ringMasterScale];
	[self resizeSubView:utcSecondHand masterScale:ringMasterScale];
	[self resizeSubView:solarHourHand masterScale:ringMasterScale];
	[self resizeSubView:solarMinuteHand masterScale:ringMasterScale];
	[self resizeSubView:solarSecondHand masterScale:ringMasterScale];
	[self resizeSubView:siderealHourHand masterScale:ringMasterScale];
	[self resizeSubView:siderealMinuteHand masterScale:ringMasterScale];
	[self resizeSubView:siderealSecondHand masterScale:ringMasterScale];
#endif
	[self resizeSubView:saturnHand masterScale:ringMasterScale];
	[self resizeSubView:jupiterHand masterScale:ringMasterScale];
	[self resizeSubView:marsHand masterScale:ringMasterScale];
	[self resizeSubView:earthHand masterScale:ringMasterScale];
	[self resizeSubView:venusHand masterScale:ringMasterScale];
	[self resizeSubView:mercuryHand masterScale:ringMasterScale];

#ifdef SEASONS
	[self resizeSubView:springIcon masterScale:ringMasterScale];
	[self resizeSubView:summerIcon masterScale:ringMasterScale];
	[self resizeSubView:fallIcon masterScale:ringMasterScale];
	[self resizeSubView:winterIcon masterScale:ringMasterScale];
#endif	
	//moonHand is a subview of earthHand so it needs further modification
        // First, the location of the subview needs to change because the bounds rectangle has changed
        CGPoint center;
        center.x = 38;
        center.y = 17;
        CGRect requestedFrame = moonHand.requestedFrame;
        requestedFrame.origin.x = center.x * ringMasterScale - requestedFrame.size.width / 2;
        requestedFrame.origin.y = center.y * ringMasterScale - requestedFrame.size.height / 2;
        CGRect roundedOutFrame;
        CGPoint zeroOffset;
        roundOutFrameToIntegralBoundaries(&requestedFrame, ringMasterScale, &roundedOutFrame, &zeroOffset);
        setFrameForViewAtZeroRotation(moonHand, &roundedOutFrame);
        [moonHand setZeroOffset:zeroOffset];
        [moonHand setRequestedFrame:requestedFrame];
        [moonHand setNeedsDisplay];

        // And it also needs to get resized
	[self resizeSubView:moonHand masterScale:ringMasterScale];

	lastOrientation = newOrientation;
	
	[self reorientSubView:dateLabel toOrientation:newOrientation offsetBy:CGPointMake(0, fullHeight/2-20)];
    }
}

- (void)clockRedraw:(CGContextRef)context forOrientation:(UIInterfaceOrientation)orientation {
    bool landscapeMode = (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight);

    traceEnter("clockRedraw");
    ESAssert(mainR != 0);		    // must have run initializeConstants

    // transform to center in the middle of the screen with Y increasing UP
    CGContextTranslateCTM(context, [EOClock clockCenter].x, [EOClock clockCenter].y);
    CGContextScaleCTM(context, 1, -1);

    //////////// header box
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetLineWidth(context, headerLineWidth);
    CGContextSetRGBStrokeColor(context, 0.5, 0.5, 0.5, .5);
    if (landscapeMode) {
	CGContextStrokeRect(context, CGRectMake(EOSCREENHEIGHT/2 - bmw*earthMasterScale - headerLineWidth*2 + 1, EOSCREENWIDTH/2 - EOSTATICSTATUSBARHEIGHT/2 - headerHeight*earthMasterScale - headerLineWidth*2 + 1, bmw*earthMasterScale + headerLineWidth, headerHeight*earthMasterScale + headerLineWidth));
    } else {
	CGContextStrokeRect(context, CGRectMake(-EOSCREENWIDTH/2 + headerLineWidth/2, EOSCREENHEIGHT/2-EOSTATICSTATUSBARHEIGHT/2 - headerLineWidth*2 -headerHeight, EOSCREENWIDTH-headerLineWidth, headerHeight+headerLineWidth));
	CGContextMoveToPoint(context, -bmw/2-1, EOSCREENHEIGHT/2-EOSTATICSTATUSBARHEIGHT/2-headerLineWidth);
	CGContextAddLineToPoint(context, -bmw/2-1, EOSCREENHEIGHT/2-EOSTATICSTATUSBARHEIGHT/2-headerLineWidth-headerHeight-1);
	CGContextMoveToPoint(context,  bmw/2+1, EOSCREENHEIGHT/2-EOSTATICSTATUSBARHEIGHT/2-headerLineWidth);
	CGContextAddLineToPoint(context, bmw/2+1, EOSCREENHEIGHT/2-EOSTATICSTATUSBARHEIGHT/2-headerLineWidth-headerHeight-1);
	CGContextDrawPath(context, kCGPathStroke);
    }
    
    traceExit("clockRedraw");
}

- (void)clockSetup:(EOBaseView *)theview orientation:(UIInterfaceOrientation)orientation {
    traceEnter("clockSetup");
    view = theview;
    [self initializeConstantsForOrientation:orientation];
    [self createClockWidgets];
    traceExit("clockSetup");
}

- (void)prepareToReorient:(UIInterfaceOrientation)newOrientation {
    aboutToReorient = true;
    if (firstAfterComingToForeground && (newOrientation != lastOrientation)) {
	for (EOScheduledView *v in subviews) {
	    [v zeroAngle];
	    [v resetTarget];
	}
    }
    [UIApplication sharedApplication].statusBarHidden = false;
    dateLabel.hidden = true;
}

- (void)resetAfterOrientationChangeToOrientation:(UIInterfaceOrientation)newOrientation newSize:(CGSize)newSize {
    [self initializeConstantsForOrientation:newOrientation];
    [self moveClockWidgetsForOrientation:newOrientation newSize:newSize];
    aboutToReorient = false;
    if (finishingHelp) {
        finishingHelp = false;
    } else {
	[self setStatusBar:NULL];
        dateLabel.hidden = !setMode;
    }
}

+ (ESWatchTime *)alarmTime {
    return alarmTime;
}

- (void)updateAlarmHand {
    [alarmHand update];
}

- (int)ringsForTime {
    double hours = floor(ESUtil::fmod(alarmTime->secondsSinceMidnightValueUsingEnv(env) / 3600, 24));
    hours = hours == 0 ? 12 : hours <= 12 ? hours : hours - 12;
    return hours;
}

+ (void)setAlarmTime:(NSDate *)aTime {
    // start with midnight today
    ESTimeInterval now = ESTime::currentTime();
    ESTimeZone *estz = ESCalendar_localTimeZone();
    ESDateComponents comps;
    ESCalendar_localDateComponentsFromTimeInterval(now, estz, &comps);
    comps.hour = 0;
    comps.minute = 0;
    comps.seconds = 0;
    ESTimeInterval midnightToday = ESCalendar_timeIntervalFromLocalDateComponents(estz, &comps);

    // aTime may be in some arbitrary day, only the time is valid; add that to today's midnight value
    ESDateComponents offsetComps;
    ESCalendar_localDateComponentsFromTimeInterval([aTime timeIntervalSinceReferenceDate], estz, &offsetComps);
    double alarmSecondsFromMidnight = offsetComps.hour * 3600 + offsetComps.minute * 60;
    ESTimeInterval alarmDateInterval = midnightToday + alarmSecondsFromMidnight;

    // now adjust for possible DST transition
    ESCalendar_localDateComponentsFromTimeInterval(alarmDateInterval, estz, &comps);
    double delta = (offsetComps.hour - comps.hour) * 3600 + (offsetComps.minute - comps.minute) * 60;
    if (delta == 0) {
	// it was OK
    } else {
	alarmDateInterval += delta;
    }
    
    // move to tomorrow if that time is in the past
    if (now > alarmDateInterval) {
	alarmDateInterval += 86400;
    }
    
    // now make it into an ESWatchTime and save
    delete alarmTime;
    alarmTime = new ESWatchTime(alarmDateInterval);
    alarmTime->saveStateForWatch("EOAlarmTime");
    [theClock updateAlarmHand];
    [EOClock setupLocalNotificationForAlarmStateEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"EOAlarmEnabled"]];
    //printf("alarmTime %d:%d on %d/%d\n",  [alarmTime hour24NumberUsingEnv:theClock.env], [alarmTime minuteNumberUsingEnv:theClock.env], [alarmTime monthNumberUsingEnv:theClock.env]+1, [alarmTime dayNumberUsingEnv:theClock.env]+1);
}

- (void)dealloc {
    [theTimer invalidate];
    [subviews release];
    [azBut release];
    [altBut release];
    [snoozeBut release];
    [dayBut release];
    [monBut release];
    [centBut release];
    [yearBut release];
    [demoBut release];
    [lunarBut release];
    [minuteBut release];
    [hourBut release];
    [resetBut release];

    env->location()->removeObserver(locationObserver);
    delete locationObserver;

    ESTime::unregisterTimeSyncObserver(timeSyncObserver);
    delete timeSyncObserver;

    delete time;
    delete env;

    [dayButB release];
    [monButB release];
    [yearButB release];
    [centButB release];
    [lunarButB release];
    [minuteButB release];
    [hourButB release];
    if (alarmTime) {
        delete alarmTime;
    }
    [super dealloc];  // Do this last
}

@end
