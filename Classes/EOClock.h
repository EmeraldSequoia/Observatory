//
//  EOClock.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/16/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandAlarmView.h"
#include "ESCalendar.hpp"


#define EOSCREENWIDTH      768
#define EOSCREENHEIGHT	  1024
#define EOCURRENTSTATUSBARHEIGHT ([UIApplication sharedApplication].statusBarFrame.size.height)
#define EOSTATICSTATUSBARHEIGHT 20

class ESTimeLocAstroEnvironment;
class ESWatchTime;
class ClockLocationObserver;
class ClockTimeSyncObserver;

@class EOBaseView, EOHandView, EORingView, EOMoonView, EOEarthView, EOHandTriangleView, EOHandBreguetView, EOHandImageView, EOHandNeedleView;
@class EORingsAndPlanetsShuffleView, EOLogoShuffleView, EOAltitudeDialShuffleView, EOAzimuthDialShuffleView, EOEclipseDialShuffleView, EOEOTDialShuffleView, EOEarthBackShuffleView, EOSimpleImageShuffleView;
@class EOEclipseRingImageView, EOEclipseView, EOMoonAgeView;

@interface EOClock : NSObject<UIActionSheetDelegate, UIAlertViewDelegate> {
    ESWatchTime		*time;
    ESTimeLocAstroEnvironment *env;
    EOBaseView		*view;
    NSMutableArray	*subviews;
    NSTimer		*theTimer;
    UILabel		*dateLabel;
    UILabel		*bigDate;
    UILabel		*bigDate2;
    UILabel		*utcdayLabel;
    UILabel		*tzLabel;
    UILabel		*azLabel;
    UILabel		*altLabel;
    UILabel		*yearLabel;
    UILabel		*leapLabel;
    UILabel             *eclipseStatusLabel;
    UILabel             *eclipseHorizonLabel;
    UILabel		*NTPStatusLabel;
    
    EORingsAndPlanetsShuffleView *ringsAndPlanetsBackView;
    EOLogoShuffleView            *logoView;
    EOEarthBackShuffleView       *earthBackView;
    EOAltitudeDialShuffleView    *altitudeDialView;
    EOAzimuthDialShuffleView     *azimuthDialView;
    EOEclipseDialShuffleView    *eclipseDialView;
    EOEOTDialShuffleView         *eotDialView;

    EOMoonView          *moonView;
    EOEarthView         *earthView;

    EOHandTriangleView  *utcHourHand;
    EOHandTriangleView  *utcMinuteHand;
    EOHandTriangleView  *utcSecondHand;
    EOHandTriangleView  *solarHourHand;
    EOHandTriangleView  *solarMinuteHand;
    EOHandTriangleView  *solarSecondHand;
    EOHandTriangleView  *siderealHourHand;
    EOHandTriangleView  *siderealMinuteHand;
    EOHandTriangleView  *siderealSecondHand;

    EORingView          *sunRing;
    EORingView          *moonRing;
    EORingView          *mercuryRing;
    EORingView          *venusRing;
    EORingView          *marsRing;
    EORingView          *jupiterRing;
    EORingView          *saturnRing;

    EOHandAlarmView     *alarmHand;
    EOHandView          *hour24Hand;
    EOHandView          *sunriseHand;
    EOHandView          *sunsetHand;
    EOHandView          *goldenHourEndHand;
    EOHandView          *civilTwilightBeginHand;
    EOHandView          *nauticalTwilightBeginHand;
    EOHandView          *astronomicalTwilightBeginHand;
    EOHandView          *goldenHourBeginHand;
    EOHandView          *civilTwilightEndHand;
    EOHandView          *nauticalTwilightEndHand;
    EOHandView          *astronomicalTwilightEndHand;
    EOHandView          *snoonHand;	// solar noon
    EOHandView          *smidHand;	// solar midnight

    EOHandBreguetView   *hour12Hand;
    EOHandBreguetView   *minuteHand;
    EOHandNeedleView    *secondHand;

    EOHandImageView     *saturnHand;
    EOHandImageView     *jupiterHand;
    EOHandImageView     *marsHand;
    EOHandImageView     *earthHand;
    EOHandImageView     *moonHand;
    EOHandImageView     *venusHand;
    EOHandImageView     *mercuryHand;

    EOHandTriangleView  *altHand;
    EOHandTriangleView  *azHand;
    EOHandTriangleView  *northHand;
    EOHandTriangleView  *yearHand;
    EOHandTriangleView  *eotHand;
    
    EOEclipseRingImageView *eclipseRingSunHand;
    EOEclipseRingImageView *eclipseRingMoonHand;
    EOEclipseRingImageView *eclipseRingEarthShadowHand;
    EOEclipseRingImageView *eclipseRingAscNodeHand;
    EOEclipseRingImageView *eclipseRingDesNodeHand;
    EOEclipseView *eclipseView;
    //EOMoonAgeView *moonAgeView;

#undef DSTINDICATORS
#ifdef DSTINDICATORS
    EOSimpleImageShuffleView *springDSTIndicator;
    EOSimpleImageShuffleView *fallDSTIndicator;
#endif

#ifdef SEASONS
    EOSimpleImageShuffleView *springIcon;
    EOSimpleImageShuffleView *summerIcon;
    EOSimpleImageShuffleView *fallIcon;
    EOSimpleImageShuffleView *winterIcon;
#endif

    UIButton		*demoBut;
    UIButton		*yearBut;
    UIButton		*centBut;
    UIButton		*dayBut;
    UIButton		*wdayBut;
    UIButton		*monBut;
    UIButton		*lunarBut;
    UIButton		*hourBut;
    UIButton		*minuteBut;
    UIButton		*yearButB;
    UIButton		*centButB;
    UIButton		*dayButB;
    UIButton		*wdayButB;
    UIButton		*monButB;
    UIButton		*lunarButB;
    UIButton		*hourButB;
    UIButton		*minuteButB;
    UIButton		*resetBut;
    UIButton		*azBut;
    UIButton		*altBut;
    UIButton		*snoozeBut;
    UIButton		*NTPStatusBut;

    ClockTimeSyncObserver *timeSyncObserver;
    ClockLocationObserver *locationObserver;

    bool		setMode;
    bool		finishingHelp;
    int			centStep;
    int			yearStep;
    int			monthStep;
    int			lunarStep;
    int			wkdStep;
    int			dayStep;
    int			hourStep;
    int			minuteStep;
    bool		resetBool;
    int			planet;
    UIInterfaceOrientation  lastOrientation;
    bool		noonOnTop;
}

@property (readonly) ESWatchTime *time;
@property (readonly) ESTimeLocAstroEnvironment *env;
@property (readonly) bool noonOnTop, setMode;
@property (readwrite) bool finishingHelp;
@property (readonly) UILabel *dateLabel;
@property (readonly) UIInterfaceOrientation lastOrientation;

+ (EOClock *)theClock;
- (void)reCreateMainDial;
- (void)clockRedraw:(CGContextRef)context forOrientation:(UIInterfaceOrientation)orientation;
- (void)clockSetup:(UIView *)view orientation:(UIInterfaceOrientation)orientation;
- (void)resetAfterOrientationChangeToOrientation:(UIInterfaceOrientation)newOrientation newSize:(CGSize)newSize;
+ (void)drawCircularText:(NSString *)str inRect:(CGRect)rect radius:(double)radius angle:(double)angle offset:(double)offsetAngle withContext:(CGContextRef)context withFont:(UIFont *)fnt color:(UIColor *)color demi:(bool)demi;
+ (void)drawDialNumbersUpright:(CGContextRef)context x:(double)x y:(double)y text:(NSString *)text font:(UIFont *)font color:(UIColor *)color radius:(double)radius;
+ (void)drawDialNumbersDemiRadial:(CGContextRef)context x:(double)x y:(double)y text:(NSString *)text font:(UIFont *)font color:(UIColor *)color radius:(double)radius radius2:(double)radius2;
+ (void)drawZodiacDialDemiRadial:(CGContextRef)context x:(double)x y:(double)y font:(UIFont *)font color:(UIColor *)color radius:(double)radius radius2:(double)radius2;
+ (void)drawTicks:(CGContextRef)context x:(double)x y:(double)y n:(int)n innerRadius:(double)innerRadius outerRadius:(double)outerRadius width:(double)width color:(UIColor *)color angle1:(double)angle1 angle2:(double)angle2;
+ (void)drawTicks:(CGContextRef)context x:(double)x y:(double)y n:(int)n innerRadius:(double)innerRadius outerRadius:(double)outerRadius width:(double)width color:(UIColor *)color;
+ (void)drawTicksNoFives:(CGContextRef)context x:(double)x y:(double)y n:(int)n innerRadius:(double)innerRadius outerRadius:(double)outerRadius width:(double)width color:(UIColor *)color;
+ (void)drawText:(NSString *)text
	  inRect:(CGRect)rect
     withContext:(CGContextRef)context
	withFont:(UIFont *)aFont
	   color:(UIColor *)color;
+ (CGPoint)clockCenter;
- (void)prepareToReorient:(UIInterfaceOrientation)newOrientation;
- (void)setStatusBar:(NSNotification *)notif;
- (void)resetTargets;
- (void)resetTZ;
- (void)locationUpdate;
- (void)checkSanityForTimezone:(ESTimeZone *)tz latitude:(double)lat longitude:(double)lng;
- (void)showQuickStartIfNecessaryInView:(UIView *)parentView;
+ (void)setAlarmTime:(NSDate *)aTime;
+ (ESWatchTime *)alarmTime;
+ (void)setupLocalNotificationForAlarmStateEnabled:(bool)enabled;
- (void)notifyTimeAdjustment;
- (void)goingToBackground;
- (void)goingToForeground;
- (void)adjustAlarmTime;
- (int)ringsForTime;
- (void)checkSanityHereAndNow:(id)foo;

@end
