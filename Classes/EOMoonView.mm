//
//  EOMoonView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/18/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "EOMoonView.h"
#import "Utilities.h"
#import "EOClock.h"
#import "ESTimeEnvironment.hpp"
#import "ESAstronomy.hpp"
#import <QuartzCore/QuartzCore.h>
#undef ECTRACE
#import "ECTrace.h"

@implementation EOMoonView


- (EOMoonView *)initWithName:(NSString *)fn x:(double)ax y:(double)ay radiusAtPerigee:(double)aRadius update:(double)aUpdate {
    img = [[Utilities imageFromResource:fn] retain];
    assert(img);
    width = img.size.width;
    length = img.size.height;
    ax = ax;
    ay = ay;
    if ((self = [self initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - aRadius,
                                               -ay + [EOClock clockCenter].y - aRadius,
                                               aRadius * 2,
                                               aRadius * 2)
                               kind:EOChandra
                             update:aUpdate
                        strokeColor:nil
                          fillColor:nil])) {
        radiusAtPerigee = aRadius;
    }
    return self;
}

- (void)drawMoonPhaseAt:(double)x y:(double)y radius:(double)radius phaseAngle:(double)pa {  // pa == 0 => new moon; pa == pi/2 => 1st quarter
#ifdef CAPTUREDEFAULTS
    pa=0;
#endif
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    double alph = 0.75 + fabs(sin(pa))/3;	// not completely opaque near new to simulate the earthlight
    [[UIColor colorWithRed:.08 green:.08 blue:.09 alpha:alph] set];
    CGContextSetLineWidth(context, .2);
    
    radius++;
    // start at the south pole
    CGContextMoveToPoint(context, x, y+radius);
    
    // draw a half circle clockwise around to the north pole
    CGContextAddArc(context, x, y, radius, M_PI/2, -M_PI/2, sin(pa) >= 0 ? 0 : 1);
    
    // draw the terminator from north to south in 2n steps
    double n = 10;
    double i;
    for (i = -n; i < n; i++) {
	double th = (M_PI / 2) * (i / n);
	CGContextAddLineToPoint(context, (sin(pa) < 0 ? -1 : 1) * cos(pa) * cos(th) * radius + x, sin(th) * radius + y);
    }
    
    // fill it in
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
    CGContextRestoreGState(context);
}

- (void)drawRect:(CGRect)rect {
    traceEnter("EOMoonView: drawRect");
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    astro->setupLocalEnvironmentForThreadFromActionButton(false, [[EOClock theClock] time]);

    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);

    // calculate apparent size
    const double perigeeDistance = 355000.0;	    // km
    const double au = 149600000.0;		    // km; units of planetGeoCentricDistance
    const double lunarRadius = 1737.10;	    // km
    const double angularRadiusAtPerigee = atan(lunarRadius/perigeeDistance);
    const double angularRadiusNow = atan(lunarRadius/(astro->planetGeocentricDistance(ECPlanetMoon)*au));
    const double pixelRadiusNow = radiusAtPerigee * angularRadiusNow/angularRadiusAtPerigee;
    CGRect nowRect = CGRectMake(-pixelRadiusNow, -pixelRadiusNow,
				pixelRadiusNow * 2, pixelRadiusNow * 2);

    // draw the full moon
    CGContextScaleCTM(context, 1, -1);
    tracePrintf1("EOMoonView: drawInRect start, diameter=%g",pixelRadiusNow*2);
    [img drawInRect:nowRect];
    tracePrintf("EOMoonView: drawInRect done");
    CGContextScaleCTM(context, 1, -1);

    // draw the terminator
    [self drawMoonPhaseAt:0 y:0 radius:pixelRadiusNow phaseAngle:astro->moonAgeAngle()];

    // rotation is now done in EOHandView::update

    // the terminator probably should be rotated separately:
    //printf("%8.4f %8.4f %8.4f\n", [astro moonRelativeAngle]*180/pi, [astro moonRelativePositionAngle]*180/pi, fabs(fmod([astro moonRelativeAngle]-[astro moonRelativePositionAngle],twoPi)*180/pi));
    astro->cleanupLocalEnvironmentForThreadFromActionButton(false);
    CGContextRestoreGState(context);
    traceExit("EOMoonView: drawRect");
}

- (void)dealloc {
    [img release];
    [super dealloc];
}

@end
