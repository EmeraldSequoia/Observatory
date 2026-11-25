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
#import "EOSaturnRenderer.hpp"
#include "ESAstronomy.hpp"

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

// Saturn's rings are drawn as a telescope shows them on the current date (see EOSaturnRenderer).
// saturn.png still sets the size and stands in until the geometry is known.  Redraw when the
// geometry has moved by more than this (radians); the tilt changes by at most ~0.1 degree a day.
static const double ringRedrawThreshold = 0.0002;

- (void)update {
    [super update];
    if (kind != EOSaturn) {
        return;
    }
    double earthTilt, sunTilt, deltaU;
    astro->setupLocalEnvironmentForThreadFromActionButton(false, [[EOClock theClock] time]);
    astro->saturnRingGeometry(&earthTilt, &sunTilt, &deltaU);
    astro->cleanupLocalEnvironmentForThreadFromActionButton(false);
    if (isnan(earthTilt) || isnan(sunTilt) || isnan(deltaU)) {
        return;
    }
    if (!ringGeometryValid ||
        fabs(earthTilt - ringEarthTilt) > ringRedrawThreshold ||
        fabs(sunTilt - ringSunTilt) > ringRedrawThreshold ||
        fabs(remainder(deltaU - ringDeltaU, 2 * M_PI)) > ringRedrawThreshold * 10) {
        ringEarthTilt = earthTilt;
        ringSunTilt = sunTilt;
        ringDeltaU = deltaU;
        ringGeometryValid = true;
        [self setNeedsDisplay];
    }
}

// Saturn at the current ring geometry, at the view's pixel resolution; the caller releases it
- (CGImageRef)newSaturnImage {
    double scale = masterScale * self.contentScaleFactor;
    int pixelWidth = (int)ceil(width * scale);
    int pixelHeight = (int)ceil(length * scale);
    if (pixelWidth <= 0 || pixelHeight <= 0) {
        return NULL;
    }
    size_t bytes = (size_t)pixelWidth * pixelHeight * 4;
    uint8_t *pixels = (uint8_t *)malloc(bytes);
    if (!pixels) {
        return NULL;
    }
    // A hair of margin so the ring tips are not clipped
    EOSaturnRender(ringEarthTilt, ringSunTilt, ringDeltaU, pixelWidth, pixelHeight,
                   pixelWidth / (2 * EOSaturnRingOuterRadius * 1.01), pixels);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(pixels, pixelWidth, pixelHeight, 8, pixelWidth * 4, colorSpace,
                                                kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
    return image;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);

    CGRect where = CGRectMake(-width/2, radius-length/2, width, length);
    CGImageRef saturn = (kind == EOSaturn && ringGeometryValid) ? [self newSaturnImage] : NULL;
    if (saturn) {
        // CGContextDrawImage in this y-up space puts the rendering's top (Saturn's north) outward,
        // away from the Sun; UIImage drawing would turn it over and show the wrong face of the rings
        CGContextDrawImage(context, where, saturn);
        CGImageRelease(saturn);
    } else {
        [img drawInRect:where];
    }

    CGContextRestoreGState(context);
}

- (void)dealloc {
    [img release];
    [super dealloc];
}

@end
