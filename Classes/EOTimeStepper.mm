//
//  EOTimeStepper.mm
//  Emerald Observatory
//
//  See EOTimeStepper.h.
//

#import "EOTimeStepper.h"
#import "Constants.h"
#import "ESWatchTime.hpp"
#import "ESTimeLocAstroEnvironment.hpp"
#import "ESAstronomy.hpp"
#import "ESErrorReporter.hpp"

#include <math.h>

// A press becomes a scrub after this long.  The scrub then moves one unit per clock tick, as the
// old row of buttons did: the display shows each position as a jump, with no motion in between,
// so a slower cadence only looks choppier (the web app's ten a second rides on its animation).
static const NSTimeInterval EOHoldDelay = 0.3;

static NSString * const EOTimeStepUnitDefaultsKey = @"EOTimeStepUnit";
static NSString * const EOTimeStepBodyDefaultsKey = @"EOTimeStepBody";

// The persisted form of each unit (the web app's keys, so the two apps' settings read alike)
static const char *unitKeys[EOTimeStepNumUnits] = { "cent", "yr", "mo", "day", "hr", "min", "sec", "rise", "set", "transit", "phase" };

// The bodies the ‹ › row steps through, in the web app's order (Earth has no rising or setting)
static const int bodyPlanets[] = { ECPlanetSun, ECPlanetMoon, ECPlanetMercury, ECPlanetVenus, ECPlanetMars, ECPlanetJupiter, ECPlanetSaturn, ECPlanetUranus, ECPlanetNeptune };
static const int numBodies = sizeof(bodyPlanets) / sizeof(bodyPlanets[0]);

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

+ (bool)unitIsAstro:(EOTimeStepUnit)aUnit {
    return aUnit >= EOTimeStepFirstAstro && aUnit < EOTimeStepNumUnits;
}

+ (bool)unitUsesBody:(EOTimeStepUnit)aUnit {
    return aUnit == EOTimeStepRise || aUnit == EOTimeStepSet || aUnit == EOTimeStepTransit;
}

- (id)initWithWatchTime:(ESWatchTime *)aTime env:(ESTimeLocAstroEnvironment *)anEnv client:(id<EOTimeStepperClient>)aClient ticksPerSecond:(int)aTicksPerSecond {
    if ((self = [super init])) {
        time = aTime;
        env = anEnv;
        client = aClient;
        ticksPerSecond = aTicksPerSecond;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        unit = [EOTimeStepper unitForKey:[defaults stringForKey:EOTimeStepUnitDefaultsKey]];
        body = [defaults objectForKey:EOTimeStepBodyDefaultsKey] ? (int)[defaults integerForKey:EOTimeStepBodyDefaultsKey] : -1;
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
      case EOTimeStepRise:
        return NSLocalizedString(@"rise", @"chip: the rising of a body, as in sunrise or moonrise");
      case EOTimeStepSet:
        return NSLocalizedString(@"set", @"chip: the setting of a body, as in sunset (not the verb 'Set', which is its own key)");
      case EOTimeStepTransit:
        return NSLocalizedString(@"transit", @"chip: a body crossing the meridian");
      case EOTimeStepPhase:
        return NSLocalizedString(@"phase", @"short abbreviation for phase of the Moon");
      default:
        ESAssert(false);
        return @"";
    }
}

- (NSString *)stepLabelWithBodyName:(NSString *)bodyName {
    int planet = [self bodyPlanetNumber];
    switch (unit) {
      case EOTimeStepRise:
        if (planet == ECPlanetSun) {
            return NSLocalizedString(@"Sunrise", @"the pair's label: step to the Sun's rising");
        }
        if (planet == ECPlanetMoon) {
            return NSLocalizedString(@"Moonrise", @"the pair's label: step to the Moon's rising");
        }
        return [NSString stringWithFormat:NSLocalizedString(@"%@ rise", @"the pair's label: step to a planet's rising, e.g. 'Jupiter rise'"), bodyName];
      case EOTimeStepSet:
        if (planet == ECPlanetSun) {
            return NSLocalizedString(@"Sunset", @"the pair's label: step to the Sun's setting");
        }
        if (planet == ECPlanetMoon) {
            return NSLocalizedString(@"Moonset", @"the pair's label: step to the Moon's setting");
        }
        return [NSString stringWithFormat:NSLocalizedString(@"%@ set", @"the pair's label: step to a planet's setting, e.g. 'Jupiter set'"), bodyName];
      case EOTimeStepTransit:
        return [NSString stringWithFormat:NSLocalizedString(@"%@ transit", @"the pair's label: step to a body's meridian crossing, e.g. 'Jupiter transit'"), bodyName];
      case EOTimeStepPhase:
        return NSLocalizedString(@"Moon phase", @"the pair's label: step to the Moon's next quarter");
      default:
        return [NSString stringWithFormat:NSLocalizedString(@"1 %@", @"the pair's label: one unit, e.g. '1 day' (%@ is the unit abbreviation)"),
                         [EOTimeStepper labelForUnit:unit]];
    }
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

//// the body

- (int)bodyPlanetNumber {
    if (body >= 0) {
        return body;
    }
    return [client dialPlanetNumber];
}

- (void)stepBody:(int)direction {
    int current = [self bodyPlanetNumber];
    int index = 0;
    for (int i = 0; i < numBodies; i++) {
        if (bodyPlanets[i] == current) {
            index = i;
            break;
        }
    }
    index = (index + direction + numBodies) % numBodies;
    body = bodyPlanets[index];
    [[NSUserDefaults standardUserDefaults] setInteger:body forKey:EOTimeStepBodyDefaultsKey];
}

//// stepping

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
    ESAssert(![EOTimeStepper unitIsAstro:unit]);
    time->stop();     // every step freezes the clock, as the old row's buttons did
    [self advanceOneUnitInDirection:direction];
    [client timeDidChange];
}

// An astronomical event: search from the frozen time for the next (or previous) one and jump
// to it.  The clock is stopped first, and deliberately: the library's "previous" searches read
// their direction from the watch, and a stopped watch is never running backward.  As the old
// phase buttons did, the search runs inside the astronomy manager's environment bracket.
- (bool)astroJumpInDirection:(int)direction {
    ESAssert(direction == 1 || direction == -1);
    time->stop();
    ESAstronomyManager *astro = env->astronomyManager();
    astro->setupLocalEnvironmentForThreadFromActionButton(false, time);
    int planet = [self bodyPlanetNumber];
    ESTimeInterval target;
    switch (unit) {
      case EOTimeStepRise:
        target = direction > 0 ? astro->nextPlanetriseForPlanetNumber(planet) : astro->prevPlanetriseForPlanetNumber(planet);
        break;
      case EOTimeStepSet:
        target = direction > 0 ? astro->nextPlanetsetForPlanetNumber(planet) : astro->prevPlanetsetForPlanetNumber(planet);
        break;
      case EOTimeStepTransit:
        target = direction > 0 ? astro->nextPlanettransit(planet) : astro->prevPlanettransit(planet);
        break;
      case EOTimeStepPhase:
        target = direction > 0 ? astro->nextMoonPhase() : astro->prevMoonPhase();
        break;
      default:
        ESAssert(false);
        target = nan("");
    }
    astro->cleanupLocalEnvironmentForThreadFromActionButton(false);
    if (isnan(target)) {
        return false;     // no such event here: a polar day or night, a body that never rises or sets
    }
    time->setToFrozenDateInterval(target);
    [client timeDidChange];
    return true;
}

- (bool)pressInDirection:(int)direction {
    [self endPress];  // a second finger, or a press whose release never came
    if ([EOTimeStepper unitIsAstro:unit]) {
        return [self astroJumpInDirection:direction];    // tap-only: each tap is a search, so there is nothing to hold
    }
    [self stepInDirection:direction];
    scrubDirection = direction;
    scrubState = EOTimeScrubPending;
    holdTimer = [NSTimer scheduledTimerWithTimeInterval:EOHoldDelay target:self selector:@selector(holdTimerFired:) userInfo:nil repeats:NO];
    return true;
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

//// the transport

- (void)stop {
    [self endPress];
    time->stop();
    [client transportDidChange];
}

- (void)play {
    [self endPress];
    time->setWarp(1.0);   // not start(): that would resume at whatever speed preceded the freeze
    [client transportDidChange];
}

- (void)playReverse {
    [self endPress];
    time->setWarp(-1.0);
    [client transportDidChange];
}

- (void)now {
    [self endPress];
    time->resetToLocal();
    [client transportDidChange];
}

- (bool)isRunning {
    return !time->isStopped();
}

- (bool)isAtPresent {
    return time->isCorrect();
}

@end
