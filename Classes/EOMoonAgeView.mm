//
//  EOMoonAgeView.m
//  Emerald Orrery
//
//  Created by Steve Pucci on 4 Dec 2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "EOMoonAgeView.h"
#import "EOClock.h"
#import "Utilities.h"
#import "ESWatchTime.hpp"

@implementation EOMoonAgeView

- (EOMoonAgeView *)initWithOuterRadius:(double)anOuterRadius
			   innerRadius:(double)anInnerRadius
				     x:(double)ax
				     y:(double)ay
				update:(double)aUpdate {
    [super initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - anOuterRadius,
				    -ay + [EOClock clockCenter].y - anOuterRadius,
				     anOuterRadius * 2,
				     anOuterRadius * 2)
		    kind:EOEclipse
		  update:aUpdate
	     strokeColor:nil
	       fillColor:nil];
    innerRadius = anInnerRadius;
    outerRadius = anOuterRadius;
    return self;
}

// We want the value in a different cycle, where the value in some arbitrary cycle is 'value' and the
// approximate value we want is approximateValueInCycle.  Useful for not losing track of accumulated
// angles when crossing a cycle boundary.  The approximate value needs to be no further than PI from
// the actual value.
static double refineInCycle(double value,
			    double approximateValueInCycle) {
    //EC_printAngle(value, "inputValue");
    //EC_printAngle(approximateValueInCycle, "approximateValueInCycle");
    while (value - approximateValueInCycle > M_PI) {
	value -= 2 * M_PI;
    }
    while (value - approximateValueInCycle < -M_PI) {
	value += 2 * M_PI;
    }
    //EC_printAngle(value, "outputValue");
    return value;
}

// Draw the visible portion of the infinite spiral of Moon Age, where
//    - the radius of the spiral at the current Moon position is always (outer+inner)/2
//    - the delta radius for a given angle ahead (or behind) of the current Moon is a constant times the angle ahead (or behind)
- (void)drawRect:(CGRect)rect {
    //[TSTime noteTimeAtPhase:"-[EOMoonAgeView drawRect] start"];
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    astro->setupLocalEnvironmentForThreadFromActionButton(false, [[EOClock theClock] time]);

    const double spiralRatio = 1.2 /*0.8*/;   // one cycle results in this much change in radius (in units of outer-inner).
    const double deltaAngleSpan = M_PI / spiralRatio;   // We can see this much of the spiral forward and back

    const NSTimeInterval now = [[EOClock theClock] time]->currentTime();
    //printf("'now' is %s\n", [[[NSDate dateWithTimeIntervalSinceReferenceDate:now] description] UTF8String]);
    double moonPositionNow = astro->planetRA(ECPlanetMoon, false/*correctForParallax*/);
    NSTimeInterval prevNewMoonTime = now;
    double deltaAngle = 0;

    // Go find the first New Moon that's *out* of range backwards
    do {
	prevNewMoonTime = astro->nextQuarterAngle(0, prevNewMoonTime/*fromTime*/, false/*nextNotPrev*/);
	//printf("prevNewMoon calc as %s\n", [[[NSDate dateWithTimeIntervalSinceReferenceDate:prevNewMoonTime] description] UTF8String]);
	double moonPositionAtNewMoon = astro->planetRA(ECPlanetMoon, prevNewMoonTime/*atTime*/, false/*correctForParallax*/);
	deltaAngle = refineInCycle(moonPositionAtNewMoon - moonPositionNow, (prevNewMoonTime - now) * (2 * M_PI / (29.5 * 24 * 3600)));
    } while (-deltaAngle < deltaAngleSpan);

    // Determine next New Moon
    double nextNewMoonTime = astro->nextQuarterAngle(0, prevNewMoonTime/*fromTime*/, true/*nextNotPrev*/);

    float w = self.bounds.size.width;
    float h = self.bounds.size.height;
    assert(w == h);
    CGContextTranslateCTM(context, w/2, h/2);

    // Now walk forward from New Moon by days, noting data for each one
    int ageInDays = 0;
    bool firstTime = true;
#define MAX_POINTS 60    
    struct PointData {
	float radiusFraction;
	float radius;
	double moonPosition;
	int ageInDays;
    } data[MAX_POINTS];
    int i = 0;
    while (1) {
	ageInDays++;
	NSTimeInterval t = prevNewMoonTime + ageInDays*24*3600;
	if (t > nextNewMoonTime) {
	    prevNewMoonTime = nextNewMoonTime;
	    t = nextNewMoonTime;
	    ageInDays = 0;
	    nextNewMoonTime = astro->nextQuarterAngle(0, nextNewMoonTime/*fromTime*/, true/*nextNotPrev*/);
	    //printf("nextNewMoonTime recalculated to %s\n", [[[NSDate dateWithTimeIntervalSinceReferenceDate:nextNewMoonTime] description] UTF8String]);
	}
	data[i].moonPosition = astro->planetRA(ECPlanetMoon, t/*atTime*/, false/*correctForParallax*/);
	deltaAngle = refineInCycle(data[i].moonPosition - moonPositionNow, (t - now) * (2 * M_PI / (29.5 * 24 * 3600)));
	if (deltaAngle < -deltaAngleSpan) {
	    continue;
	}
	if (deltaAngle > deltaAngleSpan) {
	    break;
	}
	//EC_printAngle(data[i].moonPosition, [[NSString stringWithFormat:@"Moon age: %02d days at %@", ageInDays, [[NSDate dateWithTimeIntervalSinceReferenceDate:t] description]] UTF8String]);
#define SPIRAL
#ifdef SPIRAL
	data[i].radiusFraction = (deltaAngle + deltaAngleSpan)/(2 * deltaAngleSpan);
#else
	data[i].radiusFraction = 0.99;
#endif
	data[i].radius = innerRadius + data[i].radiusFraction*(outerRadius - innerRadius);
	double x = data[i].radius * sin(data[i].moonPosition);
	double y = data[i].radius * -cos(data[i].moonPosition);
	data[i].ageInDays = ageInDays;
	if (firstTime) {
	    CGContextMoveToPoint(context, x, y);
	} else {
	    CGContextAddLineToPoint(context, x, y);
	}
	firstTime = false;
	i++;
	if (i >= MAX_POINTS) {
	    assert(false);
	    break;
	}
    }
    UIFont *font = [UIFont fontWithName:@"Arial" size:8];
    if (i <= MAX_POINTS) {
	int numPoints = i;
	// First draw spiral baseline
	[[UIColor colorWithRed:1 green:1 blue:1 alpha:1.0] setFill];
	[[UIColor colorWithRed:1 green:1 blue:1 alpha:1.0] setStroke];
	CGContextSetLineWidth(context, 0.25);
	CGContextStrokePath(context);

	for (i = 0; i < numPoints; i++) {
	    struct PointData *pd = &data[i];
	    float lineLength;
	    if (pd->ageInDays == 0) {
		CGContextSetLineWidth(context, 1.0);
		lineLength = 7;
	    } else if ((pd->ageInDays % 5) == 0) {
		CGContextSetLineWidth(context, 1.0);
		lineLength = 5;
	    } else {
		CGContextSetLineWidth(context, 1.0);
		lineLength = 2;
	    }
	    double startRadius, endRadius;
	    if (pd->radiusFraction < 0.2) {  // close to inner edge -- draw line out from spiral
		startRadius = pd->radius;
		endRadius = startRadius + lineLength;
	    } else if (pd->radiusFraction > 0.8) {  // close to outer edge -- draw line in from spiral
		startRadius = pd->radius;
		endRadius = startRadius - lineLength;
	    } else { // in the middle -- draw line in middle
		startRadius = pd->radius - lineLength/2;
		endRadius = pd->radius + lineLength/2;
	    }
	    double sinAngle = sin(pd->moonPosition);
	    double cosAngle = cos(pd->moonPosition);
	    CGContextMoveToPoint(context, startRadius*sinAngle, -startRadius*cosAngle);
	    CGContextAddLineToPoint(context, endRadius*sinAngle, -endRadius*cosAngle);
	    CGContextStrokePath(context);
	    if ((pd->ageInDays % 5) == 0) {
		CGContextSaveGState(context);
		double textRadius;
		double modPos = EC_fmod(pd->moonPosition, M_PI * 2);
		bool lowerHalfOfDial = modPos > M_PI / 2 && modPos < 3 * M_PI / 2;
		if (pd->radiusFraction > 0.5) {  // closer to outer edge, put text on inside
		    textRadius = innerRadius + (lowerHalfOfDial ? 5 : 3);
		} else {
		    textRadius = outerRadius - (lowerHalfOfDial ? 3 : 5);
		}
		CGContextTranslateCTM(context, textRadius*sinAngle, -textRadius*cosAngle);
		if (lowerHalfOfDial) {
		    CGContextRotateCTM(context, M_PI + pd->moonPosition);
		} else {
		    CGContextRotateCTM(context, pd->moonPosition);
		}
		NSString *text = [NSString stringWithFormat:@"%d", pd->ageInDays];
		// Deprecated iOS 7:  CGSize sz = [text sizeWithFont:font];
                CGSize sz = [text sizeWithAttributes:@{NSFontAttributeName:font}];
		// Deprecated iOS 7:  [text drawInRect:CGRectMake(-sz.width/2, -sz.height/2, sz.width, sz.height) withFont:font];
                if (text) {
                    [text drawInRect:CGRectMake(-sz.width/2, -sz.height/2, sz.width, sz.height) withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:[UIColor whiteColor]}];
                }
		CGContextRestoreGState(context);
	    }
	}
    }
    //[TSTime noteTimeAtPhase:"-[EOMoonAgeView drawRect] finish"];
    astro->cleanupLocalEnvironmentForThreadFromActionButton(false);
    CGContextRestoreGState(context);
}

@end
