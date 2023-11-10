//
//  EOBatteryAndDAL.m
//  Emerald Observatory
//
//  Created by Bill Arnett on 7/3/2010. (but mostly stolen from EC)
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "EOBatteryAndDAL.h"

@implementation EOBatteryAndDAL

#define theApplication [UIApplication sharedApplication]

static int lastBatteryState = -1;
static BOOL currentDAL;

static bool batteryStatesAreEquivalent(int batteryState1, int batteryState2) {
    return batteryState1 == batteryState2 ||
	  (batteryState1 == UIDeviceBatteryStateFull     && batteryState2 == UIDeviceBatteryStateCharging) ||
	  (batteryState1 == UIDeviceBatteryStateCharging && batteryState2 == UIDeviceBatteryStateFull);
}

// static const char *batteryStateNameForState(int batteryState) {
//     char *stateName;
//     switch (batteryState) {
// 	case UIDeviceBatteryStateUnknown:
// 	    stateName = "unknown";
// 	    break;
// 	case UIDeviceBatteryStateUnplugged:
// 	    stateName = "unplugged";
// 	    break;
// 	case UIDeviceBatteryStateCharging:
// 	    stateName = "charging";
// 	    break;
// 	default:
// 	    assert(false);
// 	case UIDeviceBatteryStateFull:
// 	    stateName = "full";
// 	    break;
//     }
//     return stateName;
// }

+ (void)setDAL:(BOOL)newVal {
   //tracePrintf1("setDAL: %d", newVal);
    assert([NSThread isMainThread]);
    currentDAL = newVal;
    theApplication.idleTimerDisabled = !newVal;
    theApplication.idleTimerDisabled = newVal;
}

+ (void)setDALHeartbeatFire:(NSTimer *)timer {
    if (currentDAL) {
	//tracePrintf("setDALHeartbeatFire");
	theApplication.idleTimerDisabled = !currentDAL;
	theApplication.idleTimerDisabled = currentDAL;
    }
}

+ (void)setDALForBatteryState:(int) batteryState {
    //tracePrintf1("setting DAL for %s", batteryStateNameForState(batteryState));
    BOOL dalDefault;
    if (batteryState == UIDeviceBatteryStateFull || batteryState == UIDeviceBatteryStateCharging) {
	dalDefault = [[NSUserDefaults standardUserDefaults] boolForKey:@"EODisableAutoLock"];
    } else {
	dalDefault = [[NSUserDefaults standardUserDefaults] boolForKey:@"EODisableAutoLockUnplugged"];
    }
    [self setDAL:dalDefault];
}

+ (void)setDALForBatteryState {
    [self setDALForBatteryState:(int)[[UIDevice currentDevice] batteryState]];
}

+ (void)setDALOption:(bool)val whenPluggedIn:(bool)plugged {
    //tracePrintf2("setting DAL option to %d whenPluggedIn %d", val, plugged);
    if (plugged) {
	[[NSUserDefaults standardUserDefaults] setBool:val forKey:@"EODisableAutoLock"];
    } else {
    	[[NSUserDefaults standardUserDefaults] setBool:val forKey:@"EODisableAutoLockUnplugged"];
    }
    [self setDALForBatteryState:(int)[[UIDevice currentDevice] batteryState]];
}

+ (void)delayedSetDal:(NSTimer *)timer {
    //tracePrintf("delayedSetDal");
    [self setDALForBatteryState];
}

+ (void)batteryStateDidChange:(id)foo {
    int newState = (int)[[UIDevice currentDevice] batteryState];
    //tracePrintf1("batteryStateDidChange to %s", batteryStateNameForState(newState));
    if (!batteryStatesAreEquivalent(newState,lastBatteryState)) {
	[self setDALForBatteryState:newState];
    }
    lastBatteryState = newState;
}

+ (void)startup {
    // Toggle DAL state to work around apparent bug in OS
    [UIApplication sharedApplication].idleTimerDisabled = false;
    [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(delayedSetDal:) userInfo:nil repeats:false];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(setDALHeartbeatFire:) userInfo:nil repeats:true];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryStateDidChange:)
                                                 name:@"UIDeviceBatteryStateDidChangeNotification" object:nil];
}

@end
