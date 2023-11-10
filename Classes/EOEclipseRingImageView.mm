//
//  EOEclipseRingImageView.m
//  Emerald Orrery
//
//  Created by Steve Pucci on 27 Nov 2010
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "EOEclipseRingImageView.h"
#import "EOClock.h"
#import "Utilities.h"

@implementation EOEclipseRingImageView

@synthesize radius;

- (EOEclipseRingImageView *)initWithKind:(EOHandKind)aKind name:(NSString *)fn radius:(double)aRadius x:(double)ax y:(double)ay update:(double)aUpdate {
    img = [[Utilities imageFromResource:fn] retain];
    assert(img);
    width = img.size.width;
    length = img.size.height;
    if (aKind != EOMoon) {
	ax = ax;
	ay = ay;
    }
    if ((self = [self initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - width/2,
					      -ay + [EOClock clockCenter].y - length/2,
					       width,
					       length)
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
    
    [img drawInRect:CGRectMake(-width/2, -length/2, width, length)];

    CGContextRestoreGState(context);
}

- (void)dealloc {
    [img release];
    [super dealloc];
}

@end
