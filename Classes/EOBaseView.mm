//
//  EObaseView.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/15/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "EOBaseView.h"
#import "EOClock.h"
#import "Constants.h"
#import "Utilities.h"
#import "ESWatchTime.hpp"


@implementation EOBaseView

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

#undef DEBUGLAYOUT
#ifdef DEBUGLAYOUT
    CGContextSetRGBFillColor(context, .15, .15, .15, 1);
    CGContextFillRect(context, rect);
#else
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
	CGContextSaveGState(context);
    
	// get background (before transforming coordinates)
	unWarped = [EOClock theClock].time->isCorrect();
	UIImage *bgImg = [Utilities imageFromResource:@"background.png"];	// unWarped ? @"background.png" : @"background-warp.png"];
	if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
	    CGFloat width = self.bounds.size.width;
	    CGFloat height = self.bounds.size.height;
	    CGContextTranslateCTM(context, width/2, height/2);
	    CGContextRotateCTM(context, M_PI / 2);
	    CGContextTranslateCTM(context, -height/2, -width/2);
	}
	[bgImg drawAtPoint:CGPointMake(0, 0)];

	CGContextRestoreGState(context);
    } else {
	CGContextSetRGBFillColor(context, 0, 0, 0, 1);
	CGContextFillRect(context, CGRectMake(0, 0, 480, 480));
    }
#endif

    [[EOClock theClock] clockRedraw:context forOrientation:orientation];
}

- (void)setOrientation:(UIInterfaceOrientation)newOrientation {
    orientation = newOrientation;
}

- (void)backgroundCheck {
    if ([EOClock theClock].time->isCorrect() != unWarped) {
//	[self setNeedsDisplay];
    }
}

- (void)dealloc {
    [super dealloc];
}


@end
