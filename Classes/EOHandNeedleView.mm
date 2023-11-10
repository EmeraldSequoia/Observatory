//
//  EOHandNeedleView.mm
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/25/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "EOHandNeedleView.h"
#import "EOHandView.h"
#import <QuartzCore/QuartzCore.h>
#import "EOClock.h"
#import "ESWatchTime.hpp"
#import "ESTimeLocAstroEnvironment.hpp"
#import "ESAstronomy.hpp"
#import "Utilities.h"

#define TAILFRACTION	0.3


@implementation EOHandNeedleView

- (EOHandNeedleView *)initWithKind:(EOHandKind)aKind length:(double)aLength width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor ballRadius:(double)ballRad {
    double w = ((ballRad*2) > aWidth) ? (ballRad*2) : aWidth;
    w = w * 2;		    // I don't understand why this is needed but without it the ball at the end of the hand gets clipped
    ax = ax;
    ay = ay;
    if ((self = [self initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - w/2,
					      -ay + [EOClock clockCenter].y - (aLength+aWidth),
					      w,
					      (aLength+aWidth) * 2)
			      kind:aKind
			    update:aUpdate
		       strokeColor:asColor
			 fillColor:asColor])) {
	length = aLength;
	width = aWidth;
	ballRadius = ballRad;
	angle = halfPi;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context,YES);
    CGContextSetAllowsAntialiasing(context, YES);
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);
    [strokeColor set];

    // arm (long skinny pentagon)
    CGContextSetLineWidth(context, 0.1);
    CGContextMoveToPoint(context, -width/2, 0);
    CGContextAddLineToPoint(context, -width/2, length/2);
    CGContextAddLineToPoint(context, 0, length);
    CGContextAddLineToPoint(context, width/2, length/2);
    CGContextAddLineToPoint(context, width/2, -length*TAILFRACTION+ballRadius);
    CGContextAddLineToPoint(context, -width/2, -length*TAILFRACTION+ballRadius);
    CGContextAddLineToPoint(context, -width/2, 0);
    CGContextDrawPath(context, kCGPathFillStroke);

    // ball on the tail end and center
    if (ballRadius > 0) {
	CGContextAddArc(context, 0, 0, ballRadius/2, 0, twoPi, 0);
	CGContextDrawPath(context, kCGPathFill);
	CGContextSetLineWidth(context, width);
	CGContextAddArc(context, 0, -length*TAILFRACTION, ballRadius, 0, twoPi, 0);
	CGContextDrawPath(context, kCGPathStroke);
    }
    
    CGContextRestoreGState(context);
}


@end
