//
//  EORingView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/17/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EORingView.h"
#import "EOClock.h"
#import "ESAstronomy.hpp"
#import "ESWatchTime.hpp"
#import "ESTimeLocAstroEnvironment.hpp"
#import "ESLocation.hpp"
#import "Utilities.h"
#undef ECTRACE
#import "ECTrace.h"


@implementation EORingView

- (void)update {
    [self setNeedsDisplay];
}

- (void)addDelegate:(EOScheduledView *)twiHand {
    [delegates addObject:twiHand];
}

- (EORingView *)initWithPlanet:(ECPlanetNumber)body outerRadius:(double)oR innerRadius:(double)iR x:(double)ax y:(double)ay update:(double)aUpdate dayColor:(UIColor *)dayClr nightColor:(UIColor *)nightClr {
    ax = ax;
    ay = ay;
    if ((self = [self initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - oR,
					      -ay + [EOClock clockCenter].y - oR,
					      oR * 2,
					      oR * 2)
                             update:aUpdate])) {
	planet = body;
	outerR = oR;
	innerR = iR;
	dayColor = [dayClr retain];
	nightColor = [nightClr retain];
	tim = [EOClock theClock].time;
	env = [[EOClock theClock] env];
	astro = env->astronomyManager();
        self.clearsContextBeforeDrawing = YES;
	self.opaque = NO;
	self.userInteractionEnabled = false;
	delegates = [[NSMutableArray alloc] initWithCapacity:8];
    }
    return self;
}
typedef struct gradElement {
    float   alt;
    float   red;
    float   green;
    float   blue;
    float   alpha;
} gradElement;
static const gradElement gradientSteps [] = {	    // alt, r, g, b, a
    {-90.01,0.125, 0.125, 0.125, 0},		    // full night (must match clock background)
    {-30,   0.125, 0.125, 0.125, 0},
    {- 9,   0.00, 0.00, 0.39, 1}, 
    {- 1,   0.17, 0.77, 0.84, 1},
    {-0.5,  0.84, 0.00, 0.00, 1},
    {  1,   0.94, 0.42, 0.00, 1},
    {  9,   1.00, 1.00, 0.00, 1}, 
    { 30,   0.90, 0.90, 1.00, 1},
    { 90.01,0.90, 0.90, 1.00, 1}
};

- (bool)setContextStrokeColor:(CGContextRef)context forAltitude:(double)altr forceDraw:(bool)forceDraw {	    // alt in radians
    double alt = altr * 360/twoPi;
    assert(-90 <= alt && alt <= 90);
    int i = 0;
    while (gradientSteps[i].alt <= alt) {
	++i;
    }
    int j = i - 1;
    assert(j >= 0);
    assert(gradientSteps[j].alt <= alt);
    assert(alt < gradientSteps[i].alt);
    double stepWidth = gradientSteps[i].alt - gradientSteps[j].alt;
    double fraction = (alt - gradientSteps[j].alt) / stepWidth;
    double rDiff = gradientSteps[i].red   - gradientSteps[j].red;	    // difference in red for this step
    double rNew  = gradientSteps[j].red   + rDiff*fraction;
    double gDiff = gradientSteps[i].green - gradientSteps[j].green;
    double gNew  = gradientSteps[j].green + gDiff*fraction;
    double bDiff = gradientSteps[i].blue  - gradientSteps[j].blue;
    double bNew  = gradientSteps[j].blue  + bDiff*fraction;
    double aDiff = gradientSteps[i].alpha - gradientSteps[j].alpha;
    double aNew  = gradientSteps[j].alpha + aDiff*fraction;
    //printf("%7.2f [%d %d] %.2f %.2f %.2f\n", alt, j, i, rNew, gNew, bNew);
    if (forceDraw || fabs(rDiff)+fabs(gDiff)+fabs(bDiff)+fabs(aDiff) > 0) {
	CGContextSetRGBStrokeColor(context, rNew, gNew, bNew, aNew);
	return true;
    }
    return false;
}

- (void)drawRangeFromTime:(NSTimeInterval)fromTime
                   toTime:(NSTimeInterval)toTime
       usingTempWatchTime:(ESWatchTime *)tempWatchTime
                  context:(CGContextRef)context
                      lat:(double)lat
                      lng:(double)lng {
    //printf("drawRangeFromTime from "); printADate(fromTime); printf(" to "); printADate(toTime - 0.02); printf("\n");
    NSTimeInterval t = fromTime;
    tempWatchTime->setToFrozenDateInterval(t);
    double startAngle = EC_fmod(tempWatchTime->secondsSinceMidnightValueUsingEnv(env) / 3600, 24) * twoPi/24 + pi * [EOClock theClock].noonOnTop;
    if (startAngle > twoPi) {
        startAngle -= twoPi;
    }
    double angleInc = 3/outerR;
    const double cheat = 1/outerR;
    double endAngle = startAngle;
    double centerR = innerR + (outerR-innerR)/2;
    bool first = true;
    while (t < toTime) {
        // compute sky color
        double alt = cachelessPlanetAlt(ECPlanetSun, t, lat, lng);
        if ([self setContextStrokeColor:context forAltitude:alt forceDraw:first]) {
            endAngle += (fabs(alt) < twoPi*9./360 ? angleInc/3 : angleInc*3);
#define CGContextAddClockArc(startAngle, endAngle) CGContextAddArc(context, 0, 0, centerR, halfPi-(startAngle), halfPi-(endAngle), 1)
            CGContextAddClockArc(startAngle-cheat, endAngle+cheat);
            CGContextDrawPath(context, kCGPathStroke);
            startAngle = endAngle;
//		++draw;
        } else {
//		++skip;
            endAngle += (fabs(alt) < twoPi*9./360 ? angleInc/3 : angleInc*3);
        }
        first = false;
        t += 86400*(fabs(alt) < twoPi*9./360 ? angleInc/3 : angleInc*3)/twoPi;
    }
    if (startAngle != endAngle) {
        endAngle += angleInc;
        CGContextAddClockArc(startAngle-cheat, endAngle+cheat);
        CGContextDrawPath(context, kCGPathStroke);
//	    ++draw;
    }
//	tracePrintf2("draw=%d, skip=%d", draw,  skip);
}

- (void)drawConstantValueForDataTime:(NSTimeInterval)dataTime
             timeOffsetForStartAngle:(NSTimeInterval)timeOffsetForStartAngle
                         forTimeSpan:(NSTimeInterval)timeSpan
                  usingTempWatchTime:(ESWatchTime *)tempWatchTime
                             context:(CGContextRef)context
                                 lat:(double)lat
                                 lng:(double)lng {
    //printf("drawConstantValue with reference time "); printADate(dataTime); printf(" offset by %.2f minutes and going for %.2f minutes\n", timeOffsetForStartAngle/60, timeSpan/60);
    NSTimeInterval t = dataTime;
    tempWatchTime->setToFrozenDateInterval(t);
    double startAngle = EC_fmod((tempWatchTime->secondsSinceMidnightValueUsingEnv(env) + timeOffsetForStartAngle) / 3600, 24) * twoPi/24 + pi * [EOClock theClock].noonOnTop;
    if (startAngle > twoPi) {
        startAngle -= twoPi;
    }
    double endAngle = startAngle + (timeSpan)*(M_PI * 2)/(24 * 3600);
    // compute sky color at single point
    double alt = cachelessPlanetAlt(ECPlanetSun, t, lat, lng);
    double centerR = innerR + (outerR-innerR)/2;
    const double cheat = 1/outerR;
    [self setContextStrokeColor:context forAltitude:alt forceDraw:true];
    CGContextAddClockArc(startAngle-cheat, endAngle+cheat);
    CGContextDrawPath(context, kCGPathStroke);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);
    CGContextSetLineWidth(context, outerR-innerR);
    
    if (planet == ECPlanetSun) {
//	traceEnter("sun ring");
//	int draw=0, skip=0;
	double lat = env->location()->latitudeRadians();
	double lng = env->location()->longitudeRadians();
        
        NSTimeInterval now = tim->currentTime();
#ifdef CAPTUREDEFAULTS
        now = 314968600;
        lat = 0;
        lng = -120*twoPi/360;
#endif
        NSTimeInterval base = now - (13 * 3600 + 1);  // Go back 13 hours, in case there's a spring DST transition in the last 12
        NSTimeInterval last = now + (13 * 3600 + 1);  // .. and forward 13 hours in case there's a spring DST in the next 12
        ESWatchTime *tempWatchTime = new ESWatchTime;
        tempWatchTime->setToFrozenDateInterval(base);
        NSTimeInterval nextDST = tempWatchTime->nextDSTChangeUsingEnv(env);
        if (nextDST == 0 || nextDST >= last || nextDST < base) {  // nextDST < base is to work around any calendar bugs
            // No DST, just draw range normally
            [self drawRangeFromTime:(now - (12 * 3600))
                             toTime:(now + (12 *3600))
                 usingTempWatchTime:tempWatchTime
                            context:context lat:lat lng:lng];
        } else {
            NSTimeInterval baseOffset = tempWatchTime->tzOffsetUsingEnv(env);
            tempWatchTime->setToFrozenDateInterval(last);
            NSTimeInterval lastOffset = tempWatchTime->tzOffsetUsingEnv(env);
            NSTimeInterval dstDelta = lastOffset - baseOffset;  // positive delta means spring, negative means autumn
            NSTimeInterval absDelta;
            NSTimeInterval nextDST0;  // The point where the algorithm changes
            if (dstDelta < 0) {
                absDelta = -dstDelta;
                nextDST0 = nextDST - absDelta;  // When we reach 1am in autumn
            } else {
                absDelta = dstDelta;
                nextDST0 = nextDST;
            }
            NSTimeInterval startTime;
            NSTimeInterval endTime;
            if (now < nextDST) {
                startTime = now - (12 * 3600);
                endTime   = now + (12 * 3600 - dstDelta);
            } else {
                startTime = now - (12 * 3600 - dstDelta);
                endTime   = now + (12 * 3600);
            }
            if (startTime > nextDST0) {
                // DST near left edge of range
                startTime = now - (12 * 3600);
                if (dstDelta >= 0 && startTime < nextDST) {  // spring, 2pm-3pm: -11h is after the change, but -12h is before it; if we draw back 12h we'll draw before 2am
                    NSTimeInterval timeRange = nextDST - startTime;
                    startTime = nextDST + .01;  // So draw starting at 3am
                    // And draw portion of gap to cover visible 12hrs back
                    [self drawConstantValueForDataTime:(nextDST + .01)
                               timeOffsetForStartAngle:-timeRange
                                           forTimeSpan:timeRange
                                    usingTempWatchTime:tempWatchTime
                                               context:context lat:lat lng:lng];
                }
                [self drawRangeFromTime:startTime
                                 toTime:endTime
                     usingTempWatchTime:tempWatchTime
                                context:context lat:lat lng:lng];
            } else if (endTime < nextDST) {
                // DST near right end of range
                endTime = now + (12 * 3600);
                if (dstDelta >= 0 && endTime > nextDST) {  // spring, 2pm-3pm: +13h is before the change, but +12h is before it; if we draw forward 12h we'll draw after 3pm
                    NSTimeInterval timeRange = endTime - nextDST;
                    endTime = nextDST - .01;  // So draw ending at 2am
                    // And draw portion of gap to cover visible 12hrs forward
                    [self drawConstantValueForDataTime:(nextDST - .01)
                               timeOffsetForStartAngle:0
                                           forTimeSpan:timeRange
                                    usingTempWatchTime:tempWatchTime
                                               context:context lat:lat lng:lng];
                }
                [self drawRangeFromTime:startTime
                                 toTime:endTime
                     usingTempWatchTime:tempWatchTime
                                context:context lat:lat lng:lng];
            } else { // normal case
                if (dstDelta >= 0) {  // spring
                    // Draw segment from start to DST
                    [self drawRangeFromTime:startTime
                                     toTime:nextDST
                         usingTempWatchTime:tempWatchTime
                                    context:context lat:lat lng:lng];
                    // Draw segment from DST to end (leaving gap, since nextDST + .01 will be 1hr LT after we stopped)
                    [self drawRangeFromTime:(nextDST + .01)
                                     toTime:endTime
                         usingTempWatchTime:tempWatchTime
                                    context:context lat:lat lng:lng];
                    // Fill in gap
                    [self drawConstantValueForDataTime:(nextDST - .01)
                               timeOffsetForStartAngle:0
                                           forTimeSpan:dstDelta
                                    usingTempWatchTime:tempWatchTime
                                               context:context lat:lat lng:lng];
                } else { // dstDelta < 0, autumn
                    // fall back between base and now; need to go back more in UTC
                    if (nextDST < now) {
                        // Draw segment from start to DST - absDelta (skipping first pass through double region, since second is closer to 'now')
                        [self drawRangeFromTime:startTime
                                         toTime:nextDST0
                             usingTempWatchTime:tempWatchTime
                                        context:context lat:lat lng:lng];
                        // Draw second pass through double region and on to the end time
                        [self drawRangeFromTime:(nextDST + .01)
                                         toTime:endTime
                             usingTempWatchTime:tempWatchTime
                                        context:context lat:lat lng:lng];
                    } else {  // DST shift is in the future
                        // Draw segment from start to DST, which includes first pass through double region, since first is closer to 'now'
                        [self drawRangeFromTime:startTime
                                         toTime:nextDST
                             usingTempWatchTime:tempWatchTime
                                        context:context lat:lat lng:lng];
                        // Skip second pass, go on to the end
                        if (nextDST + absDelta + .01 < endTime) {
                            [self drawRangeFromTime:(nextDST + absDelta + .01)
                                             toTime:endTime
                                 usingTempWatchTime:tempWatchTime
                                            context:context lat:lat lng:lng];
                        }
                    }
                }
            }
        }
        delete tempWatchTime;
        tempWatchTime = NULL;

	for (EOScheduledView *twiHand in delegates) {
	    [twiHand update];
	}
//	traceExit("sun ring");
    } else {
#undef NOPLANETS
#ifndef NOPLANETS
        double centerR = innerR + (outerR-innerR)/2;
	astro->setupLocalEnvironmentForThreadFromActionButton(false, [[EOClock theClock] time]);
        bool riseValid;
        bool setValid;
        bool aboveHorizonDuringInvalidRise;
        bool aboveHorizonDuringInvalidSet;
	double riseAngle = astro->planetrise24HourIndicatorAngle(planet, &riseValid/*isRiseSet*/, &aboveHorizonDuringInvalidRise/*aboveHorizon*/) + pi * [EOClock theClock].noonOnTop;
	double setAngle  = astro->planetset24HourIndicatorAngle (planet, &setValid/*isRiseSet*/,  &aboveHorizonDuringInvalidSet/*aboveHorizon*/)  + pi * [EOClock theClock].noonOnTop;
        bool drawLabelOnly = false;
	double transitAngle = astro->planettransit24HourIndicatorAngle(planet) + pi * [EOClock theClock].noonOnTop;
        if (!riseValid || !setValid) {
            bool aboveHorizon;
            if (!riseValid) {
                aboveHorizon = aboveHorizonDuringInvalidRise;
            } else {
                assert(!setValid);
                aboveHorizon = aboveHorizonDuringInvalidSet;
            }
            if (aboveHorizon) {
                // Draw complete loop centered at transit angle
                riseAngle = EC_fmod(transitAngle - M_PI + 0.0001, M_PI * 2);
                setAngle = EC_fmod(transitAngle + M_PI - 0.0001, M_PI * 2);
            } else {
                drawLabelOnly = true;
            }
        }
#ifdef CAPTUREDEFAULTS
	riseAngle=-halfPi;
        setAngle=halfPi;
        transitAngle=0;
#endif
	
	// convert to CGContextAddArc values
	riseAngle = halfPi - riseAngle;
	setAngle  = halfPi - setAngle;
        // Transit angle is now exact, no fudging necessary.
        transitAngle  = halfPi - transitAngle;
	
        if (!drawLabelOnly) {
            // day arc
            [dayColor set];
            CGContextAddArc(context, 0, 0, centerR, riseAngle, setAngle, 1);
            CGContextDrawPath(context, kCGPathStroke);

            // night arc
            if (nightColor != [UIColor clearColor]) {
                [nightColor set];
                CGContextAddArc(context, 0, 0, centerR, setAngle, riseAngle, 1);
                CGContextDrawPath(context, kCGPathStroke);
            }
        }
	astro->cleanupLocalEnvironmentForThreadFromActionButton(false);

	// draw label
	NSString *pName=nil;
	UIColor *diamondColor = nil;
	switch (planet) {
	  case ECPlanetMoon:
	    pName = NSLocalizedString(@"Moon", @"the proper name of Earth's moon");
	    diamondColor = [UIColor colorWithWhite:0.15 alpha:0.5];
	    break;
	  case ECPlanetMercury:
	    pName = NSLocalizedString(@"Mercury", @"the planet Mercury");
	    diamondColor = [UIColor colorWithWhite:0.20 alpha:0.5];
	    break;
	  case ECPlanetVenus:
	    pName = NSLocalizedString(@"Venus", @"the planet Venus");
	    diamondColor = [UIColor colorWithWhite:0.33 alpha:0.5];
	    break;
	  case ECPlanetMars:
	    pName = NSLocalizedString(@"Mars", @"the planet Mars");
	    diamondColor = [UIColor colorWithWhite:0.28 alpha:0.5];
	    break;
	  case ECPlanetJupiter:
	    pName = NSLocalizedString(@"Jupiter", @"the planet Jupiter");
	    diamondColor = [UIColor colorWithWhite:0.33 alpha:0.5];
	    break;
	  case ECPlanetSaturn:
	    pName = NSLocalizedString(@"Saturn", @"the planet Saturn");
	    diamondColor = [UIColor colorWithWhite:0.33 alpha:0.5];
	    break;
	  default:
	    assert(false);
	    diamondColor = [UIColor darkGrayColor];
	    break;
	}
#ifdef CAPTUREDEFAULTS
        pName = @"";
#endif
	[[UIColor clearColor] setFill];
	UIFont *fnt = [UIFont fontWithName:@"Heiti J" size:10];
	if (fnt==nil) {
	    fnt = [UIFont fontWithName:@"Arial" size:10];
	}
        if (drawLabelOnly) {
            [EOClock drawCircularText:pName inRect:rect radius:outerR+2  angle:halfPi-transitAngle    offset:0 withContext:context withFont:fnt color:dayColor demi:true];
        } else {
            [EOClock drawCircularText:pName inRect:rect radius:outerR+2  angle:halfPi-riseAngle    offset:-pi/40 withContext:context withFont:fnt color:[UIColor blackColor] demi:true];
            [EOClock drawCircularText:pName inRect:rect radius:outerR+2  angle:halfPi- setAngle    offset: pi/40 withContext:context withFont:fnt color:[UIColor blackColor] demi:true];

            // draw transit time marker
            double dc = 9.0/20*twoPi/360;	// half-width in radians
            double midR = (outerR+innerR)/2;
            double ct = cos(transitAngle);
            double st = sin(transitAngle);
            CGContextSetLineWidth(context, 0.33);
            [diamondColor setStroke];
            [diamondColor setFill];
            CGContextSetBlendMode(context, kCGBlendModeNormal);
            CGContextMoveToPoint(context, innerR*ct, innerR*st);
            CGContextAddLineToPoint(context, midR*cos(transitAngle-dc), midR*sin(transitAngle-dc));
            CGContextAddLineToPoint(context, outerR*cos(transitAngle), outerR*sin(transitAngle));
            CGContextAddLineToPoint(context, midR*cos(transitAngle+dc), midR*sin(transitAngle+dc));
            CGContextAddLineToPoint(context, innerR*ct, innerR*st);
            CGContextDrawPath(context, kCGPathFillStroke);
        }
#endif  // NOPLANETS
    }
    CGContextRestoreGState(context);
}

- (void)dealloc {
    [delegates release];
    [dayColor release];
    [nightColor release];
    [super dealloc];
}

@end
