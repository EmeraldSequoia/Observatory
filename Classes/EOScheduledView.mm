//
//  EOScheduledView.m
//  Orrery
//
//  Created by Bill Arnett on 3/22/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "EOScheduledView.h"
#import "EOClock.h"
#import "ESWatchTime.hpp"

#import <QuartzCore/QuartzCore.h>

void roundOutFrameToIntegralBoundaries(const CGRect *requestedFrame,
                                       double       requestedMasterScale,
                                       CGRect       *roundedOutFrame,
                                       CGPoint      *zeroOffset) {
    //assert(requestedMasterScale == 1.0);
    double requestedWidth = requestedFrame->size.width;
    double requestedHeight = requestedFrame->size.height;

    CGPoint zeroPointInFrameCoordinates;
    zeroPointInFrameCoordinates.x = requestedFrame->origin.x + requestedWidth / 2;
    zeroPointInFrameCoordinates.y = requestedFrame->origin.y + requestedHeight / 2;
    //assert(fabs(round(2*zeroPointInFrameCoordinates.x) - 2*zeroPointInFrameCoordinates.x) < 0.001);
    //assert(fabs(round(2*zeroPointInFrameCoordinates.y) - 2*zeroPointInFrameCoordinates.y) < 0.001);

    double scaledRequestedWidth = requestedWidth * requestedMasterScale;
    double scaledRequestedHeight = requestedHeight * requestedMasterScale;

    roundedOutFrame->origin.x = floorf(zeroPointInFrameCoordinates.x - scaledRequestedWidth / 2);
    roundedOutFrame->origin.y = floorf(zeroPointInFrameCoordinates.y - scaledRequestedHeight / 2);
    roundedOutFrame->size.width = ceilf(zeroPointInFrameCoordinates.x + scaledRequestedWidth / 2) - roundedOutFrame->origin.x;
    roundedOutFrame->size.height = ceilf(zeroPointInFrameCoordinates.y + scaledRequestedHeight / 2) - roundedOutFrame->origin.y;

    zeroOffset->x = zeroPointInFrameCoordinates.x - roundedOutFrame->origin.x;
    zeroOffset->y = zeroPointInFrameCoordinates.y - roundedOutFrame->origin.y;
}
                               
void setupContextForZeroOffsetAndScale(CGContextRef  context,
                                       const CGPoint *zeroOffset,
                                       double        scale) {
    CGContextTranslateCTM(context, zeroOffset->x, zeroOffset->y);
    CGContextScaleCTM(context, scale, -scale);
}

@implementation EOScheduledView

@synthesize orientation, masterScale, requestedFrame, zeroOffset;

static double offsetter = 29.5;

- (EOScheduledView *)initWithFrame:(CGRect)frame update:(double)aUpdate {
    CGRect roundedFrame;
    CGPoint aZeroOffset;
    roundOutFrameToIntegralBoundaries(&frame, 1.0/*masterScale*/, &roundedFrame, &aZeroOffset);
    if ((self = [super initWithFrame:roundedFrame])) {
        update = aUpdate;
	if (update > 20) {
	    updateOffset = offsetter;
	    offsetter += 7;
	} else {
	    updateOffset = 0;
	}
	masterScale = 1.0;
        requestedFrame = frame;
        zeroOffset = aZeroOffset;
	self.autoresizesSubviews = NO;
	[self resetTarget];
    }
    return self;
}

- (void)tick:(bool)forceIt {
    NSTimeInterval now = [EOClock theClock].time->currentTime();
    if (forceIt || now > target) {
	target = floor((now+update) / update) * update + updateOffset;
	[self update];
    }
}

- (void)zeroAngle {
    // do nothing; EOHandView overrides
}

- (void)resetTarget {
    NSTimeInterval now = [EOClock theClock].time->currentTime();
    target = floor(now / update) * update;
}

- (void)update {
    assert(false);	    // subclasses override
}

- (void)dealloc {
    [super dealloc];
}


@end
