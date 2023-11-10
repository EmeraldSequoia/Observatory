//
//  EOHandAlarmView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/25/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "EOHandAlarmView.h"
#import "EOHandView.h"
#import "EOClock.h"
#import "OrreryAppDelegate.h"


@implementation EOHandAlarmView


- (EOHandAlarmView *)initWithKind:(EOHandKind)aKind length:(double)aLength length2:(double)aLength2 width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor armStrokeColor:(UIColor *)armsColor arrowLength:(double)aArrowLength tailRadius:(double)aTailRadius {
    double w = (aTailRadius+aWidth*1.5)*2; //((aTailRadius*2) > aWidth) ? (aTailRadius*2) : aWidth;
    ax = ax;
    ay = ay;
    if ((self = [self initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - w/2,
					      -ay + [EOClock clockCenter].y - (aLength+aWidth*1.5),
					      w,
					      (aLength+aWidth*1.5) * 2)
			      kind:aKind
			    update:aUpdate
		       strokeColor:asColor
			 fillColor:afColor])) {
	length = aLength;
	length2 = aLength2;
	width = aWidth;
	angle = halfPi;
	tailRadius = aTailRadius;
	armStrokeColor = [armsColor retain];
	arrowLength = aArrowLength;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context,YES);
    CGContextSetAllowsAntialiasing(context, YES);
    double w = (arrowLength/2 > width) ? arrowLength/2: width;
    w = fmax(w, tailRadius+width*1.5);
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);

    if (fillColor) {
	[fillColor setFill];
    } else {
	[strokeColor setFill];
    }
    
    // outer arm
    [armStrokeColor setStroke];
    CGContextSetLineWidth(context, width);
    CGContextMoveToPoint(context, 0, length2);
    CGContextAddLineToPoint(context, 0, length);
    CGContextDrawPath(context, kCGPathFillStroke);
    
    // end cap
    [strokeColor setStroke];
    if (arrowLength > 0) {
	CGContextMoveToPoint(context,-arrowLength/2/sqrt(3), length-arrowLength);
	CGContextAddLineToPoint(context, 0, length);
    	CGContextAddLineToPoint(context, arrowLength/2/sqrt(3), length-arrowLength);
    } else {
	CGContextAddArc(context, 0, length, width/2, 0, twoPi, 0);
    }
    CGContextDrawPath(context, kCGPathFill);
    
    // center
    CGContextAddArc(context, 0, 0, width, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathFill);
    
    // tail
    CGContextSetLineWidth(context, width*1.5);
    CGContextAddArc(context, 0, length2-tailRadius, tailRadius, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    double fs = tailRadius*1.5;
    [EOClock drawText:@"♬" inRect:CGRectMake(-fs/2,length2-tailRadius-fs/3,fs,fs) withContext:context withFont:[UIFont fontWithName:@"ArialRoundedMTBold" size:fs] color:fillColor?fillColor:strokeColor];

    // inner arm
    [armStrokeColor setStroke];
    CGContextSetLineWidth(context, width);
    CGContextMoveToPoint(context, 0, 333);
    CGContextAddLineToPoint(context, 0, length2-tailRadius*2);
    CGContextDrawPath(context, kCGPathFillStroke);

    CGContextRestoreGState(context);
}

@end
