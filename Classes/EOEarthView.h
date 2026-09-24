//
//  EOEarthView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/22/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"

class ESWatchTime;
class ESTimeLocAstroEnvironment;

// Draws the Earth map (the month's image, day/night shading, and the red dot at the current location) into the
// rectangle (0, 0, width, length) of a y-down context.  markScale scales the dots' size and line width.
extern void EODrawEarthMap(CGContextRef context, UIImage *img, double width, double length, double markScale,
			   ESWatchTime *tim, ESTimeLocAstroEnvironment *env);


@interface EOEarthView : EOHandView {
    UIImage	    *img;
    int		    monthLoaded;
}

- (EOEarthView *)initWithX:(double)ax y:(double)ay width:(double)w height:(double)h update:(double)aUpdate;
- (CGRect)mapRect;  // where the map is drawn, in this view's coordinates

@end
