//
//  EOTimeStepper.h
//  Emerald Observatory
//
//  The time controller's model: which unit a step means, the body for the
//  rise / set / transit events, the hold-to-scrub state machine, the
//  transport, and the operations on the clock's ESWatchTime.  No UIKit here,
//  so it can be compiled and exercised outside the app; the clock that owns
//  it is reached only through EOTimeStepperClient.
//
//  Design: chronometer-web planning/2026-09-25-ios-backport-observatory-time-controller.md
//

#import <Foundation/Foundation.h>
#include "ESTime.hpp"

class ESWatchTime;
class ESTimeLocAstroEnvironment;

// What the stepper needs from the clock that owns it
@protocol EOTimeStepperClient
- (void)timeDidChange;          // the display must redraw at the next tick
- (void)transportDidChange;     // the views must re-arm their schedules as well
- (int)dialPlanetNumber;        // the planet on the altitude and azimuth dials (an ECPlanetNumber)
@end

// What one step moves the time by.  The order is the chip order: the calendar units, which
// also scrub when held, then the astronomical events, which are tap-only (each tap is a search).
typedef enum EOTimeStepUnit {
    EOTimeStepCentury = 0,
    EOTimeStepYear,
    EOTimeStepMonth,
    EOTimeStepDay,
    EOTimeStepHour,
    EOTimeStepMinute,
    EOTimeStepSecond,
    EOTimeStepRise,         // the chosen body's rising
    EOTimeStepSet,          // its setting
    EOTimeStepTransit,      // its crossing of the meridian
    EOTimeStepPhase,        // the Moon's next quarter
    EOTimeStepNumUnits,
    EOTimeStepFirstAstro = EOTimeStepRise
} EOTimeStepUnit;

typedef enum EOTimeScrubState {
    EOTimeScrubIdle = 0,    // no finger on the pair
    EOTimeScrubPending,     // pressed; the hold timer is armed
    EOTimeScrubHeld         // the hold engaged: time moves until the release
} EOTimeScrubState;

@interface EOTimeStepper : NSObject {
    ESWatchTime               *time;              // the client's; not owned
    ESTimeLocAstroEnvironment *env;               // the client's; not owned
    id<EOTimeStepperClient>   client;             // owns us; not retained
    int                       ticksPerSecond;     // the client's clock rate: a scrub moves one unit per tick
    EOTimeStepUnit            unit;
    int                       body;               // for rise / set / transit: an ECPlanetNumber, or -1 to follow the dials
    EOTimeScrubState          scrubState;
    int                       scrubDirection;     // +1 forward, -1 backward
    NSTimer                   *holdTimer;
}

@property (readonly) EOTimeStepUnit unit;
@property (readonly) EOTimeScrubState scrubState;
@property (readonly) int scrubDirection;

- (id)initWithWatchTime:(ESWatchTime *)aTime env:(ESTimeLocAstroEnvironment *)anEnv client:(id<EOTimeStepperClient>)aClient ticksPerSecond:(int)aTicksPerSecond;

// The units
+ (bool)unitIsAstro:(EOTimeStepUnit)aUnit;      // rise, set, transit, phase
+ (bool)unitUsesBody:(EOTimeStepUnit)aUnit;     // rise, set, transit
+ (NSString *)labelForUnit:(EOTimeStepUnit)aUnit;   // the chip's label, localized

// The chip: persisted in NSUserDefaults as EOTimeStepUnit
- (void)selectUnit:(EOTimeStepUnit)newUnit;

// The body for rise / set / transit: the dials' planet until the user steps it with ‹ ›, then
// the user's own, persisted in NSUserDefaults as EOTimeStepBody
- (int)bodyPlanetNumber;
- (void)stepBody:(int)direction;

// The pair's label ("1 day", "Sunrise", "Jupiter transit", "Moon phase") — the caller supplies
// the body's localized name, which lives on the UIKit side — and the status line's
- (NSString *)stepLabelWithBodyName:(NSString *)bodyName;
- (NSString *)statusString;

// One calendar step: freezes the clock, moves it one unit, has the display redraw
- (void)stepInDirection:(int)direction;

// The pair's touches.  A press steps at once — for an astro unit it searches and jumps, and
// answers false when there is no such event here — and, for a calendar unit, arms the hold;
// the release ends any scrub.
- (bool)pressInDirection:(int)direction;
- (void)endPress;
- (bool)isScrubbing;    // the hold has engaged

// From the clock's tick: one unit per tick while a scrub runs
- (void)scrubTick;

// The transport: ‖ freezes the clock where it is, ▶ runs it on from there at real speed, ◀ runs
// it backward at real speed (the views schedule by direction: EOScheduledView), Now returns to
// the present (running)
- (void)stop;
- (void)play;
- (void)playReverse;
- (void)now;
- (bool)isRunning;      // the clock is moving
- (bool)isAtPresent;    // it shows the present, so there is nothing to return to

@end
