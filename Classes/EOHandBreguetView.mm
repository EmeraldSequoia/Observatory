//
//  EOHandBreguetView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/25/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "EOHandBreguetView.h"
#import "EOHandView.h"
#import "EOClock.h"


@implementation EOHandBreguetView


- (EOHandBreguetView *)initWithKind:(EOHandKind)aKind length:(double)aLength width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor centerRadius:(double)centerRad {
    double w = ((centerRad*2) > aWidth) ? (centerRad*2) : aWidth;
    ax = ax;
    ay = ay;
    if ((self = [self initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - w/2,
					      -ay + [EOClock clockCenter].y - aLength,
					      w,
					      aLength * 2)
			      kind:aKind
			    update:aUpdate
		       strokeColor:asColor
			 fillColor:afColor])) {
	length = aLength;
	width = aWidth;
	angle = halfPi;
	centerRadius = centerRad;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context,YES);
    CGContextSetAllowsAntialiasing(context, YES);
    // Breguet style pomme hand
    double lineWidth	  = 0.1;
    double widthScaler	  = width / (length * 0.16);
    double lengthScaler	  = (length-81)/10;
    double armWidth       = length * 0.04  * widthScaler;
    double breOuterCenter = length * 0.71  + lengthScaler;
    double breInnerCenter = length * 0.725 + lengthScaler * 0.88;
    double breOuterRadius = length * 0.075 * widthScaler;
    double breInnerRadius = length * 0.05  * widthScaler;
    double breBase	  = breInnerCenter - breInnerRadius;
    double tipBase	  = breOuterCenter + breOuterRadius - 1;
    double tipWidth	  = length * 0.045 * widthScaler;
    CGContextSetLineWidth(context, lineWidth);
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);

    [strokeColor setStroke];
    if (fillColor) {
	[fillColor setFill];
    } else {
	[strokeColor setFill];
    }
    
    // filled circle at the hub
    CGContextAddArc(context, 0, 0, centerRadius, 0, 2*M_PI, 1);
    CGContextDrawPath(context,  kCGPathFillStroke);
    // inner arm trapezoid
    CGContextMoveToPoint(context, -armWidth/2, centerRadius);
    CGContextAddLineToPoint(context, -armWidth/5, breBase);
    CGContextAddLineToPoint(context,  armWidth/5, breBase);
    CGContextAddLineToPoint(context, armWidth/2, centerRadius);
    CGContextDrawPath(context,  kCGPathFillStroke);
    // Breguet thingie:  filled circle with an offset circle removed
    CGContextAddArc(context, 0, breOuterCenter, breOuterRadius, 0, 2*M_PI, 1);
    CGContextMoveToPoint(context, breInnerRadius, breInnerCenter);
    CGContextAddArc(context, 0, breInnerCenter, breInnerRadius, -2*M_PI, 0, 0);
    CGContextDrawPath(context,  kCGPathFillStroke);
    // fatter triangle at the end
    CGContextMoveToPoint(context, -tipWidth/2, tipBase);
    CGContextAddLineToPoint(context, 0, length);
    CGContextAddLineToPoint(context, tipWidth/2, tipBase);
    CGContextDrawPath(context,  kCGPathFillStroke);

    CGContextRestoreGState(context);
}

@end
