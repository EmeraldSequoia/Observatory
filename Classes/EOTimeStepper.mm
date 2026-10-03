//
//  EOTimeStepper.mm
//  Emerald Observatory
//
//  See EOTimeStepper.h.
//

#import "EOTimeStepper.h"
#import "ESWatchTime.hpp"
#import "ESTimeLocAstroEnvironment.hpp"
#import "ESErrorReporter.hpp"

// A press becomes a scrub after this long.  The scrub then moves one unit per clock tick, as the
// old row of buttons did: the display shows each position as a jump, with no motion in between,
// so a slower cadence only looks choppier (the web app's ten a second rides on its animation).
static const NSTimeInterval EOHoldDelay = 0.3;

static NSString * const EOTimeStepUnitDefaultsKey = @"EOTimeStepUnit";

// The persisted form of each unit (the web app's keys, so the two apps' settings read alike)
static const char *unitKeys[EOTimeStepNumUnits] = { "cent", "yr", "mo", "day", "hr", "min", "sec" };

@implementation EOTimeStepper

@synthesize unit, scrubState, scrubDirection;

+ (EOTimeStepUnit)unitForKey:(NSString *)key {
    if (key) {
        for (int i = 0; i < EOTimeStepNumUnits; i++) {
            if ([key isEqualToString:[NSString stringWithUTF8String:unitKeys[i]]]) {
                return (EOTimeStepUnit)i;
            }
        }
    }
    return EOTimeStepDay;
}

- (id)initWithWatchTime:(ESWatchTime *)aTime env:(ESTimeLocAstroEnvironment *)anEnv client:(id<EOTimeStepperClient>)aClient ticksPerSecond:(int)aTicksPerSecond {
    if ((self = [super init])) {
        time = aTime;
        env = anEnv;
        client = aClient;
        ticksPerSecond = aTicksPerSecond;
        unit = [EOTimeStepper unitForKey:[[NSUserDefaults standardUserDefaults] stringForKey:EOTimeStepUnitDefaultsKey]];
        scrubState = EOTimeScrubIdle;
        scrubDirection = 1;
        holdTimer = nil;
    }
    return self;
}

- (void)dealloc {
    [holdTimer invalidate];
    holdTimer = nil;
    [super dealloc];
}

+ (NSString *)labelForUnit:(EOTimeStepUnit)aUnit {
    switch (aUnit) {
      case EOTimeStepCentury:
        return NSLocalizedString(@"cent", @"short abbreviation for century");
      case EOTimeStepYear:
        return NSLocalizedString(@"year", @"short abbreviation for year");
      case EOTimeStepMonth:
        return NSLocalizedString(@"mon", @"short abbreviation for month");
      case EOTimeStepDay:
        return NSLocalizedString(@"day", @"short abbreviation for day");
      case EOTimeStepHour:
        return NSLocalizedString(@"hour", @"short abbreviation for hour");
      case EOTimeStepMinute:
        return NSLocalizedString(@"min", @"short abbreviation for minute");
      case EOTimeStepSecond:
        return NSLocalizedString(@"sec", @"short abbreviation for second (the time unit)");
      default:
        ESAssert(false);
        return @"";
    }
}

- (NSString *)stepLabel {
    return [NSString stringWithFormat:NSLocalizedString(@"1 %@", @"the pair's label: one unit, e.g. '1 day' (%@ is the unit abbreviation)"),
                     [EOTimeStepper labelForUnit:unit]];
}

- (NSString *)statusString {
    if (scrubState == EOTimeScrubHeld) {
        NSString *rate = [NSString stringWithFormat:NSLocalizedString(@"%d %@/s", @"scrub rate, e.g. '20 day/s' (%d is the rate, %@ the unit abbreviation)"),
                                   ticksPerSecond, [EOTimeStepper labelForUnit:unit]];
        return [NSString stringWithFormat:@"%@ %@", rate, scrubDirection > 0 ? @"▶" : @"◀"];
    }
    if (time->isStopped()) {
        return NSLocalizedString(@"Stopped", @"status line: the displayed time is frozen");
    }
    double warp = time->warp();
    if (warp == 1.0) {
        if (time->isCorrect()) {
            return [NSString stringWithFormat:@"1× (%@)", NSLocalizedString(@"real time", @"status line: the clock shows the present, as in '1× (real time)'")];
        }
        return @"1×";
    }
    if (warp == -1.0) {
        return @"1× ◀";
    }
    return [NSString stringWithUTF8String:time->representationOfWarp().c_str()];
}

- (void)selectUnit:(EOTimeStepUnit)newUnit {
    ESAssert(newUnit >= 0 && newUnit < EOTimeStepNumUnits);
    if (newUnit == unit) {
        return;
    }
    [self endPress];
    unit = newUnit;
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithUTF8String:unitKeys[unit]] forKey:EOTimeStepUnitDefaultsKey];
}

// The same jumps the old row of buttons made; DST days, month ends and Feb 29 are the
// ESWatchTime methods' business, as before
- (void)advanceOneUnitInDirection:(int)direction {
    switch (unit) {
      case EOTimeStepCentury:
        time->advanceByYears(100 * direction, env);
        break;
      case EOTimeStepYear:
        time->advanceByYears(direction, env);
        break;
      case EOTimeStepMonth:
        time->advanceByMonths(direction, env);
        break;
      case EOTimeStepDay:
        time->advanceByDays(direction, env);
        break;
      case EOTimeStepHour:
        time->advanceBySeconds(3600 * direction);
        break;
      case EOTimeStepMinute:
        time->advanceBySeconds(60 * direction);
        break;
      case EOTimeStepSecond:
        time->advanceBySeconds(direction);
        break;
      default:
        ESAssert(false);
    }
}

- (void)stepInDirection:(int)direction {
    ESAssert(direction == 1 || direction == -1);
    time->stop();     // every step freezes the clock, as the old row's buttons did
    [self advanceOneUnitInDirection:direction];
    [client timeDidChange];
}

- (void)pressInDirection:(int)direction {
    [self endPress];  // a second finger, or a press whose release never came
    [self stepInDirection:direction];
    scrubDirection = direction;
    scrubState = EOTimeScrubPending;
    holdTimer = [NSTimer scheduledTimerWithTimeInterval:EOHoldDelay target:self selector:@selector(holdTimerFired:) userInfo:nil repeats:NO];
}

- (void)holdTimerFired:(NSTimer *)timer {
    holdTimer = nil;
    if (scrubState != EOTimeScrubPending) {
        return;
    }
    scrubState = EOTimeScrubHeld;
}

- (void)endPress {
    if (holdTimer) {
        [holdTimer invalidate];
        holdTimer = nil;
    }
    bool wasScrubbing = (scrubState == EOTimeScrubHeld);
    scrubState = EOTimeScrubIdle;
    if (wasScrubbing) {
        // The scrub moved a frozen clock by jumps, so there is nothing to stop; the views
        // re-arm their schedules from where it ended
        [client transportDidChange];
    }
}

- (bool)isScrubbing {
    return scrubState == EOTimeScrubHeld;
}

- (void)scrubTick {
    if (scrubState == EOTimeScrubHeld) {
        [self stepInDirection:scrubDirection];
    }
}

- (void)now {
    [self endPress];
    time->resetToLocal();
    [client transportDidChange];
}

@end
