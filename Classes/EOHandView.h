//
//  EOHandView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/16/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EOScheduledView.h"

#import "ESAstronomy.hpp"

class ESWatchTime;
class ESTimeLocAstroEnvironment;
class ESAstronomyManager;

typedef enum EOHandKind {
    EO60RPM,
    EOSeconds,
    EOMinutes,
    EO12Hours,
    EO24Hours,
    EOUTCMinutes,
    EOUTCHours,
    EOWeekdays,
    EOMonths,
    EODays,
    EOAlarms,
    EONorth,
    EOFirstAstro,
    EOSunrise = EOFirstAstro,
    EOSunset,
    EOGoldenHourBegin,
    EOCivilTwilightEnd,
    EONauticalTwilightEnd,
    EOAstronomicalTwilightEnd,
    EOGoldenHourEnd,
    EOCivilTwilightBegin,
    EONauticalTwilightBegin,
    EOAstronomicalTwilightBegin,
    EOSolarNoon,
    EOSolarMidnight,
    EOEOTMinutes,
    EOSolarSeconds,
    EOSolarMinutes,
    EOSolarHours,
    EOSiderealSeconds,
    EOSiderealMinutes,
    EOSiderealHours,
    EOAzimuth,
    EOAltitude,
    EOLeapYear,
    EOSaturn,
    EOJupiter,
    EOMars,
    EOEarth,
    EOVenus,
    EOMercury,
    EOMoon,
    EOChandra,
    EOTerra,
    EOEclipseRingSun,
    EOEclipseRingMoon,
    EOEclipseRingEarthShadow,
    EOEclipseRingAscNode,
    EOEclipseRingDesNode,
    EOEclipse
} EOHandKind;


@interface EOHandView : EOScheduledView {
    EOHandKind		kind;
    double		length;
    double		length2;
    double		width;
    double		arrowLength;
    double		arrowWidth;
    double		angle;
    UIColor		*strokeColor;
    UIColor		*armStrokeColor;
    UIColor		*fillColor;
    bool		first;
    bool		animationInProgress;
    ESWatchTime		*tim;
    ESTimeLocAstroEnvironment	*env;
    ESAstronomyManager	*astro;
    ECPlanetNumber	planet;
}

@property (readonly) double length, width;
@property (readwrite, assign) ECPlanetNumber planet;

- (void)resetTarget;
- (void)zeroAngle;
- (id)initWithFrame:(CGRect)frame kind:(EOHandKind)aKind update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor;
- (EOHandView *)initWithKind:(EOHandKind)aKind length:(double)aLength length2:(double)aLength2 width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor armStrokeColor:(UIColor *)armsColor arrowLength:(double)arrowL arrowWidth:(double)arrowW;
- (EOHandView *)initWithKind:(EOHandKind)aKind length:(double)aLength length2:(double)aLength2 width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor armStrokeColor:(UIColor *)armsColor arrowLength:(double)arrowL;

@end
