//
//  EOHandTriangleView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/17/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "EOHandTriangleView.h"
#import "EOHandView.h"
#import "EOClock.h"

@implementation EOHandTriangleView

#define TAILFRACTION	0.21

- (EOHandTriangleView *)initWithKind:(EOHandKind)aKind length:(double)aLength width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor {
    double sz = fmax(aLength,aWidth);
    ax = ax;
    ay = ay;
    if ((self = [self initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - sz,
					      -ay + [EOClock clockCenter].y - sz,
					      sz * 2,
					      sz * 2)
			      kind:aKind
			    update:aUpdate
		       strokeColor:asColor
			 fillColor:afColor])) {
	length = aLength;
	width = aWidth;
	angle = 0;
	centerRadius = 0;
	ballRadius = 0;
   }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);

    double cgAngle = angle-halfPi;
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);
    CGContextScaleCTM(context, 1, -1);

    [strokeColor setStroke];
    if (fillColor) {
	[fillColor setFill];
    } else {
	[strokeColor setFill];
    }
    
    // arm
    CGContextSetLineWidth(context, width/10);
    CGContextMoveToPoint(context, width/2*cos(cgAngle-halfPi), width/2*sin(cgAngle-halfPi));
    CGContextAddLineToPoint(context, length*cos(cgAngle), length*sin(cgAngle));
    CGContextAddLineToPoint(context, width/2*cos(cgAngle+halfPi), width/2*sin(cgAngle+halfPi));
    // tail
    CGContextAddLineToPoint(context, length*TAILFRACTION*cos(cgAngle+pi), length*TAILFRACTION*sin(cgAngle+pi));
    CGContextAddLineToPoint(context, width/2*cos(cgAngle-halfPi), width/2*sin(cgAngle-halfPi));
    CGContextDrawPath(context, kCGPathFillStroke);

    CGContextRestoreGState(context);
}

@end
