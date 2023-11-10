//
//  EOHandView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/16/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "EOHandView.h"
#import <QuartzCore/QuartzCore.h>
#import "EOClock.h"
#import "ESWatchTime.hpp"
#import "ESTimeLocAstroEnvironment.hpp"
#import "ESAstronomy.hpp"
#import "ESLocation.hpp"
#import "Utilities.h"
#import "EOHandTriangleView.h"
#import "EOEclipseRingImageView.h"
#import "EOEclipseView.h"


@implementation EOHandView

@synthesize length, width, planet;

- (void)resetTarget {
    [super resetTarget];
    if (!animationInProgress) {
	first = true;
    }
}

- (EOHandView *)initWithFrame:(CGRect)frame kind:(EOHandKind)aKind update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor {
    if ((self = [super initWithFrame:frame update:aUpdate])) {
	kind = aKind;
	strokeColor = [asColor retain];
	armStrokeColor = [asColor retain];
	fillColor = [afColor retain];
	tim = [EOClock theClock].time;
	env = [[EOClock theClock] env];
	astro = env->astronomyManager();
//	self.clearsContextBeforeDrawing = YES;
	self.opaque = NO;
	self.userInteractionEnabled = false;
	first = true;
	planet = (ECPlanetNumber)-1;	    // invalid
    }
    return self;
}

- (EOHandView *)initWithKind:(EOHandKind)aKind
		      length:(double)aLength
		     length2:(double)aLength2
		       width:(double)aWidth
			   x:(double)ax
			   y:(double)ay
		      update:(double)aUpdate
		 strokeColor:(UIColor *)asColor
		   fillColor:(UIColor *)afColor
	      armStrokeColor:(UIColor *)armsColor
		 arrowLength:(double)arrowL 
    		  arrowWidth:(double)arrowW {
    double w = arrowL > aWidth*2 ? arrowL : aWidth*2;
    ax = ax;
    ay = ay;
    if ((self = [self initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - w/2,
					      -ay + [EOClock clockCenter].y - (aLength+aWidth),
					      w,
					      (aLength+aWidth) * 2)
			      kind:aKind
			    update:aUpdate
		       strokeColor:asColor
			 fillColor:afColor])) {
	length = aLength;
	armStrokeColor = [armsColor retain];
	length2 = aLength2;
	width = aWidth;
	arrowLength = arrowL;
	arrowWidth = arrowW;
	angle = halfPi;
    }
    return self;
}

- (EOHandView *)initWithKind:(EOHandKind)aKind
		      length:(double)aLength
		     length2:(double)aLength2
		       width:(double)aWidth
			   x:(double)ax
			   y:(double)ay
		      update:(double)aUpdate
		 strokeColor:(UIColor *)asColor
		   fillColor:(UIColor *)afColor
	      armStrokeColor:(UIColor *)armsColor
		 arrowLength:(double)arrowL {
    return [self initWithKind:aKind length:aLength length2:aLength2 width:aWidth x:ax y:ay update:aUpdate strokeColor:asColor fillColor:afColor armStrokeColor:armsColor arrowLength:arrowL arrowWidth:arrowL/2/sqrt(3)];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context,YES);
    CGContextSetAllowsAntialiasing(context, YES);
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);
    if (fillColor) {
	[fillColor setFill];
    } else {
	[strokeColor setFill];
    }

    // arm
    [armStrokeColor setStroke];
    CGContextSetLineWidth(context, width);
    CGContextMoveToPoint(context, 0, length2);
    CGContextAddLineToPoint(context, 0, length-arrowLength);
    CGContextDrawPath(context, kCGPathFillStroke);

    // end cap
    [strokeColor setStroke];
    if (arrowLength > 0) {
	CGContextMoveToPoint(context,-arrowWidth, length-arrowLength);
	CGContextAddLineToPoint(context, 0, length);
    	CGContextAddLineToPoint(context, arrowWidth, length-arrowLength);
    } else {
	CGContextAddArc(context, 0, length, width/2, 0, twoPi, 0);
    }
    CGContextDrawPath(context, kCGPathFill);

    // Draw at center
    //CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 0.5);
    //CGContextAddRect(context, CGRectMake(-0.5, -0.5, 1, 1));
    //CGContextDrawPath(context, kCGPathFill);
    
    CGContextRestoreGState(context);
}

#define EOHANDAMIMATIONDURATION 1.0

- (void)zeroAngle {
    angle = 0;
    first = true;
    self.layer.transform = CATransform3DMakeRotation(angle,0,0,1);
}

- (void)update {
#ifndef CAPTUREDEFAULTS
    if (animationInProgress) {
	return;
    }
    
    bool hideMe = false;
    NSTimeInterval now = tim->secondsSinceMidnightValueUsingEnv(env);
    bool rotateLayer = !([self isKindOfClass:[EOHandTriangleView class]] || [self isKindOfClass:[EOEclipseView class]]);
    if (first && rotateLayer) {
	now += EOHANDAMIMATIONDURATION;	    // where it will be when the animation is done
    }
    
    if (kind >= EOFirstAstro) {
	astro->setupLocalEnvironmentForThreadFromActionButton(false, [[EOClock theClock] time]);
    }
    double xMotion = 0;
    double yMotion = 0;
    double firstAngle = 0;
    bool animateMe = true;
    bool validReturn = false;  // Shared by many but not all cases
    switch (kind) {
	case EO60RPM:
	    angle = EC_fmod(now, 60) * twoPi;
	    break;
	case EOSeconds:
	    angle = EC_fmod(now, 60) * twoPi/60;
	    break;
	case EOMinutes:
	    angle = EC_fmod(now / 60, 60) * twoPi/60;
	    break;
	case EO12Hours:
	    angle = EC_fmod(now / 3600, 12) * twoPi/12;
	    break;
	case EOAlarms:
            angle = EC_fmod([EOClock alarmTime]->secondsSinceMidnightValueUsingEnv(env) / 3600, 24) * twoPi/24 + pi * [EOClock theClock].noonOnTop;
	    hideMe = self.layer.hidden;
	    break;
	case EONorth:
            angle = 0; // [[EOLocationManager theLocationManager] lastDirectionDegrees] * twoPi/360;
	    switch ([EOClock theClock].lastOrientation) {
		case UIInterfaceOrientationPortrait:
		    break;
		case UIInterfaceOrientationPortraitUpsideDown:
		    angle += pi;
		    break;
		case UIInterfaceOrientationLandscapeLeft:
		    angle += pi/2;
		    break;
		case UIInterfaceOrientationLandscapeRight:
		    angle -= pi/2;
		    break;
		default:
		    assert(false);
	    }
	    break;
	case EO24Hours:
	    angle = EC_fmod(now / 3600, 24) * twoPi/24 + pi * [EOClock theClock].noonOnTop;
	    break;
	case EOUTCMinutes:
	{
	    double tzOffsetSeconds = tim->tzOffsetUsingEnv(env);
	    angle = (EC_fmod(now / 60, 60) - ((int)rint(tzOffsetSeconds/60) % 60)) * twoPi/60;
	    break;
	}
	case EOUTCHours:
	{
	    double tzOffsetSeconds = tim->tzOffsetUsingEnv(env);
	    angle = (EC_fmod(now / 3600, 24) - (tzOffsetSeconds/3600)) * twoPi/24 + pi * [EOClock theClock].noonOnTop;
	    break;
	}
	case EOWeekdays:
	    angle = tim->weekdayNumberUsingEnv(env) * twoPi/7 - pi/7;
	    break;
	case EOMonths:
	    angle = tim->monthNumberUsingEnv(env) * twoPi/12 + pi/12;
	    break;
	case EODays:
	    angle = tim->dayNumberUsingEnv(env) * twoPi/31 + pi/31;
	    break;
	case EOSunrise:		////////////////////// First Astro
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunRiseMorning, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
 	case EOSunset:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunSetEvening, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EOGoldenHourEnd:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunGoldenHourMorning, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EOCivilTwilightBegin:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunCivilTwilightMorning, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EONauticalTwilightBegin:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunNauticalTwilightMorning, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EOAstronomicalTwilightBegin:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunAstroTwilightMorning, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EOGoldenHourBegin:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunGoldenHourEvening, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EOCivilTwilightEnd:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunCivilTwilightEvening, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EONauticalTwilightEnd:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunNauticalTwilightEvening, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EOAstronomicalTwilightEnd:
            angle = astro->sunSpecial24HourIndicatorAngleForAltitudeKind(sunAstroTwilightEvening, &validReturn/*validReturn*/) + pi * [EOClock theClock].noonOnTop;
            if (!validReturn) {
		hideMe = true;
	    }
	    break;
	case EOSolarNoon:
	    angle = astro->watchTimeWithSuntransitForDay()->hour24ValueUsingEnv(env) * twoPi/24 + pi * [EOClock theClock].noonOnTop;
	    break;
	case EOSolarMidnight:
	    angle = astro->watchTimeWithSuntransitForDay()->hour24ValueUsingEnv(env) * twoPi/24 + pi + pi * [EOClock theClock].noonOnTop;
	    break;
	case EOEOTMinutes:
	    angle = astro->EOT() * 24;
	    break;
#define solarTime (now + env->location()->longitudeRadians() * 86400.0 / twoPi - tim->tzOffsetUsingEnv(env) + astro->EOT() * 86400.0 / twoPi)
	case EOSolarSeconds:
	{
	    angle = fmod(solarTime, 60)*2*pi/60;
	    break;
	}
	case EOSolarMinutes:
	{
	    angle = fmod(solarTime/60, 60)*2*pi/60;
	    break;
	}
	case EOSolarHours:
	{
	    angle = fmod(solarTime/3600, 60)*2*pi/12;
	    break;
	}
	case EOSiderealSeconds:
	    angle = fmod(astro->localSiderealTime(),60)*2*pi/60;
	    break;
	case EOSiderealMinutes:
	    angle = fmod(astro->localSiderealTime()/60,60)*2*pi/60;
	    break;
	case EOSiderealHours:
	    angle = fmod(astro->localSiderealTime()/3600,24)*2*pi/24; // + pi * [EOClock theClock].noonOnTop;
	    break;
	case EOAzimuth:
	    angle = astro->planetAzimuth(planet);
	    break;
	case EOAltitude:
	    angle = astro->planetAltitude(planet) - pi/2;
	    break;
	case EOLeapYear:
	{
	    int yearNumber = tim->yearNumberUsingEnv(env);
	    int eraNumber = tim->eraNumberUsingEnv(env);
	    if (eraNumber && yearNumber >= 1582) { // Gregorian
		angle = yearNumber % 400 == 0 ?  3*pi/4 : 
		        yearNumber % 100 == 0 ?  5*pi/4 :
			yearNumber %   4 == 0 ?  1*pi/4 :
			yearNumber %   4 == 1 ? 19*pi/12 :
			yearNumber %   4 == 2 ? 21*pi/12 :
						23*pi/12;
	    } else { 
		if (eraNumber) { // Julian
		    angle = yearNumber %   4 == 0 ?  1*pi/4 :
			    yearNumber %   4 == 1 ? 19*pi/12 :
			    yearNumber %   4 == 2 ? 21*pi/12 :
						    23*pi/12;
		} else { // proleptic Julian
		    yearNumber -= 1;
		    angle = yearNumber %   4 == 0 ?  1*pi/4 :
			    yearNumber %   4 == 1 ? 19*pi/12 :
			    yearNumber %   4 == 2 ? 21*pi/12 :
						    23*pi/12;
		}
	    }
	    break;
	}
	case EOSaturn:
	    angle = -astro->planetHeliocentricLongitude(ECPlanetSaturn);
	    break;
	case EOJupiter:
	    angle = -astro->planetHeliocentricLongitude(ECPlanetJupiter);
	    break;
	case EOMars:
	    angle = -astro->planetHeliocentricLongitude(ECPlanetMars);
	    break;
	case EOEarth:
	    angle = -astro->planetHeliocentricLongitude(ECPlanetEarth);
	    break;
	case EOVenus:
	    angle = -astro->planetHeliocentricLongitude(ECPlanetVenus);
	    break;
	case EOMercury:
	    angle = -astro->planetHeliocentricLongitude(ECPlanetMercury);
	    break;
	case EOMoon:
	    angle = -astro->moonAgeAngle() + pi;
	    break;
	case EOChandra:
            angle = astro->moonRelativeAngle();            
	    [self setNeedsDisplay];
            break;
        case EOEclipse:
	case EOTerra:
	    [self setNeedsDisplay];
	    break;
        case EOEclipseRingSun:
	{
	    EOEclipseRingImageView *leafClass = (EOEclipseRingImageView *)self;
	    angle = 0;
	    firstAngle = M_PI + astro->planetRA(ECPlanetSun, false/*correctForParallax*/);
	    yMotion = leafClass.radius;
	    animateMe = false;
	    if (first) {
		self.hidden = false;
	    }
	}
	    break;
        case EOEclipseRingMoon:
	{
	    EOEclipseRingImageView *leafClass = (EOEclipseRingImageView *)self;
	    double moonRA = astro->planetRA(ECPlanetMoon, false/*correctForParallax*/);
	    double sunRA = astro->planetRA(ECPlanetSun, false/*correctForParallax*/);
	    firstAngle = M_PI + moonRA;
	    angle = sunRA - moonRA;
	    yMotion = leafClass.radius;
	    animateMe = false;
	    if (first) {
		self.hidden = false;
	    }
	}
	    break;
        case EOEclipseRingEarthShadow:
	{
	    EOEclipseRingImageView *leafClass = (EOEclipseRingImageView *)self;
	    angle = 0;
	    firstAngle = astro->planetRA(ECPlanetSun, false/*correctForParallax*/);
	    yMotion = leafClass.radius;
	    animateMe = false;
	    if (first) {
		self.hidden = false;
	    }
	}
	    break;
        case EOEclipseRingAscNode:
	{
	    EOEclipseRingImageView *leafClass = (EOEclipseRingImageView *)self;
	    firstAngle = M_PI + astro->moonAscendingNodeRA();
	    angle = 0;
	    yMotion = leafClass.radius;
	    animateMe = false;
	    if (first) {
		self.hidden = false;
	    }
	}
	    break;
        case EOEclipseRingDesNode:
	{
	    EOEclipseRingImageView *leafClass = (EOEclipseRingImageView *)self;
	    firstAngle = astro->moonAscendingNodeRA();
	    angle = 0;
	    yMotion = leafClass.radius;
	    animateMe = false;
	    if (first) {
		self.hidden = false;
	    }
	}
	    break;
	default:
	    assert(false);
	    break;
    }
    if (kind >= EOFirstAstro) {
	astro->cleanupLocalEnvironmentForThreadFromActionButton(false);
    }

    if (first && rotateLayer && animateMe) {
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:EOHANDAMIMATIONDURATION];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDone: finished: context:)];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
    }

    self.layer.hidden = hideMe;
    if (rotateLayer) {
	if (firstAngle || xMotion || yMotion) {
	    CATransform3D xform = CATransform3DMakeRotation(firstAngle,0,0,1);
	    xform = CATransform3DTranslate(xform,xMotion,yMotion,0);
	    self.layer.transform = CATransform3DRotate(xform,angle,0,0,1);
	} else {
	    self.layer.transform = CATransform3DMakeRotation(angle,0,0,1);
	}
    } else {
	[self setNeedsDisplay];
    }

    if (first && rotateLayer && animateMe) {
	animationInProgress = true;
	first = false;
	[UIView commitAnimations];
    }
    first = false;
#endif
}

- (void)delayedUpdate:(id)context {
    [self update];
}

- (void)animationDone:(id)animationID finished:(bool)finished context:(id)context {
    animationInProgress = false;
    [self performSelector:@selector(delayedUpdate:) withObject:nil afterDelay:0.001];
}

- (void)dealloc {
    [strokeColor release];
    [armStrokeColor release];
    [fillColor release];
    [super dealloc];
}


@end
