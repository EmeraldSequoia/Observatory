//
//  Utilities.m
//  Emerald Orrery from Emerald Chronometer ChronometerAppDelegate
//
//  Created by Bill Arnett on 4/16/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ESPlatform.h"
#import "ESUtil.hpp"
#import "Constants.h"
#import "Utilities.h"
#import "ESTime.hpp"
#import "ESCalendar.hpp"

#include <sys/types.h>
#include <sys/sysctl.h>

#include <libkern/OSAtomic.h>  // For OSMemoryBarrier()

@implementation Utilities

double startOfMainTime;
double lastTimeNoted = -1;

double
EC_fmod(double arg1,
	double arg2)
{
    return (arg1 - floor(arg1/arg2)*arg2);
}

void
printDate(const char *description) {
    NSTimeInterval dt = ESTime::currentTime();
    double fractionalSeconds = dt - floor(dt);
    int microseconds = round(fractionalSeconds * 1000000);
    ESDateComponents ltcs;
    ESCalendar_localDateComponentsFromTimeInterval(dt, ESCalendar_localTimeZone(), &ltcs);
    printf("%d %04d/%02d/%02d %02d:%02d:%02d.%06d LT %s",
	   ltcs.era, ltcs.year, ltcs.month, ltcs.day, ltcs.hour, ltcs.minute, (int)floor(ltcs.seconds), microseconds, description);
}

#ifndef NDEBUG
// static NSString *
// orientationNameForOrientation(UIInterfaceOrientation orient) {
//     switch (orient) {
//       case UIInterfaceOrientationPortrait:
// 	return @"Portrait";
//       case UIInterfaceOrientationPortraitUpsideDown:
// 	return @"PortraitUpsideDown";
//       case UIInterfaceOrientationLandscapeLeft:
// 	return @"LandscapeLeft";
//       case UIInterfaceOrientationLandscapeRight:
// 	return @"LandscapeRight";
//       default:
// 	assert(false);
//     }
// }
#endif

static UIInterfaceOrientation currentOrientation = UIInterfaceOrientationPortrait;
static bool currentOrientationIsLandscape = false;

+ (void)setNewOrientation:(UIInterfaceOrientation)newOrient {
#ifndef NDEBUG
    //printf("Switching to orientation %s\n", [orientationNameForOrientation(newOrient) UTF8String]);
#endif
    currentOrientation = newOrient;
    currentOrientationIsLandscape = (currentOrientation == UIInterfaceOrientationLandscapeRight ||
				     currentOrientation == UIInterfaceOrientationLandscapeLeft);
}

+ (UIInterfaceOrientation)currentOrientation {
    return currentOrientation;
}

+ (bool)currentOrientationIsLandscape {
    return currentOrientationIsLandscape;
}

+ (void)translatePointIntoCurrentOrientation:(CGPoint *)point {
    CGFloat swap;
    switch (currentOrientation) {
      case UIInterfaceOrientationPortrait:
	break;
      case UIInterfaceOrientationPortraitUpsideDown:
	point->y = - point->y;
	point->x = - point->x;
	break;
      case UIInterfaceOrientationLandscapeLeft:
	swap = point->x;
	point->x = point->y;
	point->y = -swap;
	break;
      case UIInterfaceOrientationLandscapeRight:
	swap = point->x;
	point->x = -point->y;
	point->y = swap;
	break;
      default:
	assert(false);
    }
}

static CGSize untranslatedAppSize;
static CGFloat cornerTranslationOffset;

+ (CGSize)applicationSize {
    if (currentOrientation == UIInterfaceOrientationPortrait || currentOrientation == UIInterfaceOrientationPortraitUpsideDown) {
	return untranslatedAppSize;
    } else {
	return CGSizeMake(untranslatedAppSize.height, untranslatedAppSize.width);
    }
}

+ (CGSize)untranslatedApplicationSize {
    return untranslatedAppSize;
}

+ (void)translateCornerRelativeOrigin:(CGPoint *)origin {
    if (currentOrientation != UIInterfaceOrientationPortrait && currentOrientation != UIInterfaceOrientationPortraitUpsideDown) {
	assert(currentOrientation == UIInterfaceOrientationLandscapeRight || currentOrientation == UIInterfaceOrientationLandscapeLeft);
	if (origin->x > 0) {
	    origin->x += cornerTranslationOffset;
	} else {
	    origin->x -= cornerTranslationOffset;
	}
	if (origin->y > 0) {
	    origin->y -= cornerTranslationOffset;
	} else {
	    origin->y += cornerTranslationOffset;
	}
    }
}

+ (void)startOfMain {
    //printf("Emerald Chronometer BOJ\n");
    startOfMainTime = [[NSDate date] timeIntervalSinceReferenceDate];
}

static NSLock *printfLock = nil;

+ (void)noteTimeAtPhase:(const char *)phaseName {
    if (!printfLock) {
	printfLock = [[NSLock alloc] init];
    }
    [printfLock lock];
    double t = [NSDate timeIntervalSinceReferenceDate];
    if (lastTimeNoted < 0) {
	printf("Phase time Cumulative  Description\n");
	printf("%10.4f %10.4f: ", 0.0, t - startOfMainTime);
    } else {
	printf("%10.4f %10.4f: ", t - lastTimeNoted, t - startOfMainTime);
    }
    ESTime::printTimes(phaseName);
    lastTimeNoted = t;
    [printfLock unlock];
}

+ (void)noteTimeAtPhaseWithString:(NSString *)phaseName {
    [self noteTimeAtPhase:[phaseName UTF8String]];
}

+ (void)printAllFonts {
#ifndef NDEBUG
    NSArray *fontFamilies = [UIFont familyNames];
    printf("Fonts in system:\n");
    for (NSString *fontFamily in fontFamilies) {
	printf("%s\n", [fontFamily UTF8String]);
	NSArray *fonts = [UIFont fontNamesForFamilyName:fontFamily];
	for (NSString *fontName in fonts) {
	    printf("   %s\n", [fontName UTF8String]);
	}
    }
#endif
}

+ (UIImage *)imageFromResource:(NSString *)imgName  {				// name of the info file for this watch
    UIImage *img = [UIImage imageNamed:imgName];
    assert(img);
    return img;
}

+ (NSString *)nameOfPlanetWithNumber:(ECPlanetNumber) planetNumber{
    switch(planetNumber) {
	case ECPlanetSun:
	    return NSLocalizedString(@"Sun", @"the proper name of Earth's star");;
	case ECPlanetMoon:
	    return NSLocalizedString(@"Moon", @"the proper name of Earth's moon");
	case ECPlanetMercury:
	    return NSLocalizedString(@"Mercury", @"the planet Mercury");
	case ECPlanetVenus:
	    return NSLocalizedString(@"Venus", @"the planet Venus");
	case ECPlanetEarth:
	    return NSLocalizedString(@"Earth", @"the planet Earth");
	case ECPlanetMars:
	    return NSLocalizedString(@"Mars", @"the planet Mars");	;
	case ECPlanetJupiter:
	    return NSLocalizedString(@"Jupiter", @"the planet Jupiter");
	case ECPlanetSaturn:
	    return NSLocalizedString(@"Saturn", @"the planet Saturn");
	case ECPlanetUranus:
	    return NSLocalizedString(@"Uranus", @"the planet Uranus");
	case ECPlanetNeptune:
	    return NSLocalizedString(@"Neptune", @"the planet Neptune");
	case ECPlanetPluto:
	    return NSLocalizedString(@"Pluto", @"the planet Pluto");
	default:
	    return [NSString stringWithFormat:NSLocalizedString(@"Unknown planet number %d",@"error message"), planetNumber];
    }
}

@end
