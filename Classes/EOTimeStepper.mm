//
//  EOTimeStepper.mm
//  Emerald Observatory
//
//  See EOTimeStepper.h.
//

#import "EOTimeStepper.h"
#import "Constants.h"
#import "ESWatchTime.hpp"
#import "ESTime.hpp"
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

+ (NSString *)dialLabelForUnit:(EOTimeStepUnit)aUnit {
    switch (aUnit) {
      case EOTimeStepCentury:
        return NSLocalizedString(@"Century", @"mode dial: step by a century");
      case EOTimeStepYear:
        return NSLocalizedString(@"Year", @"mode dial: step by a year");
      case EOTimeStepMonth:
        return NSLocalizedString(@"Month", @"mode dial: step by a month");
      case EOTimeStepDay:
        return NSLocalizedString(@"Day", @"mode dial: step by a day");
      case EOTimeStepHour:
        return NSLocalizedString(@"Hour", @"mode dial: step by an hour");
      case EOTimeStepMinute:
        return NSLocalizedString(@"Minute", @"mode dial: step by a minute");
      case EOTimeStepSecond:
        return NSLocalizedString(@"Second", @"mode dial: step by a second (the time unit)");
      case EOTimeStepRise:
        return NSLocalizedString(@"Rise", @"mode dial: step to a body's rising");
      case EOTimeStepSet:
        return NSLocalizedString(@"Set (of a body)", @"mode dial: step to a body's setting (not the verb 'Set', which is its own key)");
      case EOTimeStepTransit:
        return NSLocalizedString(@"Transit", @"mode dial: step to a body's crossing of the meridian");
      case EOTimeStepPhase:
        return NSLocalizedString(@"Phase", @"mode dial: step to the Moon's next quarter");
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
      case EOTimeStepCentury:
        return NSLocalizedString(@"1 century", @"the pair's label: step by one century");
      case EOTimeStepYear:
        return NSLocalizedString(@"1 year", @"the pair's label: step by one year");
      case EOTimeStepMonth:
        return NSLocalizedString(@"1 month", @"the pair's label: step by one month");
      case EOTimeStepDay:
        return NSLocalizedString(@"1 day", @"the pair's label: step by one day");
      case EOTimeStepHour:
        return NSLocalizedString(@"1 hour", @"the pair's label: step by one hour");
      case EOTimeStepMinute:
        return NSLocalizedString(@"1 minute", @"the pair's label: step by one minute");
      case EOTimeStepSecond:
        return NSLocalizedString(@"1 second", @"the pair's label: step by one second");
      default:
        ESAssert(false);
        return @"";
    }
}

- (NSString *)statusString {
    if ([self isScrubbing]) {
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
    [self selectBody:bodyPlanets[index]];
}

- (void)selectBody:(int)planetNumber {
    body = planetNumber;
    [[NSUserDefaults standardUserDefaults] setInteger:body forKey:EOTimeStepBodyDefaultsKey];
}

+ (int)numBodies {
    return numBodies;
}

+ (int)bodyAtIndex:(int)index {
    ESAssert(index >= 0 && index < numBodies);
    return bodyPlanets[index];
}

//// stepping

// The same jumps the old row of buttons made; DST days, month ends and Feb 29 are the
// ESWatchTime methods' business, as before
- (void)advanceUnit:(EOTimeStepUnit)aUnit inDirection:(int)direction {
    switch (aUnit) {
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
    [self advanceUnit:unit inDirection:direction];
    [client timeDidChange];
}

- (void)rollUnit:(EOTimeStepUnit)aUnit inDirection:(int)direction {
    ESAssert(direction == 1 || direction == -1);
    ESAssert(![EOTimeStepper unitIsAstro:aUnit]);
    [self endPress];
    time->stop();
    [self advanceUnit:aUnit inDirection:direction];
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
        if (![self astroJumpInDirection:direction]) {
            return false;   // no such event here: nothing to hold for
        }
    } else {
        [self stepInDirection:direction];
    }
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
    bool wasScrubbing = [self isScrubbing];
    scrubState = EOTimeScrubIdle;
    if (wasScrubbing) {
        // The scrub moved a frozen clock by jumps, so there is nothing to stop; the views
        // re-arm their schedules from where it ended
        [client transportDidChange];
    }
}

// The latch: the hold engaged and the finger lifted off the button, so the scrub runs on hands-free
- (void)lockScrub {
    if (scrubState == EOTimeScrubHeld) {
        scrubState = EOTimeScrubLocked;
    }
}

- (bool)isScrubbing {
    return scrubState == EOTimeScrubHeld || scrubState == EOTimeScrubLocked;
}

- (bool)isLocked {
    return scrubState == EOTimeScrubLocked;
}

- (void)scrubTick {
    if (![self isScrubbing]) {
        return;
    }
    if ([EOTimeStepper unitIsAstro:unit]) {
        if (![self astroJumpInDirection:scrubDirection]) {
            [self endPress];    // the events have run out (a polar day or night)
        }
    } else {
        [self stepInDirection:scrubDirection];
    }
}

//// the transport

- (void)stop {
    [self endPress];
    time->stop();
    [client transportDidChange];
}

- (void)togglePause {
    if (!time->isStopped()) {
        [self stop];
    } else if (time->lastMotionWasInReverse()) {
        [self playReverse];
    } else {
        [self play];
    }
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

- (int)runDirection {
    if (time->isStopped()) {
        return 0;
    }
    return time->warp() < 0 ? -1 : 1;
}

- (bool)isAtPresent {
    return time->isCorrect();
}

- (double)offsetFromPresent {
    return time->currentTime() - ESTime::currentTime();
}

// The displayed time's offset from the real time, signed (+ ahead, − behind), in its two largest units, each
// pluralized as the language does it (Localizable.stringsdict): "+3 days 4 hours", "−1 minute 5 seconds";
// years of 365.2425 days.  Nothing at the present.
static NSString *offsetPart(int unit, long count) {
    NSString *format;
    switch (unit) {
      case 0:
        format = NSLocalizedString(@"offset years", @"the clock's offset from real time: a number of years (plural rules in Localizable.stringsdict)");
        break;
      case 1:
        format = NSLocalizedString(@"offset days", @"the clock's offset from real time: a number of days (plural rules in Localizable.stringsdict)");
        break;
      case 2:
        format = NSLocalizedString(@"offset hours", @"the clock's offset from real time: a number of hours (plural rules in Localizable.stringsdict)");
        break;
      case 3:
        format = NSLocalizedString(@"offset minutes", @"the clock's offset from real time: a number of minutes (plural rules in Localizable.stringsdict)");
        break;
      default:
        format = NSLocalizedString(@"offset seconds", @"the clock's offset from real time: a number of seconds (plural rules in Localizable.stringsdict)");
        break;
    }
    return [NSString localizedStringWithFormat:format, count];
}

- (NSString *)offsetString {
    double offset = round([self offsetFromPresent]);
    if ([self isAtPresent] || offset == 0) {
        return @"";
    }
    double rest = fabs(offset);
    double sizes[5] = { 365.2425 * 86400, 86400, 3600, 60, 1 };     // years, days, hours, minutes, seconds
    long counts[5];
    for (int i = 0; i < 5; i++) {
        counts[i] = (long)floor(rest / sizes[i]);
        rest -= counts[i] * sizes[i];
    }
    int first = 0;
    while (first < 4 && counts[first] == 0) {
        first++;
    }
    NSString *text = [NSString stringWithFormat:@"%@%@", offset > 0 ? @"+" : @"\u2212", offsetPart(first, counts[first])];
    if (first < 4 && counts[first + 1] != 0) {
        text = [NSString stringWithFormat:@"%@ %@", text, offsetPart(first + 1, counts[first + 1])];
    }
    return text;
}

//// the date fields

- (void)dateComponents:(ESDateComponents *)cs {
    ESCalendar_localDateComponentsFromTimeInterval(time->currentTime(), env->estz(), cs);
}

static int clampInt(int value, int low, int high) {
    return value < low ? low : (value > high ? high : value);
}

// A typed date and time, in the clock's zone through the hybrid calendar (Julian before 1582-10-15),
// at the zone's offset for that instant.  Outside the range the astronomy supports
// (4000 BCE to 2801 CE) the time is clamped to the range's end, and the clock freezes there as it does
// anywhere.
- (bool)setEra:(int)era year:(int)year month:(int)month day:(int)day hour:(int)hour minute:(int)minute second:(int)second {
    [self endPress];
    ESDateComponents cs;
    cs.era = era ? 1 : 0;
    cs.year = clampInt(year, 1, 9999);
    cs.month = clampInt(month, 1, 12);
    cs.day = clampInt(day, 1, 31);
    cs.hour = clampInt(hour, 0, 23);
    cs.minute = clampInt(minute, 0, 59);
    cs.seconds = clampInt(second, 0, 59);
    ESTimeInterval target = ESCalendar_timeIntervalFromLocalDateComponents(env->estz(), &cs);
    bool inRange = true;
    if (target < ESMinimumSupportedAstroDate) {
        target = ESMinimumSupportedAstroDate;
        inRange = false;
    } else if (target > ESMaximumSupportedAstroDate) {
        target = ESMaximumSupportedAstroDate;
        inRange = false;
    }
    time->setToFrozenDateInterval(target);
    [client timeDidChange];
    return inRange;
}

- (bool)isAtLimit {
    ESTimeInterval t = time->currentTime();
    return t <= ESMinimumSupportedAstroDate || t >= ESMaximumSupportedAstroDate;
}

@end
