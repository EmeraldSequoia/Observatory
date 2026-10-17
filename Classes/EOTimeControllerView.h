//
//  EOTimeControllerView.h
//  Emerald Observatory
//
//  The time controller: four blocks that cover the four small dials while Set mode is open (the
//  clock's status over Now, the drive ◀ ‖ ▶, the mode dial, and the ◀ ▶ pair: tap to step, hold to
//  scrub, lift off to run hands-free; ringed by the bodies for rise / set / transit), and the odometer
//  along the top, which replaces
//  the old strip: wheels for the displayed date and time, each rolled by a vertical drag, and a
//  keyboard switch that, while on, turns them into fields to type into instead.  The blocks and the
//  odometer show only while the controller is open, swelling out of Set / Done as it opens and
//  settling back into it as it closes, as the location picker's map does.
//
//  The view itself spans the canvas and takes no touches; EOClock places its blocks where the
//  dials are and its odometer where the strip goes (moveClockWidgetsForOrientation:), with
//  reorientSubView: like every other widget.  It drives an EOTimeStepper and reads it back once
//  per clock tick (refresh).
//
//  Design: chronometer-web planning/2026-09-25-ios-backport-observatory-time-controller.md
//

#import <UIKit/UIKit.h>
#import "EOTimeStepper.h"

@class EOClock;
@class EOTimeModeDial;
@class EOTimeBodyRing;

// The odometer, in canvas units: one line of wheels, with EOOdometerButtonsWidth kept clear at its right
// end for EOClock's Set / Done and, beside it, Now (closed) or the keyboard button (open)
static const double EOOdometerWidth = 460;
static const double EOOdometerHeight = 38;
static const double EOOdometerButtonsWidth = 154;

@interface EOTimeControllerView : UIView <UIGestureRecognizerDelegate, UITextFieldDelegate> {
    EOTimeStepper  *stepper;        // EOClock's; not retained
    EOClock        *clock;          // not retained
    UIView         *nowBlock;       // over the altitude dial: the status, and Now
    UIView         *driveBlock;     // over the azimuth dial: ◀ ‖ ▶
    UIView         *modeBlock;      // over the eclipse dial: the mode dial
    UIView         *stepBlock;      // over the equation-of-time dial: the pair
    UIView         *odometer;
    UILabel        *statusLabel;
    UIButton       *nowButton;
    UIButton       *reverseButton;
    UIButton       *pauseButton;
    UIButton       *playButton;
    EOTimeModeDial *modeDial;
    EOTimeBodyRing *bodyRing;       // around the pair, for rise / set / transit
    bool           ringShown;
    UIButton       *backButton;
    UIButton       *forwardButton;
    UILabel        *stepLabel;
    UIImageView    *padlock;        // the hands-free tell, over the pair (see refresh)
    UIButton       *eraButton;      // the odometer's wheels: era, year, month, day, hour, minute, second
    UITextField    *yearField;
    UITextField    *monthField;
    UITextField    *dayField;
    UITextField    *hourField;
    UITextField    *minuteField;
    UITextField    *secondField;
    UIButton       *keyboardButton; // the odometer's switch: type the date and time instead of rolling it
    bool           entering;        // the switch is on: the wheels are fields (keyboardTapped:)
    bool           open;            // the blocks show
    bool           landscape;       // the blocks' shape
    EOTimeStepUnit shownUnit;       // the dial's unit as last drawn
    int            shownBody;       // the ring's body as last drawn
    int            shownHeld;       // 0, or the direction of the pair button drawn as held
    int            shownBadge;      // the padlock as drawn: 0 none, 1 the lock zone, 2 locked
    bool           offButton;       // the pair's touch has left its button: a lift now would lock
    int            shownDrive;      // the drive as last drawn: 0 stopped, 1 forward, -1 backward
    bool           shownAtPresent;  // Now as last drawn
    bool           faded;           // the scrub fade is on
    bool           shownBCE;        // the era wheel as drawn
    double         rollCarry;       // a wheel drag's travel not yet turned into notches
    CADisplayLink  *shrinkLink;     // while closing: fades each view out near the end of its shrink (shrinkStep)
    CGRect         shrinkTarget;    // the rect they shrink into
}

@property (readonly) UIView *nowBlock;
@property (readonly) UIView *driveBlock;
@property (readonly) UIView *modeBlock;
@property (readonly) UIView *stepBlock;
@property (readonly) UIView *odometer;

- (id)initWithStepper:(EOTimeStepper *)aStepper clock:(EOClock *)aClock;

// The Now buttons' icon (nowLive.png: a clock, broadcasting, "LIVE"), drawn at the given size in canvas units
// and fine enough for the canvas's scaling; a template, so it takes the button's tint
+ (UIImage *)nowIconOfSize:(double)size;

// The blocks' shape for the orientation, before EOClock centres them over the dials: a tall block
// in landscape, where each side's two dials stack in a column, a square in portrait's corners
- (void)layoutForLandscape:(bool)isLandscape;

// Set mode: the blocks and the odometer swell out of the given rect (Set / Done's frame) or settle back into it
- (void)setOpen:(bool)isOpen fromRect:(CGRect)source;

// Once per clock tick while the odometer or the blocks show
- (void)refresh;

// Before the blocks are hidden: a hidden view never gets the release that would end a scrub
- (void)prepareToHide;

@end
