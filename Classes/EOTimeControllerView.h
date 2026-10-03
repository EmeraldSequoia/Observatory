//
//  EOTimeControllerView.h
//  Emerald Observatory
//
//  The time controller panel: the unit chips, the ‹ Body › row for the rise /
//  set / transit events, the ◀ ▶ pair (tap to step, hold to scrub), the
//  transport row and the status line.  It drives an EOTimeStepper and reads
//  it back once per clock tick (refresh).  Laid out in canvas units like the
//  rest of the clock; opens at the lower right and can be dragged from its
//  captions or background.
//
//  Design: chronometer-web planning/2026-09-25-ios-backport-observatory-time-controller.md
//

#import <UIKit/UIKit.h>
#import "EOTimeStepper.h"

@class EOClock;

@interface EOTimeControllerView : UIView <UIGestureRecognizerDelegate> {
    EOTimeStepper  *stepper;        // EOClock's; not retained
    EOClock        *clock;          // not retained
    UIButton       *nowButton;      // Now ▶, while the time is not the present
    UIButton       *pauseButton;    // ‖, while the clock runs
    UIButton       *reverseButton;  // ◀ ▶, while it is stopped
    UIButton       *playButton;
    UIButton       *closeButton;
    UILabel        *statusLabel;
    UILabel        *stepByLabel;
    UIButton       *chips[EOTimeStepNumUnits];
    UIButton       *bodyPrevButton;
    UILabel        *bodyLabel;
    UIButton       *bodyNextButton;
    UIButton       *backButton;
    UIButton       *forwardButton;
    UILabel        *stepLabel;
    bool           bodyRowShown;    // the ‹ Body › row is laid out (rise / set / transit only)
    EOTimeStepUnit shownUnit;       // the chip currently drawn as selected
    int            shownHeld;       // 0, or the direction of the pair button drawn as held
    bool           shownAtPresent;  // the transport row as last laid out: Now hidden, and
    bool           shownRunning;    // ‖ rather than ◀ ▶
    bool           faded;           // the scrub fade is on
    bool           userMoved;       // the user dragged the panel: offset is theirs, not the corner's
    CGPoint        offset;          // the panel's centre relative to the clock centre, y up, canvas units
    CGPoint        clockCenter;     // the last placement's parameters, for re-clamping after a drag
    double         halfWidth;
    double         halfHeight;
}

- (id)initWithStepper:(EOTimeStepper *)aStepper clock:(EOClock *)aClock;

// Put the panel at its corner (or where the user dragged it), kept within the canvas of the
// given half-extents around the clock centre
- (void)placeWithClockCenter:(CGPoint)center halfWidth:(double)halfW halfHeight:(double)halfH;

// Once per clock tick while the panel is shown
- (void)refresh;

// Before the panel is hidden: a hidden view never gets the release that would end a scrub
- (void)prepareToHide;

@end
