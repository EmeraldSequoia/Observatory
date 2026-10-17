//
//  EOTimeControllerView.h
//  Emerald Observatory
//
//  The time controller: four blocks that cover the four small dials while Set mode is open (Now,
//  the drive ◀ ‖ ▶, the mode dial with its body, and the ◀ ▶ pair: tap to step, hold to scrub,
//  lift off to run hands-free), and the odometer along the top, which replaces the old strip:
//  wheels for the displayed date and time, rolled by a drag or typed into, over a line with the
//  clock's status, its distance from the present, the zone and the location.  The odometer shows
//  whenever the strip did (EOClock's timeStripVisible), open or not; it takes touches only while
//  the controller is open.
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

// The odometer, in canvas units: the wheels' line, then the info line, with EOOdometerButtonsWidth kept
// clear at the first line's right end for EOClock's Set / Done and Now
static const double EOOdometerWidth = 460;
static const double EOOdometerHeight = 52;
static const double EOOdometerRowHeight = 34;
static const double EOOdometerButtonsWidth = 154;

@interface EOTimeControllerView : UIView <UIGestureRecognizerDelegate, UITextFieldDelegate> {
    EOTimeStepper  *stepper;        // EOClock's; not retained
    EOClock        *clock;          // not retained
    UIView         *nowBlock;       // over the altitude dial: Now ▶
    UIView         *driveBlock;     // over the azimuth dial: ◀ ‖ ▶
    UIView         *modeBlock;      // over the eclipse dial: the mode dial
    UIView         *stepBlock;      // over the equation-of-time dial: the pair
    UIView         *odometer;
    UIButton       *nowButton;
    UIButton       *reverseButton;
    UIButton       *pauseButton;
    UIButton       *playButton;
    EOTimeModeDial *modeDial;
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
    UILabel        *infoLabel;      // the odometer's second line
    bool           open;            // the blocks show
    bool           landscape;       // the blocks' shape
    EOTimeStepUnit shownUnit;       // the dial's unit as last drawn
    int            shownBody;       // and its body
    int            shownHeld;       // 0, or the direction of the pair button drawn as held
    int            shownBadge;      // the padlock as drawn: 0 none, 1 the lock zone, 2 locked
    bool           offButton;       // the pair's touch has left its button: a lift now would lock
    int            shownDrive;      // the drive as last drawn: 0 stopped, 1 forward, -1 backward
    bool           shownAtPresent;  // Now as last drawn
    bool           faded;           // the scrub fade is on
    bool           shownBCE;        // the era wheel as drawn
    double         rollCarry;       // a wheel drag's travel not yet turned into notches
}

@property (readonly) UIView *nowBlock;
@property (readonly) UIView *driveBlock;
@property (readonly) UIView *modeBlock;
@property (readonly) UIView *stepBlock;
@property (readonly) UIView *odometer;

- (id)initWithStepper:(EOTimeStepper *)aStepper clock:(EOClock *)aClock;

// The blocks' shape for the orientation, before EOClock centres them over the dials: a tall block
// in landscape, where each side's two dials stack in a column, a square in portrait's corners
- (void)layoutForLandscape:(bool)isLandscape;

// Set mode: the blocks show, and the odometer takes touches
- (void)setOpen:(bool)isOpen;

// The odometer's second line, from EOClock's strip
- (void)setInfoText:(NSString *)text color:(UIColor *)color;

// Once per clock tick while the odometer or the blocks show
- (void)refresh;

// Before the blocks are hidden: a hidden view never gets the release that would end a scrub
- (void)prepareToHide;

@end
