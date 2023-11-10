//
//  EOScheduledView.h
//  Orrery
//
//  Created by Bill Arnett on 3/22/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface EOScheduledView : UIView {
    double		    update;
    double		    updateOffset;
    double		    target;		// update at this time
    UIInterfaceOrientation  orientation;
    double                  masterScale;     // The change in scale for this view after orientation change
    CGRect                  requestedFrame;  // The frame we ask for prior to masterScale, with the zero point exactly at the center
    CGPoint                 zeroOffset;      // The offset of zero (the "center" of the view, which may be offset by fractional pixels from the actual center)
}

@property (readwrite, assign) UIInterfaceOrientation orientation;
@property (nonatomic) double masterScale;
@property (nonatomic) CGRect requestedFrame;
@property (nonatomic) CGPoint zeroOffset;

- (id)initWithFrame:(CGRect)frame update:(double)update;
- (void)tick:(bool)forceIt;
- (void)update;	    // subclasses must override
- (void)zeroAngle;
- (void)resetTarget;
- (void)setOrientation:(UIInterfaceOrientation)newOrientation;

@end

extern void roundOutFrameToIntegralBoundaries(const CGRect *requestedFrame,
                                              double       requestedMasterScale,
                                              CGRect       *roundedOutFrame,
                                              CGPoint      *zeroOffset);
extern void setupContextForZeroOffsetAndScale(CGContextRef  context,
                                              const CGPoint *zeroOffset,
                                              double        scale);
