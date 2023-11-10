//
//  EOEarthView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/22/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "OrreryAppDelegate.h"
#import "EOEarthView.h"
#import "EOHandView.h"
#import "EOClock.h"
#import "Utilities.h"
#include "ESWatchTime.hpp"
#include "ESTimeLocAstroEnvironment.hpp"
#include "ESLocation.hpp"
#undef ECTRACE
#import "ECTrace.h"


@implementation EOEarthView

- (EOEarthView *)initWithX:(double)ax y:(double)ay width:(double)w height:(double)h update:(double)aUpdate {
    width = w;
    length = h;
    if ((self = [self initWithFrame:CGRectMake( ax - width/2,
					      -ay - length/2,
					      width,
					      length)
			      kind:EOTerra
			    update:aUpdate
		       strokeColor:nil
			 fillColor:nil])) {
	monthLoaded = -1;
	self.clearsContextBeforeDrawing = NO;
    }
    return self;
}

// width   200   longitude   w/2=100
// length  100   latidude    h/2=50

#define latToY(l) (length/2 - (l)*length/180.*360/twoPi)
#define lngToX(l) ( width/2 + (l)*width /360.*360/twoPi)
#define YToLat(y) ((  90 - (y)*180./length) * twoPi/360)
#define XToLng(x) ((-180 + (x)*360./width ) * twoPi/360)

- (void)drawBoundaryForAltitude:(double)altitude
		    minAltitude:(double)minAltitude
		    maxAltitude:(double)maxAltitude
			  alpha:(double)alpha
			context:(CGContextRef)context
	      subSolarLongitude:(double)subSolarLongitude
	       subSolarLatitude:(double)subSolarLatitude
		     borderOnly:(bool)borderOnly {

    const double cossslat = cos(subSolarLatitude);
    const double sinsslat = sin(subSolarLatitude);
    bool sunInNorthernHemisphere = (subSolarLatitude > 0);

#define NUM_PARAMETRIC_POINTS 180
    //tracePrintf("find line");
    const double sinAlt = sin(altitude);
    const double cosAlt = cos(altitude);

    double firstX=0;
    double firstY=0;

    double lastX=0;
    double lastY=0;
    int numConstructionLines = 0;

    // Precalculate unvarying quantities:
    double sinBPart = sinsslat*sinAlt;
    double yPart = cosAlt*cossslat;

    tracePrintf("EOEarthView: drawBoundaryFor... loop start");
    for (double i = 0; i <= NUM_PARAMETRIC_POINTS; i++) {
	double psi = i * (M_PI * 2 / NUM_PARAMETRIC_POINTS);
	double xdraw;
	double ydraw;
	if (i == NUM_PARAMETRIC_POINTS) {
	    xdraw = firstX;
	    ydraw = firstY;
	} else {
	    double sinB = sinBPart + yPart*sin(psi);
	    double x = sinAlt - sinsslat*sinB;
	    double B = asin(sinB);
	    double y = yPart*cos(psi);
	    double L = atan2(y, x) + subSolarLongitude; 
	    if (L > M_PI) {
		L -= 2 * M_PI;
	    } else if (L < -M_PI) {
		L += 2 * M_PI;
	    }
	    xdraw = lngToX(L);
	    ydraw = latToY(B);
	}
	if (i == 0) {
	    CGContextMoveToPoint(context, xdraw, ydraw);
	    firstX = xdraw;
	    firstY = ydraw;
	} else {
	    if (fabs(xdraw - lastX) > 5*width/8) {
		numConstructionLines++;
		// We're centered around darkness, so the contour should include the pole that's in winter
		CGFloat yConstructionLine = sunInNorthernHemisphere ? length : 0;
		if (xdraw > lastX) {
		    CGContextAddLineToPoint(context, 0, lastY);
		    CGContextAddLineToPoint(context, 0, yConstructionLine);
		    CGContextAddLineToPoint(context, width, yConstructionLine);
		    CGContextAddLineToPoint(context, width, ydraw);
		} else {
		    CGContextAddLineToPoint(context, width, lastY);
		    CGContextAddLineToPoint(context, width, yConstructionLine);
		    CGContextAddLineToPoint(context, 0, yConstructionLine);
		    CGContextAddLineToPoint(context, 0, ydraw);
		}
		CGContextAddLineToPoint(context, xdraw, ydraw);
	    } else {
		CGContextAddLineToPoint(context, xdraw, ydraw);
	    }
	}
	lastX = xdraw;
	lastY = ydraw;
    }
    tracePrintf("EOEarthView: drawBoundaryFor... loop done");
    // Using even-odd winding rule; if necessary add a rectangle surrounding the whole map to flip the sense of the
    // contour we drew above.  This is only necessary for a closed contour which encloses a day region, which only happens
    // with altitude thresholds greater than zero.  The closed contour is if the numConstructionLines is 0 or 2.
    if (altitude > 0 && numConstructionLines != 1) {
	CGContextAddLineToPoint(context, firstX, firstY);
	CGContextMoveToPoint(context, 0, 0);
	CGContextAddLineToPoint(context, 0, length);
	CGContextAddLineToPoint(context, width, length);
	CGContextAddLineToPoint(context, width, 0);
    }
    if (borderOnly) {
	if (altitude == 0) {
	    CGContextSetRGBStrokeColor(context, 1, 0, 0, 1);	// red
	} else if (altitude > 0) {
	    CGContextSetRGBStrokeColor(context, 0, 1, 0, 1);	// green
	} else {
	    CGContextSetRGBStrokeColor(context, 0, 0, 1, 1);	// blue
	}
	CGContextDrawPath(context, kCGPathStroke);
    } else {
	CGContextSetRGBFillColor(context, 0, 0, 0, alpha);
	tracePrintf("EOEarthView: drawBoundaryFor... drawPath start");
	CGContextDrawPath(context, kCGPathEOFill);
	tracePrintf("EOEarthView: drawBoundaryFor... drawPath done");
    }
}

- (void)drawBoundariesForAltitudeIntoContext:(CGContextRef)context
				 minAltitude:(double)minAltitude
				 maxAltitude:(double)maxAltitude
			       numBoundaries:(int)numBoundaries
			   subSolarLongitude:(double)subSolarLongitude
			    subSolarLatitude:(double)subSolarLatitude 
				  borderOnly:(bool)borderOnly {
    traceEnter("EOEarthView: drawBoundaries");
    assert(numBoundaries > 0);
    if (numBoundaries == 1) {
	assert(minAltitude == maxAltitude);
	[self drawBoundaryForAltitude:minAltitude minAltitude:minAltitude maxAltitude:maxAltitude alpha:0.5 context:context subSolarLongitude:subSolarLongitude subSolarLatitude:subSolarLatitude borderOnly:borderOnly];
    }
    double altitudeIncrement = (maxAltitude - minAltitude) / (numBoundaries - 1);
    // draw maximum altitude first, because it has the biggest area (the shape surrounds the night region)
    double alphaIncrement = 1.0 / (numBoundaries);
    double alpha = alphaIncrement;  // don't start at alpha=0; drawing with alpha=0 doesn't do anything
    if (!borderOnly) {
	CGContextSetBlendMode(context, kCGBlendModeDestinationOut);
    }
    for(double altitude = maxAltitude; altitude >= minAltitude - .0001; altitude -= altitudeIncrement, alpha += alphaIncrement) {
	[self drawBoundaryForAltitude:altitude minAltitude:minAltitude maxAltitude:maxAltitude alpha:alpha context:context subSolarLongitude:subSolarLongitude subSolarLatitude:subSolarLatitude borderOnly:borderOnly];
    }
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    traceExit("EOEarthView: drawBoundaries");
}
    
- (void)drawRect:(CGRect)rect {
    traceEnter("EOEarthView: drawRect");
    //printf("    EOEarthView frame  %6.2f, %6.2f   %6.2f x %6.2f\n", self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
    //printf("    EOEarthView bounds %6.2f, %6.2f   %6.2f x %6.2f\n", self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);

    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);

    // get the image for this month
    int thisMonth = tim->monthNumberUsingEnv(env);
    if (monthLoaded != thisMonth) {
	//tracePrintf1("loading earth image for %d\n", thisMonth+1);
	[img release];
	img = [[Utilities imageFromResource:[NSString stringWithFormat:@"%02d.png", thisMonth+1]] retain];
	assert(img);
	assert(img.size.width == width && img.size.height == length);
	monthLoaded = thisMonth;
    }

    CGContextScaleCTM(context, 1, -1);
    tracePrintf("EOEarthView: drawInRect start");
    [img drawInRect:CGRectMake(-width/2,-length/2,width,length)];
    tracePrintf("EOEarthView: drawInRect done");
    //tracePrintf("draw img");
    CGContextTranslateCTM(context, -width/2, -length/2);

#ifndef CAPTUREDEFAULTS
    NSTimeInterval t = tim->currentTime();

    // compute subsolar point
    NSTimeInterval solar = tim->secondsSinceMidnightValueUsingEnv(env) - tim->tzOffsetUsingEnv(env) + EOTSecondsForDateInterval(t);
    double sslng = (180 - solar/3600*15);
    if (sslng < -180) {
	sslng += 360;
    }
    sslng *= twoPi/360;
    const double sslat = cachelessSunDecl(t);

#define TWILIGHT_ALT (-18.*M_PI/180.)		// start/end of nautical twilight

#undef PER_PIXEL_METHOD
#ifdef PER_PIXEL_METHOD
    // calculate day/night coloring by the distance from each point to the sub solar point for this time (with optimized drawing)
    const double cossslat = cos(sslat);
    const double sinsslat = sin(sslat);
    const double pixel = 1;
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextSetShouldAntialias(context, false);
    for (int x = 0; x < width; x += pixel) {
	for (int y = 0; y < length; y += pixel) {
	    const double lat = YToLat(y);
	    const double cosdist = sinsslat*sin(lat) + cossslat*cos(lat)*cos(XToLng(x)-sslng);
	    if (cosdist < -ALT_RANGE) {
		CGContextFillRect(context, CGRectMake(x, y, pixel, pixel));
	    } else if (cosdist < ALT_RANGE) {
		CGContextSetRGBFillColor(context, 0, 0, 0, .5- (cosdist)/ALT_RANGE*.5);
		CGContextSetBlendMode(context, kCGBlendModeDestinationOut);
		CGContextFillRect(context, CGRectMake(x, y, pixel, pixel));
		CGContextSetRGBFillColor(context, 0, 0, 0, .5);
		CGContextSetBlendMode(context, kCGBlendModeClear);
	    } else {
		// leave it alone
	    }
	}
    }
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextSetShouldAntialias(context, true);
#else  // not PER_PIXEL_METHOD
    [self drawBoundariesForAltitudeIntoContext:context minAltitude:TWILIGHT_ALT maxAltitude:0 numBoundaries:4 subSolarLongitude:sslng subSolarLatitude:sslat borderOnly:false];
#endif

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EOShowSubsolarPoint"]) {
	// draw the subsolar point
	CGContextSetLineWidth(context, 1);
	CGContextSetRGBStrokeColor(context, 1, 1, 0, 1);	// yellow
	CGContextAddArc(context, lngToX(sslng), latToY(sslat), 3, 0, twoPi, 0);
	CGContextDrawPath(context, kCGPathStroke);
	//printf("subsolar latitude = %+5.1f;   longitude = %+6.1f   [%.0f,%.0f]\n", sslat*360/twoPi, sslng*360/twoPi, lngToX(sslng), latToY(sslat));
	
    }
    
    // draw current location
    ESLocation *location = env->location();
    CGContextSetLineWidth(context, 1);
    CGContextSetRGBStrokeColor(context, 1, 0, 0, 1);	// red
    CGContextAddArc(context, lngToX(location->longitudeRadians()), latToY(location->latitudeRadians()), 1, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    // printf("env latitude = %+5.1f;   longitude = %+6.1f   [%.0f,%.0f]\n", env.latitude*360/twoPi, env.longitude*360/twoPi, lngToX(env.longitude), latToY(env.latitude));

    CGContextRestoreGState(context);
#endif
    traceExit("EOEarthView: drawRect");
}

- (void)dealloc {
    [img release];
    [super dealloc];
}

@end
