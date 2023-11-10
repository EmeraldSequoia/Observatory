//
//  EORingView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/17/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Constants.h"
#import "EOScheduledView.h"


class ESWatchTime;
class ESTimeLocAstroEnvironment;
class ESAstronomyManager;

@interface EORingView : EOScheduledView {
    ECPlanetNumber	planet;
    double		outerR, innerR;
    UIColor		*dayColor;
    UIColor		*nightColor;
    ESWatchTime		*tim;
    ESTimeLocAstroEnvironment *env;
    ESAstronomyManager  *astro;
    NSMutableArray	*delegates;
}

- (EORingView *)initWithPlanet:(ECPlanetNumber)planet outerRadius:(double)oR innerRadius:(double)iR x:(double)x y:(double)y update:(double)update dayColor:(UIColor *)dayColor nightColor:(UIColor *)nightColor;
- (void)addDelegate:(EOScheduledView *)twiHand;

@end
