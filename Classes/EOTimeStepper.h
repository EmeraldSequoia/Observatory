//
//  EOTimeStepper.h
//  Emerald Observatory
//
//  The time controller's model: which unit a step means, the hold-to-scrub
//  state machine, and the operations on the clock's ESWatchTime.  No UIKit
//  here, so it can be compiled and exercised outside the app; the clock that
//  owns it is reached only through EOTimeStepperClient.
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
@end

// What one step (or one scrub tick) moves the time by.  The order is the chip order.
typedef enum EOTimeStepUnit {
    EOTimeStepCentury = 0,
    EOTimeStepYear,
    EOTimeStepMonth,
    EOTimeStepDay,
    EOTimeStepHour,
    EOTimeStepMinute,
    EOTimeStepSecond,
    EOTimeStepNumUnits
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
    EOTimeScrubState          scrubState;
    int                       scrubDirection;     // +1 forward, -1 backward
    NSTimer                   *holdTimer;
}

@property (readonly) EOTimeStepUnit unit;
@property (readonly) EOTimeScrubState scrubState;
@property (readonly) int scrubDirection;

- (id)initWithWatchTime:(ESWatchTime *)aTime env:(ESTimeLocAstroEnvironment *)anEnv client:(id<EOTimeStepperClient>)aClient ticksPerSecond:(int)aTicksPerSecond;

// Labels, localized: a chip's, the pair's ("1 day"), and the status line's ("Stopped", "20 day/s ▶")
+ (NSString *)labelForUnit:(EOTimeStepUnit)aUnit;
- (NSString *)stepLabel;
- (NSString *)statusString;

// The chip: persisted in NSUserDefaults as EOTimeStepUnit
- (void)selectUnit:(EOTimeStepUnit)newUnit;

// One step: freezes the clock, moves it one unit, has the display redraw
- (void)stepInDirection:(int)direction;

// The pair's touches: a press steps at once and arms the hold; the release ends any scrub
- (void)pressInDirection:(int)direction;
- (void)endPress;
- (bool)isScrubbing;    // the hold has engaged

// From the clock's tick: one unit per tick while a scrub runs
- (void)scrubTick;

// Back to the present, running
- (void)now;

@end
