//
//  EOImageHandView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/18/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "EOHandImageView.h"
#import "EOHandView.h"
#import "EOClock.h"
#import "Utilities.h"

@implementation EOHandImageView


- (EOHandImageView *)initWithKind:(EOHandKind)aKind name:(NSString *)fn x:(double)ax y:(double)ay radius:(double)aRadius update:(double)aUpdate {
    img = [[Utilities imageFromResource:fn] retain];
    assert(img);
    width = img.size.width;
    length = img.size.height;
    if (aKind != EOMoon) {
	ax = ax;
	ay = ay;
    }
    if ((self = [self initWithFrame:CGRectMake( ax + (aKind == EOMoon ? 0 : [EOClock clockCenter].x) - width/2,
					      -ay + (aKind == EOMoon ? 0 : [EOClock clockCenter].y) - (aRadius + length/2),
					      width,
					      (aRadius + length/2) * 2)
			      kind:aKind
			    update:aUpdate
		       strokeColor:nil
			 fillColor:nil])) {
	radius = aRadius;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);

    [img drawInRect:CGRectMake(-width/2, radius-length/2, width, length)];

    CGContextRestoreGState(context);
}

- (void)dealloc {
    [img release];
    [super dealloc];
}

@end
