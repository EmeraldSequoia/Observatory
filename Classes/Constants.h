//
//  Constants.h
//  Emerald Chronometer/Orrery
//
//  Created by Bill Arnett on 5/9/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

// Guard against multiple inclusion:
#ifndef EC_CONSTANTS
#define EC_CONSTANTS
#undef CAPTUREDEFAULTS
#define CAPTURESPECIALS

#define pi	M_PI
#define twoPi	(M_PI*2)
#define halfPi	(M_PI/2)

// Compile-time switches:
#undef MEMORY_TRACK_TEXTURE
#undef SHAREDCLOCK
#define INNER_SUBDIALS

//#define HIRES_DUMP 4.0
#ifndef NDEBUG
#define ECTRACE
#define BIGMAPLABELS
#define SAVEHELPSTACK
#define SAVEWATCHTIME
#endif

// control dimensions
#define kStdButtonWidth			40.0
#define kStdButtonHeight		40.0
#define kSliderHeight			7.0
#define kSwitchButtonWidth		94.0
#define kSwitchButtonHeight		27.0
#define kProgressIndicatorSize		20.0

// UITableView row heights
#define kUIRowHeight			40.0
#define kPrefFontSize			16

// table view cell content offsets
#define kCellLeftOffset			8.0
#define kCellTopOffset			7.0

// parameters to determing gestures
#define ECMinSwipeX			65	// more than this counts 
#define ECMinSwipeXFirstSpeed		500	// more than this counts 
#define ECMaxSwipeY			999	// less than this counts (ie ignore Y)
#define ECMaxPressX                     15      // less than this many pixels is a press, not a drag
#define ECMinHold                       1      // more than this many seconds is a hold
#define kECDragRepeatInterval           0.01

// ECQView parameters
#define ECDialRadiusFactor		0.92
#define ECDialSmallRadiusCutoff         45
#define ECDialSmallRadiusFactor		((0.11)/(ECDialSmallRadiusCutoff - 25))
#define ECHandLineWidthFill		0.25
#define ECHandLineWidthOutline		1.0
#define ECMaxLeaves			32

// abritrary sizes of things
#define kECTimerResolutionInSeconds	(0.01)	// all events are rounded to this number of seconds
#define kECNumDefaults			5
#define ECMinDeltaAngle			(12 * 2 * M_PI / 360)	    // 2 seconds
#define ECTexturePartPadding            1
#define ECMinimumInputViewSize          (40) // in each dimension
#define ECLoadingListTextOffset         (35)
#define ECLoadingListIconOffset         (-20)
#define ECMaxRecents			500	// max size of recents list

// Texture size limitation
#define ECHenryMaxTextureSize           (200 * 1024 * 1024)
#define ECMemoryBumpInterval		60	// seconds between attempts to increase memory limit

// Zoom (in and out)
#define ECZoomMinPower2 (-2)  // 0.25
#define ECZoomMaxPower2 ( 0)  // 1

// Derived from above
#define ECNumVisualZoomFactors (ECZoomMaxPower2 - ECZoomMinPower2 + 1)
#define ECZoom0Index (-ECZoomMinPower2)
#define ECZoomIndexForPower2(z2) (z2 - ECZoomMinPower2)

// timing
#define ECTargetAlarmWrap               (24 * 60 * 60)
#define ECIntervalAlarmWrap             (24 * 60 * 60)
#define kECGLFrameRate                  (1.0/120)
#define kECGLSwipeAnimateSpeed          1200  // pixels per second
#define kECGLAngleAnimationSpeed        2.0   // radians per second
#define kECGLLinearAnimationSpeed       80.0 // pixels per second
#define kECGLFlipAnimationTime          0.5   // seconds
#define kECGLGridAnimationTime          0.5   // seconds
#define kECButtonAnimateTime		0.25
#define kECButtonFirstRepeatInterval	0.75
#define kECButtonRepeatInterval		0.25
#define kECButtonFastRepeatInterval	0.1
#define kECButtonFasterRepeatInterval	0.05
#define ECModeSwitchAnimationDuration	0.75	// seconds
#define ECHandAnimationDuration		0.67	// in seconds
#define ECFastAnimationDuration		0.01
#define ECLevelChangeAnimationDuration	0.75	// seconds
#define ECStatusIndicatorBlinkRate      0.5     // seconds
#define ECControlStickTime		5
#define ECInitialControlStickTime	20
#define ECControlFadeTime		0.33	// should match statusBar animation duration
#define ECStatusPersistence		5	// how long the status line stays visible
#define ECSwipeControlFadeOffTime	0
#define ECSwipeControlFadeOnTime	1
#define ECHelpFadeTime			0.5
#define ECHeartbeatInterval             0.1
#define ECFarInTheFuture                (1E100)
#define ECFarInThePast                  (-1E100)
#define ECAReallyLongTime               (2E100)
#define TOOBIGSKEW			1800		   // something is really screwy if the skew is this big 
#define ECSavedSkewLifetime             ECAReallyLongTime  // after this much time the skew saved in the defaults is discarded
#define ECSavedSkewThreshold            (60)               // unless it's this much in absolute value, in which case it's assumed to be systematic error
#define ECAlarmRings			20

#define ECInitialAccuracy		10000	// locationManager desired accuracy on startup (meters)
#define ECRequestAccuracy		100	// locationManager desired accuracy on user requests (meters)
#define ECLocationFixLifetime           1800    // seconds after which we update the location; fixes are no longer shown as valid after this amount of time
#define ECLocationAutoCheckTimeout      60     // seconds after which we stop trying to get a location and just display yellow
#define ECLocationRequestCheckTimeout   180    // seconds after which we stop trying to get a location and just display yellow
#define ECDefaultHorizontalError	101	// presumed error in geoNames db

#define ECMinimumSupportedAstroDate     (-189344476800.0)  // Jan 1 4000 BC
#define ECGregorianStartDate		(- 13197600000.0)  // Oct 15 1582
#define ECMaximumSupportedAstroDate     (  25245561600.0)  // Jan 1 2801 AD
#define ECLastAstroDateWarningInterval  (10)  // Seconds

#define kECAUInKilometers 149597870.691

typedef enum ECPlanetNumber {
    ECPlanetSun       = 0,
    ECPlanetMoon      = 1,
    ECPlanetMercury   = 2,
    ECPlanetVenus     = 3,
    ECPlanetEarth     = 4,
    ECPlanetMars      = 5,
    ECPlanetJupiter   = 6,
    ECPlanetSaturn    = 7,
    ECPlanetUranus    = 8,
    ECPlanetNeptune   = 9,
    ECPlanetPluto     = 10,
    ECPlanetMidnightSun=11,
    ECNumPlanets      = 11,
    ECNumLegalPlanets = 10,
    ECFirstActualPlanet = 2,
    ECLastLegalPlanet = 9
} ECPlanetNumber;

typedef enum ECEclipseKind {
    ECEclipseNoneSolar    = 0,
    ECEclipseNoneLunar    = 1,
    ECEclipseSolarNotUp   = 2,
    ECEclipsePartialSolar = 3,
    ECEclipseAnnularSolar = 4,
    ECEclipseTotalSolar   = 5,
    ECEclipseLunarNotUp   = 6,
    ECEclipsePartialLunar = 7,
    ECEclipseTotalLunar   = 8
} ECEclipseKind;

enum {
    ECDefaultNumParts = 20,
    ECDefaultNumChimes = 2,
    ECDefaultNumButtons = 4
};

typedef enum ECLocState {
    ECLocGood = 0,
    ECLocWorkingGood = 1,
    ECLocWorkingUncertain = 2,
    ECLocUncertain = 3,
    ECLocCanceled = 4,
    ECLocManual = 5
} ECLocState;

typedef enum ECTSState {
    ECTSGood = 0,
    ECTSWorkingGood = 1,
    ECTSWorkingUncertain = 2,
    ECTSUncertain = 3,
    ECTSOFF = 4,
    ECTSFailed = 5,
    ECTSCanceled = 6
} ECTSState;

typedef enum ECWatchLoadState {
    ECWatchUnloaded,
    ECWatchLoading,
    ECWatchLoaded,
    ECWatchAttached,
    ECWatchUnattaching
} ECWatchLoadState;

// constants used in xml watch descriptions

#define ECNumTimers                 3
// Check size of updateTimer bitfield in ECGLPart if enlarging this enum
typedef enum ECWatchTimerSlot {
    ECTimerLB			    = 0,
    ECMainTimer			    = 0,
    ECStopwatchTimer		    = 1,
    ECStopwatchLapTimer		    = 2,
    ECStopwatchDisplayTimer         = 2,  // note: a given watch will use either a stopwatchDisplayTimer or a stopwatchLapTimer but not both
    ECTimerUB			    = 2   // 2 bits have been allocated, meaning a max of 3 can go here without changing bitfield
} ECWatchTimerSlot;

// Check size of envSlot bitfield in ECGLPart if enlarging this enum
typedef enum ECWatchEnvSlot {
    ECEnvLB                         = 0,
    ECEnvGlobal                     = 0, // The location and time zone set globally for the application
    ECEnvFirstNonGlobal             = 1,
    ECEnvUB                         = 31  // 5 bits have been allocated; current worldtime uses 1(global) + 24(worldtime) + 4(subdial) = 29 of these 32
} ECWatchEnvSlot;

// Check size of partSpecialness bitfield in ECGLPart if enlarging this enum
typedef enum ECPartSpecialness {
    ECPartSpecialLB                 = 0,
    ECPartNotSpecial                = 0,
    ECPartSpecialWorldtimeRing      = 1,
    ECPartSpecialSubdial            = 2,
    ECPartSpecialDotsMap            = 3,
    ECPartSpecialUB                 = 3
} ECPartSpecialness;

// Check size of specialParameter bitfield in ECGLPart if enlarging this upper bound
#define ECPartSpecialParamLB 0
#define ECPartSpecialParamUB 15

typedef enum ECAlarmTimeMode {
    ECAlarmTimeTarget,
    ECAlarmTimeInterval
} ECAlarmTimeMode;

typedef enum ECWatchModeEnum {
    ECfrontMode                     = 0,	    // normal front side view
    ECnightMode                     = 1,	    // luminous items with everything else dimmed (and maybe red)
    ECbackMode                      = 2,            // backside view with all images mirror imaged (possibly showing animated gears)
    ECbackNightMode                 = 3,      // for future use, not currently in use
    ECNumWatchDrawModes             = 3,
    ECInvalidMode                   = -1,      // to make compiler treat this as an int instead of an unsigned(?)
    ECmodeLB                        = 0,     // Put the bounds last so the debugger doesn't print out that enumeration
    ECmodeUB                        = 2,
} ECWatchModeEnum;

typedef enum ECWatchModeMask {
    ECmaskLB			    = 1,
    frontMask			    = (1 << ECfrontMode),
    nightMask			    = (1 << ECnightMode),
    backMask			    = (1 << ECbackMode),
    backOrBackNightMask             = ((1 << ECbackMode) | (1 << ECbackNightMode)),
    allModes			    = 7,	    // not including stopwatch or spare
    stopMask			    = 16,	    // stopwatch mode
    spareMask                       = 32,
    specialMask			    = 64,	    // 2D switcher (grid) or options panel
    worldMask			    = 128,	    // multi-timezone watch
    ECmaskUB			    = 128
} ECWatchModeMask;

typedef enum ECDiskMarksMask {			// for both dials and wheels
    ECDiskMarksMaskLB		    = 0,
    ECDiskMarksMaskCenter	    = 1,	    // mark the center
    ECDiskMarksMaskInner	    = 2,	    // mark the inner edge
    ECDiskMarksMaskOuter	    = 4,	    // mark the outer edge
    ECDiskMarksMaskDotRing	    = 8,	    // dots instead of tick marks
    ECDiskMarksMaskTickIn	    = 16,	    // "ticks" start from center and radiate outward
    ECDiskMarksMaskTickOut	    = 32,	    // "ticks" start from circumference and project inward
    ECDiskMarksMaskArc		    = 64,	    // concentric arcs
    ECDiskMarksMaskLine		    = 128,	    // parallel lines
    ECDiskMarksMaskOdd		    = 256,	    // draw only odd numbered marks (valid only for dotRing)
    ECDiskMarksMaskTachy	    = 512,	    // draw tachymeter marks
    ECDiskMarksMaskNo5s		    = 1024,	    // skip every 5th mark
    ECDiskMarksMaskRose		    = 2048,	    // draw a simple compass rose
    ECDiskMarksMaskUB		    = 4095
} ECDiskMarksMask;

// Check size of animationDir bitfield in ECGLPart if enlarging this enum
typedef enum ECAnimationDirection {
    ECAnimationDirLB                = 0,
    ECAnimationDirAlwaysCW          = 1,
    ECAnimationDirAlwaysCCW         = 2,
    ECAnimationDirLogicalForward    = 3,
    ECAnimationDirLogicalBackward   = 4,
    ECAnimationDirClosest           = 5,
    ECAnimationDirFurthest          = 6,
    ECAnimationDirUB                = 6,
} ECAnimationDirection;

// Check size of dragType bitfield in ECGLPart if enlarging this enum
typedef enum ECDragType {
    ECDragLB                        = 0,
    ECDragNotDragging               = 0,  // Animate hands with ECDragAnimationAlways
    ECDragNormal                    = 1,
    ECDragHack1                     = 2,  // Animate hands with ECDragAnimationHack1 at much faster speed
    ECDragUB                        = 2,
} ECDragType;

// Check size of dragAnimationType bitfield in ECGLPart if enlarging this enum
typedef enum ECDragAnimationType {
    ECDragAnimationLB               = 0,
    ECDragAnimationNever            = 0,
    ECDragAnimationAlways           = 1,
    ECDragAnimationHack1            = 2,  // When dragging a ECDragHack1 part, drag this part at a faster speed; other part drags mean slow animate
    ECDragAnimationHack2            = 3,  // When dragging a ECDragHack1 part, drag this part at a faster speed; other part drags mean don't animate
    ECDragAnimationUB               = 3
} ECDragAnimationType;

typedef enum ECColor {
    ECColorLB			    = 10,
    ECblack			    = 10,
    ECblue			    = 11,
    ECgreen			    = 12,
    ECcyan			    = 13,
    ECred			    = 14,
    ECyellow			    = 15,
    ECmagenta			    = 16,
    ECwhite			    = 17,
    ECbrown			    = 18,
    ECdarkGray			    = 19,
    EClightGray			    = 20,
    ECclear			    = 21,
    ECColorUB			    = 22
} ECColorType;

typedef enum ECQHandType {
    ECQHandTypeLB		    = 29,
    ECQHandSun2			    = 29,	    // like ECQHandSun but without the extra long ray
    ECQHandRect			    = 30,	    // just the outer end of a rectangular hand
    ECQHandTri			    = 31,	    // triangle
    ECQHandQuad			    = 32,	    // quadratic bezier
    ECQHandCube			    = 33,	    // cubic bezier
    ECQHandRise			    = 34,	    // clockwise pointing partial sun
    ECQHandSet			    = 35,	    // counterclockwise pointing partial sun
    ECQHandSpoke		    = 36,	    // arc with text (part of a wheel)
    ECQHandSun			    = 37,	    // "sun" with rays
    ECQHandWire			    = 38,	    // a single line
    ECQHandGear			    = 39,	    // gear with teeth, pinion and spokes
    ECQHandBreguet		    = 40,	    // Breguet style hand
    ECQHandTypeUB		    = 40
} ECQHandType;

typedef enum ECWheelOrientation {
    ECWheelOrientationLB	    = 41,
    ECWheelOrientationTwelve	    = 41,	    // with the right side up numbers at the twelve oclock position
    ECWheelOrientationThree	    = 42,	    // with the right side up numbers at the three oclock position
    ECWheelOrientationSix	    = 43,	    // with the right side up numbers at the six oclock position
    ECWheelOrientationNine	    = 44,	    // with the right side up numbers at the nine oclock position
    ECWheelOrientationStraight	    = 45,
    ECWheelOrientationUB	    = 45
} ECWheelOrientation;

typedef enum ECDialOrientation {
    ECDialOrientationLB		    = 60,
    ECDialOrientationUpright	    = 60,	    // all numbers right  way up
    ECDialOrientationRadial	    = 61,	    // all numbers with baseline radially out from center
    ECDialOrientationDemiRadial	    = 62,	    // same as radial but with numbers below center inverted
    ECDialOrientationTachy	    = 63,	    // same as radial but with numbers positioned for a tachymeter
    ECDialOrientationRotatedRadial  = 64,	    // same as radial but with text rotated 90 degrees
    ECDialOrientationYear	    = 65,	    // tick marks for a year
    ECDialOrientationUB		    = 65
} ECDialOrientation;

typedef enum ECDialTickType {
    ECDialTickLB		    = 70,	    // values must be in this order
    ECDialTickNone		    = 70,	    // no tick marks
    ECDialTick4			    = 71,	    // tick at each quarter
    ECDialTick8			    = 72,	    // 8 ticks around
    ECDialTick10		    = 73,	    // 10 ticks around
    ECDialTick12		    = 74,	    // 12 (tick at each hour)
    ECDialTick16		    = 75,	    // 16 (tick for each compass quarter)
    ECDialTick36		    = 76,	    // 12 / 3
    ECDialTick60		    = 77,	    // 12 / 5	(major tick on each hour, minor tick on each minute)
    ECDialTick72		    = 78,	    // 12 / 6
    ECDialTick96		    = 79,	    // 16 / 4
    ECDialTick180		    = 80,	    // 12 / 3 / 5
    ECDialTick240		    = 81,	    // 24 / 2 / 5
    ECDialTick241		    = 82,	    // 12 / 5 / 4
    ECDialTick288		    = 83,	    // 24 / 2 / 6
    ECDialTick300		    = 84,	    // 12 / 5 / 5
    ECDialTick360		    = 85,	    // 12 / 6 / 5
    ECDialTickUB		    = 85
} ECDialTickType;

typedef enum ECHoleType {
    ECHoleLB			    = 90,
    ECHoleWind			    = 90,	    // rectangular window
    ECHolePort			    = 91,	    // round port hole
    ECHoleUB			    = 91
} ECHoleType;

typedef enum ECHandKind {
    ECHandKindLB       = 100,
    ECSecondHandKind   = 100,
    ECMinuteHandKind   = 101,
    ECHour12HandKind   = 102,
    ECHour24HandKind   = 103,
    ECDayHandKind      = 104,
    ECWkDayHandKind    = 105,
    ECMonthHandKind    = 106,
    ECYear1HandKind    = 107,
    ECYear10HandKind   = 108,
    ECYear100HandKind  = 109,
    ECYear1000HandKind = 110,
    ECNotTimerZeroKind = 111,
    ECReverseHour24Kind= 112,
    ECHandKindFirstLatLong = 113,
    ECLatitudeMinuteOnesHandKind = 113,
    ECLatitudeMinuteTensHandKind = 114,
    ECLatitudeOnesHandKind       = 115,
    ECLatitudeTensHandKind       = 116,
    ECLongitudeMinuteOnesHandKind = 117,
    ECLongitudeMinuteTensHandKind = 118,
    ECLongitudeOnesHandKind       = 119,
    ECLongitudeTensHandKind       = 120,
    ECLongitudeHundredsHandKind   = 121,
    ECLatitudeSignHandKind        = 122,
    ECLongitudeSignHandKind       = 123,
    ECHandKindLastLatLong  = 123,
    ECMoonDayHandKind     = 124,
    ECHandKindFirstAlarm   = 125,
    ECTargetMinuteHandKind = 125,
    ECTargetHour12HandKind = 126,
    ECTargetHour12HandKindB = 127,
    ECTargetHour24HandKind = 128,
    ECIntervalSecondHandKind = 129,
    ECIntervalMinuteHandKind = 130,
    ECIntervalHour12HandKind = 131,
    ECIntervalHour24HandKind = 132,
    ECHandKindLastAlarm    = 132,
    ECSunRAHandKind = 133,
    ECMoonRAHandKind = 134,
    ECHour24MoonHandKind = 135,
    ECMercuryYearHandKind    = 136,
    ECVenusYearHandKind    = 137,
    ECEarthYearHandKind    = 138,
    ECMarsYearHandKind    = 139,
    ECJupiterYearHandKind    = 140,
    ECSaturnYearHandKind    = 141,
    ECReverseSunRAHandKind     = 142,
    ECReverseMoonRAHandKind     = 143,
    ECGreatYearHandKind = 144,
    ECNodalHandKind       = 145,
    ECWorldtimeRingHandKind = 146,
    ECHandKindUB           = 146
} ECHandKind;

// Check size of repeatStrategy bitfield in ECGLPart if enlarging this enum
typedef enum ECPartRepeatStrategy {
    ECPartDoesNotRepeat              = 0,
    ECPartRepeatsSlowlyOnly          = 1,
    ECPartRepeatsAndAcceleratesOnce  = 2,
    ECPartRepeatsAndAcceleratesTwice = 3,
    ECPartRepeatStrategyLB           = 0,
    ECPartRepeatStrategyUB           = 3
} ECPartRepeatStrategy;

typedef enum ECButtonEnabledControl {
    ECButtonEnabledControlLB        = 150,
    ECButtonEnabledAlways           = 150,
    ECButtonEnabledStemOutOnly      = 151,
    ECButtonEnabledWrongTimeOnly    = 152,
    ECButtonEnabledAlarmStemOutOnly = 153,
    ECButtonEnabledControlUB        = 153
} ECButtonEnabledControl;

typedef enum ECDynamicUpdateSpecifier {
    ECDynamicUB			    	  = -1001,	    // note reversal of UB/LB
    ECDynamicUpdateNextSunrise	    	  = -1001,	    // Start at high negative to reduce proability of accidental specification
    ECDynamicUpdateNextSunset	    	  = -1002,
    ECDynamicUpdateNextMoonrise	    	  = -1003,
    ECDynamicUpdateNextMoonset	    	  = -1004,
    ECDynamicUpdateNextSunriseOrMidnight  = -1005,
    ECDynamicUpdateNextSunsetOrMidnight	  = -1006,
    ECDynamicUpdateNextMoonriseOrMidnight = -1007,
    ECDynamicUpdateNextMoonsetOrMidnight  = -1008,
    ECDynamicUpdateForSunriseCover    	  = -1009,
    ECDynamicUpdateForSunsetCover    	  = -1010,
    ECDynamicUpdateForMoonriseCover    	  = -1011,
    ECDynamicUpdateForMoonsetCover    	  = -1012,
    ECDynamicUpdateNextDSTChange    	  = -1013,
    ECDynamicUpdateNextEnvChange    	  = -1013,	    // yes, == DSTChange
    ECDynamicUpdateLocSyncIndicator       = -1014,
    ECDynamicUpdateTimeSyncIndicator      = -1015,
    ECDynamicUpdateNextSunriseOrSunset    = -1016,
    ECDynamicUpdateNextMoonriseOrMoonset  = -1017,
    ECDynamicLB			    	  = -1017
} ECDynamicUpdateSpecifier;

typedef enum ECTerminatorQuadrant {
    ECTerminatorUpperLeft,
    ECTerminatorLowerLeft,
    ECTerminatorUpperRight,
    ECTerminatorLowerRight
} ECTerminatorQuadrant;

// Check bitfield width of handGrabPriority in ECGLPart before changing the following
#define ECGrabPrioLB (-4)
#define ECGrabPrioUB (3)
#define ECGrabPrioDefault 0

#define ECTerminatorQuadrantIsLeft(quad)  (quad <= ECTerminatorLowerLeft)
#define ECTerminatorQuadrantIsRight(quad) (quad > ECTerminatorLowerLeft)
#define ECTerminatorQuadrantIsUpper(quad) (!(quad % 2))
#define ECTerminatorQuadrantIsLower(quad) (quad % 2)

#define kECminRadius			1	    // for dials
#define kECdefaultRadius		100
// min x and y are screen bounds
// default x and y are zero

#define kECminUpdate			kECTimerResolutionInSeconds	    // min update interval and offset (seconds)
#define kECmaxUpdate			(60*60*24*365*10)		    // 10 years

#define kECdefaultDialColor		[UIColor whiteColor]	// for wheels, too
#define kECdefaultHandColor		[UIColor blackColor]	// stroke and fill for hands; stroke for dials and wheels
#define kECdefaultTickType		ECDialTickNone

#define kECminFontSize			1
#define kECmaxFontSize			128
#define kECdefaultFontSize		18

#define kECminHandWidth			0.1
#define kECmaxHandWidth			50
#define kECdefaultHandWidth		2
#define kECminHandLength		1
//#define kECmaxHandLength		screen size
#define kECdefaultHandLength		100
//#define kECdefaultTailScale		0	    // no tail

#define kECminScale			-100
#define kECmaxScale			100
#define kECdefaultScale			1

// padding for margins
#define kLeftMargin			20.0
#define kTopMargin			20.0
#define kRightMargin			20.0
#define kBottomMargin			20.0
#define kTweenMargin			10.0

// control dimensions
#define kSegmentedControlHeight		30.0
#define kPageControlHeight		20.0
#define kTextFieldHeight		30.0
#define kPageControlWidth		160.0
#define kLabelHeight			20.0
#define kToolbarHeight			40.0
#define kUIProgressBarWidth		160.0
#define kUIProgressBarHeight		24.0
#define kUIRowLabelHeight		22.0

#endif
