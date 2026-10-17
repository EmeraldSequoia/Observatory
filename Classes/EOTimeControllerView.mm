//
//  EOTimeControllerView.mm
//  Emerald Observatory
//
//  See EOTimeControllerView.h.
//

#import "EOTimeControllerView.h"
#import "EOClock.h"
#import "Utilities.h"
#import <QuartzCore/QuartzCore.h>

// Geometry, in canvas units.  The blocks cover the small dials (radius 60, the eclipse ring 63) with their
// labels; landscape's are taller, each pair filling its side's column between the Moon or the map and the
// big date.
static const double portraitBlockWidth = 130;
static const double portraitBlockHeight = 130;
static const double landscapeBlockWidth = 170;
static const double landscapeBlockHeight = 215;
static const double blockPad = 8;
static const double blockRadius = 14;
static const double buttonRadius = 8;
static const double gap = 4;
static const double labelHeight = 18;           // the pair's label
static const double wheelGap = 4;               // between the wheels of a group
static const double groupGap = 14;              // between the date's wheels and the time's
static const double eraWidth = 40;
static const double yearWidth = 52;
static const double wheelWidth = 34;            // month, day, hour, minute, second
static const double notch = 20;                 // a wheel drag's travel per unit rolled
static const double statusHeight = 30;          // the status over Now: two lines, for a scrub at the limit
static const double scrubAlpha = 0.38;          // the blocks while a scrub runs (the web's tuned level)
static const NSTimeInterval fadeDuration = 0.15;
static const NSTimeInterval flashDuration = 0.3;    // a pair button after a search that found nothing
static const double lockBadgeSize = 56;             // the padlock (the web's #tp-lock-badge, to the block's size)
static const double lockZoneAlpha = 0.75;           // the padlock while a lift would lock
static const double lockedAlpha = 0.4;              // and once locked, over the faded blocks (the two multiply)

static UIColor *rgb(int r, int g, int b) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
}

// The looks a button can have: the web's .tp-btn, .tp-btn.holding, .tp-btn.flash-fail and .tp-btn.active
static void styleButton(UIButton *button, UIColor *background, UIColor *border, UIColor *text) {
    button.backgroundColor = background;
    button.layer.borderColor = border.CGColor;
    [button setTitleColor:text forState:UIControlStateNormal];
}

static void styleAsPlain(UIButton *button) {
    styleButton(button, rgb(0x2a, 0x2a, 0x3e), rgb(0x3a, 0x3a, 0x5e), rgb(0x99, 0x99, 0xbb));
}

static void styleAsHolding(UIButton *button) {
    styleButton(button, rgb(0x55, 0x55, 0x66), rgb(0x88, 0xaa, 0xff), rgb(0xcc, 0xcc, 0xff));
}

static void styleAsActive(UIButton *button) {     // the drive's current setting
    styleButton(button, rgb(0x44, 0x44, 0x55), rgb(0x88, 0xaa, 0xff), rgb(0x88, 0xaa, 0xff));
}

static void styleAsFailed(UIButton *button) {
    styleButton(button, rgb(0x44, 0x33, 0x22), rgb(0x77, 0x55, 0x44), rgb(0xaa, 0x88, 0x66));
}

static void styleAsEra(UIButton *button, bool bce) {     // the web's #tp-bce, and its .active: BCE in red
    if (bce) {
        styleButton(button, rgb(0x2a, 0x2a, 0x3e), rgb(0xaa, 0x44, 0x44), rgb(0xff, 0x44, 0x44));
    } else {
        styleButton(button, rgb(0x2a, 0x2a, 0x3e), rgb(0x3a, 0x3a, 0x5e), rgb(0x99, 0x99, 0xbb));
    }
}

// A wheel's two looks.  Rolling: a drum, shaded dark toward its top and bottom edges (the gradient is the
// field's first sublayer, under its text).  Typing, while the keyboard switch is on: a plain light field.
static void styleWheel(UITextField *field, bool typing) {
    CALayer *drum = [field.layer.sublayers objectAtIndex:0];
    drum.hidden = typing;
    if (typing) {
        field.backgroundColor = rgb(0xee, 0xee, 0xf4);
        field.textColor = rgb(0x11, 0x11, 0x22);
        field.layer.borderWidth = 2;
        field.layer.borderColor = rgb(0x88, 0xaa, 0xff).CGColor;
        field.layer.cornerRadius = 4;
    } else {
        field.backgroundColor = rgb(0x30, 0x30, 0x40);
        field.textColor = rgb(0xee, 0xee, 0xee);
        field.layer.borderWidth = 0;
        field.layer.cornerRadius = 2;
    }
}

// Write a label or a field only when its text changes: refresh runs twenty times a second
static void setLabelText(UILabel *label, NSString *text) {
    if (![label.text isEqualToString:text]) {
        label.text = text;
    }
}

static void setFieldText(UITextField *field, NSString *text) {
    if (![field.text isEqualToString:text]) {
        field.text = text;
    }
}

//// The mode dial: a rotary switch with a position per unit around its rim, clockwise from the top.  A touch
//// on the rim turns the pointer to the nearest position, and a drag around it keeps turning; the hub shows
//// the body for rise / set / transit, and a tap on its left or right half steps it back or on.

@interface EOTimeControllerView (ModeDial)
- (void)dialSelectedUnit:(EOTimeStepUnit)unit;
- (void)dialSteppedBody:(int)direction;
@end

@interface EOTimeModeDial : UIView {
    EOTimeControllerView *controller;   // not retained: our superview's superview
    EOTimeStepUnit       unit;
    NSString             *bodyName;
    bool                 hubTouch;      // the touch began on the hub
}
- (id)initWithController:(EOTimeControllerView *)aController;
- (void)setUnit:(EOTimeStepUnit)aUnit bodyName:(NSString *)aBodyName;
@end

@implementation EOTimeModeDial

- (id)initWithController:(EOTimeControllerView *)aController {
    if ((self = [super initWithFrame:CGRectZero])) {
        controller = aController;
        unit = EOTimeStepDay;
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)dealloc {
    [bodyName release];
    [super dealloc];
}

- (void)setUnit:(EOTimeStepUnit)aUnit bodyName:(NSString *)aBodyName {
    unit = aUnit;
    [bodyName release];
    bodyName = [aBodyName copy];
    [self setNeedsDisplay];
}

- (CGPoint)hub {
    return CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
}

- (double)rimRadius {
    return fmin(self.bounds.size.width, self.bounds.size.height) / 2 - 1;
}

- (double)hubRadius {
    return [self rimRadius] * 0.42;
}

static double angleForPosition(int i) {
    return i * 2 * M_PI / EOTimeStepNumUnits;
}

- (void)drawRect:(CGRect)rect {
    CGPoint hub = [self hub];
    double rim = [self rimRadius];
    double labelRadius = rim - rim * 0.17;

    UIBezierPath *ring = [UIBezierPath bezierPathWithArcCenter:hub radius:rim - 0.5 startAngle:0 endAngle:2 * M_PI clockwise:YES];
    [rgb(0x22, 0x22, 0x38) setFill];
    [ring fill];
    [rgb(0x3a, 0x3a, 0x5e) setStroke];
    ring.lineWidth = 1;
    [ring stroke];

    // The pointer, under the labels
    double angle = angleForPosition(unit);
    UIBezierPath *pointer = [UIBezierPath bezierPath];
    [pointer moveToPoint:hub];
    [pointer addLineToPoint:CGPointMake(hub.x + (labelRadius - rim * 0.13) * sin(angle), hub.y - (labelRadius - rim * 0.13) * cos(angle))];
    pointer.lineWidth = 3;
    pointer.lineCapStyle = kCGLineCapRound;
    [rgb(0x88, 0xaa, 0xff) setStroke];
    [pointer stroke];

    // The positions' labels, each shrunk to its share of the rim
    double slot = 2 * M_PI * labelRadius / EOTimeStepNumUnits;
    for (int i = 0; i < EOTimeStepNumUnits; i++) {
        NSString *label = [EOTimeStepper labelForUnit:(EOTimeStepUnit)i];
        UIColor *color = (i == unit) ? rgb(0xcc, 0xcc, 0xff) : ([EOTimeStepper unitIsAstro:(EOTimeStepUnit)i] ? rgb(0x7a, 0x8a, 0xa8) : rgb(0x88, 0x88, 0x99));
        double size = rim * 0.15;
        NSDictionary *attributes;
        CGSize extent;
        do {
            attributes = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont fontWithName:(i == unit ? @"Arial-BoldMT" : @"Arial") size:size], NSFontAttributeName,
                                       color, NSForegroundColorAttributeName, nil];
            extent = [label sizeWithAttributes:attributes];
            size -= 0.5;
        } while (extent.width > slot * 0.92 && size > 6);
        CGPoint center = CGPointMake(hub.x + labelRadius * sin(angleForPosition(i)), hub.y - labelRadius * cos(angleForPosition(i)));
        [label drawAtPoint:CGPointMake(center.x - extent.width / 2, center.y - extent.height / 2) withAttributes:attributes];
    }

    // The hub, with the body when the unit has one
    double hubR = [self hubRadius];
    UIBezierPath *hubPath = [UIBezierPath bezierPathWithArcCenter:hub radius:hubR startAngle:0 endAngle:2 * M_PI clockwise:YES];
    [rgb(0x2a, 0x2a, 0x3e) setFill];
    [hubPath fill];
    [rgb(0x3a, 0x3a, 0x5e) setStroke];
    hubPath.lineWidth = 1;
    [hubPath stroke];
    if ([EOTimeStepper unitUsesBody:unit] && bodyName) {
        double size = hubR * 0.42;
        NSDictionary *attributes;
        CGSize extent;
        do {
            attributes = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont fontWithName:@"Arial" size:size], NSFontAttributeName,
                                       rgb(0x88, 0xaa, 0xff), NSForegroundColorAttributeName, nil];
            extent = [bodyName sizeWithAttributes:attributes];
            size -= 0.5;
        } while (extent.width > hubR * 1.3 && size > 6);
        [bodyName drawAtPoint:CGPointMake(hub.x - extent.width / 2, hub.y - extent.height / 2) withAttributes:attributes];
        NSDictionary *arrows = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:hubR * 0.5], NSFontAttributeName,
                                             rgb(0x99, 0x99, 0xbb), NSForegroundColorAttributeName, nil];
        CGSize arrow = [@"‹" sizeWithAttributes:arrows];
        [@"‹" drawAtPoint:CGPointMake(hub.x - hubR * 0.88, hub.y - arrow.height / 2) withAttributes:arrows];
        [@"›" drawAtPoint:CGPointMake(hub.x + hubR * 0.88 - arrow.width, hub.y - arrow.height / 2) withAttributes:arrows];
    }
}

// The position nearest a point on the rim
- (EOTimeStepUnit)unitAtPoint:(CGPoint)point {
    CGPoint hub = [self hub];
    double angle = atan2(point.x - hub.x, hub.y - point.y);     // clockwise from the top
    if (angle < 0) {
        angle += 2 * M_PI;
    }
    int i = (int)lround(angle / (2 * M_PI / EOTimeStepNumUnits)) % EOTimeStepNumUnits;
    return (EOTimeStepUnit)i;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self];
    CGPoint hub = [self hub];
    hubTouch = hypot(point.x - hub.x, point.y - hub.y) <= [self hubRadius];
    if (!hubTouch) {
        [controller dialSelectedUnit:[self unitAtPoint:point]];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!hubTouch) {
        [controller dialSelectedUnit:[self unitAtPoint:[[touches anyObject] locationInView:self]]];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (hubTouch && [EOTimeStepper unitUsesBody:unit]) {
        CGPoint point = [[touches anyObject] locationInView:self];
        CGPoint hub = [self hub];
        if (hypot(point.x - hub.x, point.y - hub.y) <= [self hubRadius]) {
            [controller dialSteppedBody:(point.x < hub.x ? -1 : 1)];
        }
    }
    hubTouch = false;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    hubTouch = false;
}

@end

@implementation EOTimeControllerView

@synthesize nowBlock, driveBlock, modeBlock, stepBlock, odometer;

- (UIView *)addBlock {
    UIView *block = [[UIView alloc] initWithFrame:CGRectZero];
    block.opaque = NO;      // the rounded corners
    block.backgroundColor = rgb(0x1a, 0x1a, 0x2e);   // solid: the dial beneath shows only through a scrub's fade
    block.layer.cornerRadius = blockRadius;
    block.layer.borderWidth = 1;
    block.layer.borderColor = rgb(0x3a, 0x3a, 0x5e).CGColor;
    [self addSubview:block];
    [block release];
    return block;
}

- (UIButton *)addButtonTo:(UIView *)parent title:(NSString *)title font:(UIFont *)font {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = font;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.layer.cornerRadius = buttonRadius;
    button.layer.borderWidth = 1;
    [button setTitleColor:rgb(0xcc, 0xcc, 0xff) forState:UIControlStateHighlighted];   // a tap's feedback (the web's hover colour)
    [parent addSubview:button];
    return button;
}

- (UILabel *)addLabelTo:(UIView *)parent font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = font;
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.adjustsFontSizeToFitWidth = YES;
    [parent addSubview:label];
    [label release];
    return label;
}

// An odometer wheel: a vertical drag rolls its unit (wheelPanned:); it takes digits from the keyboard only
// while the keyboard switch is on (keyboardTapped:)
- (UITextField *)addWheelWithPlaceholder:(NSString *)placeholder unit:(EOTimeStepUnit)unit {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
    field.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightMedium];
    field.tintColor = rgb(0x33, 0x55, 0xcc);
    field.textAlignment = NSTextAlignmentCenter;
    field.clipsToBounds = YES;
    CAGradientLayer *drum = [CAGradientLayer layer];
    drum.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0 alpha:0.75].CGColor, (id)[UIColor colorWithWhite:0 alpha:0].CGColor,
                                            (id)[UIColor colorWithWhite:0 alpha:0].CGColor, (id)[UIColor colorWithWhite:0 alpha:0.75].CGColor, nil];
    drum.locations = [NSArray arrayWithObjects:[NSNumber numberWithDouble:0], [NSNumber numberWithDouble:0.35],
                                               [NSNumber numberWithDouble:0.65], [NSNumber numberWithDouble:1], nil];
    [field.layer insertSublayer:drum atIndex:0];
    styleWheel(field, false);
    field.placeholder = placeholder;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.keyboardAppearance = UIKeyboardAppearanceDark;
    // iPadOS 26's number-pad popover appears only some of the time, ignores the dark appearance (white
    // keys on white) and covers the panel: the docked keyboard, always
    if (@available(iOS 26.0, *)) {
        field.allowsNumberPadPopover = NO;
    }
    field.returnKeyType = UIReturnKeyDone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.delegate = self;
    field.tag = unit;
    UIPanGestureRecognizer *roll = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(wheelPanned:)];
    roll.delegate = self;
    [field addGestureRecognizer:roll];
    [roll release];
    [odometer addSubview:field];
    [field release];
    return field;
}

- (id)initWithStepper:(EOTimeStepper *)aStepper clock:(EOClock *)aClock {
    if ((self = [super initWithFrame:CGRectZero])) {
        stepper = aStepper;
        clock = aClock;
        open = false;
        landscape = false;
        shownUnit = EOTimeStepNumUnits;     // nothing drawn yet
        shownBody = -2;
        shownHeld = 0;
        shownBadge = 0;
        offButton = false;
        shownDrive = 2;
        shownAtPresent = false;
        faded = false;
        shownBCE = false;
        rollCarry = 0;
        entering = false;

        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];

        // Over the altitude dial: what the clock is doing, and Now ▶, acting on the press
        nowBlock = [self addBlock];
        statusLabel = [self addLabelTo:nowBlock font:[UIFont fontWithName:@"Arial" size:12] color:rgb(0x88, 0xaa, 0xff)];
        statusLabel.numberOfLines = 2;
        nowButton = [self addButtonTo:nowBlock title:[NSString stringWithFormat:@"%@ ▶", NSLocalizedString(@"Now", @"button: return the clock to the present")]
                                 font:[UIFont fontWithName:@"Arial" size:18]];
        styleAsPlain(nowButton);
        [nowButton addTarget:self action:@selector(nowPressed:) forControlEvents:UIControlEventTouchDown];

        // Over the azimuth dial: the drive, its current setting lit
        driveBlock = [self addBlock];
        UIFont *transportFont = [UIFont systemFontOfSize:18];
        reverseButton = [self addButtonTo:driveBlock title:@"◀" font:transportFont];
        pauseButton = [self addButtonTo:driveBlock title:@"‖" font:transportFont];
        playButton = [self addButtonTo:driveBlock title:@"▶" font:transportFont];
        [reverseButton addTarget:self action:@selector(reversePressed:) forControlEvents:UIControlEventTouchDown];
        [pauseButton addTarget:self action:@selector(pausePressed:) forControlEvents:UIControlEventTouchDown];
        [playButton addTarget:self action:@selector(playPressed:) forControlEvents:UIControlEventTouchDown];

        // Over the eclipse dial: the mode dial
        modeBlock = [self addBlock];
        modeDial = [[EOTimeModeDial alloc] initWithController:self];
        [modeBlock addSubview:modeDial];
        [modeDial release];

        // Over the equation-of-time dial: the pair.  Tap to step, hold to scrub, lift off the button to
        // scrub hands-free.  UIControl keeps tracking a touch wherever it goes, so the release reaches the
        // button however far the finger has wandered, classed inside or outside; the drag events say which
        // side it is on meanwhile.
        stepBlock = [self addBlock];
        stepLabel = [self addLabelTo:stepBlock font:[UIFont fontWithName:@"Arial-BoldMT" size:14] color:rgb(0xcc, 0xcc, 0xdd)];
        UIFont *pairFont = [UIFont systemFontOfSize:22];
        backButton = [self addButtonTo:stepBlock title:@"◀" font:pairFont];
        forwardButton = [self addButtonTo:stepBlock title:@"▶" font:pairFont];
        styleAsPlain(backButton);
        styleAsPlain(forwardButton);
        for (UIButton *button in [NSArray arrayWithObjects:backButton, forwardButton, nil]) {
            [button addTarget:self action:@selector(stepTouchDown:) forControlEvents:UIControlEventTouchDown];
            [button addTarget:self action:@selector(stepTouchUp:) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchCancel)];
            [button addTarget:self action:@selector(stepTouchUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
            [button addTarget:self action:@selector(stepTouchDragExit:) forControlEvents:UIControlEventTouchDragExit];
            [button addTarget:self action:@selector(stepTouchDragEnter:) forControlEvents:UIControlEventTouchDragEnter];
        }
        // The padlock, the hands-free tell: over the pair at full alpha while a lift would lock, dimmer once
        // it has.  An image view takes no touches, so the pair keeps tracking beneath it.
        padlock = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"
                                                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:lockBadgeSize]]];
        padlock.tintColor = rgb(0x4c, 0xd9, 0x64);
        padlock.contentMode = UIViewContentModeCenter;
        padlock.hidden = YES;
        [stepBlock addSubview:padlock];
        [padlock release];

        // The odometer: the wheels, then the keyboard button and Set / Done (EOClock's).  A typed value
        // applies when its wheel's edit ends; the era, at once.
        odometer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, EOOdometerWidth, EOOdometerHeight)];
        odometer.opaque = NO;
        odometer.backgroundColor = [UIColor colorWithRed:26/255.0 green:26/255.0 blue:46/255.0 alpha:0.96];
        odometer.layer.cornerRadius = 8;
        odometer.layer.borderWidth = 1;
        odometer.layer.borderColor = rgb(0x3a, 0x3a, 0x5e).CGColor;

        [self addSubview:odometer];
        [odometer release];
        eraButton = [self addButtonTo:odometer title:NSLocalizedString(@"CE", @"era toggle: Common Era") font:[UIFont fontWithName:@"Arial" size:13]];
        eraButton.layer.cornerRadius = 6;
        styleAsEra(eraButton, false);
        [eraButton addTarget:self action:@selector(eraTapped:) forControlEvents:UIControlEventTouchUpInside];
        yearField = [self addWheelWithPlaceholder:@"YYYY" unit:EOTimeStepYear];
        monthField = [self addWheelWithPlaceholder:@"MM" unit:EOTimeStepMonth];
        dayField = [self addWheelWithPlaceholder:@"DD" unit:EOTimeStepDay];
        hourField = [self addWheelWithPlaceholder:@"HH" unit:EOTimeStepHour];
        minuteField = [self addWheelWithPlaceholder:@"mm" unit:EOTimeStepMinute];
        secondField = [self addWheelWithPlaceholder:@"ss" unit:EOTimeStepSecond];
        keyboardButton = [self addButtonTo:odometer title:nil font:nil];
        [keyboardButton setImage:[UIImage systemImageNamed:@"keyboard"
                                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17]]
                        forState:UIControlStateNormal];
        styleAsPlain(keyboardButton);
        keyboardButton.tintColor = rgb(0x99, 0x99, 0xbb);
        keyboardButton.adjustsImageWhenHighlighted = NO;
        [keyboardButton addTarget:self action:@selector(keyboardTapped:) forControlEvents:UIControlEventTouchUpInside];

        [self layoutOdometer];
        [self layoutForLandscape:false];
        [self setOpen:false];
        [self refresh];
    }
    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    // The widgets are the view hierarchy's; the stepper and the clock are not ours
    [super dealloc];
}

// The view spans the canvas but is only a holder: a touch between the blocks goes on to the display
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

//// Layout

- (void)layoutForLandscape:(bool)isLandscape {
    landscape = isLandscape;
    double w = landscape ? landscapeBlockWidth : portraitBlockWidth;
    double h = landscape ? landscapeBlockHeight : portraitBlockHeight;
    for (UIView *block in [NSArray arrayWithObjects:nowBlock, driveBlock, modeBlock, stepBlock, nil]) {
        block.bounds = CGRectMake(0, 0, w, h);
    }
    double inner = w - 2 * blockPad;

    // The status on top, Now below it, in the middle of what is left
    statusLabel.frame = CGRectMake(blockPad, blockPad, inner, statusHeight);
    double nowTop = blockPad + statusHeight + gap;
    double nowHeight = fmin(64, h - nowTop - blockPad);
    nowButton.frame = CGRectMake(blockPad, nowTop + (h - nowTop - blockPad - nowHeight) / 2, inner, nowHeight);

    // The drive: ▶ ‖ ◀ down a tall block, the lever's travel; ◀ ‖ ▶ across a square one
    if (h > w * 1.2) {
        double buttonHeight = (h - 2 * blockPad - 2 * gap) / 3;
        playButton.frame = CGRectMake(blockPad, blockPad, inner, buttonHeight);
        pauseButton.frame = CGRectMake(blockPad, blockPad + buttonHeight + gap, inner, buttonHeight);
        reverseButton.frame = CGRectMake(blockPad, blockPad + 2 * (buttonHeight + gap), inner, buttonHeight);
    } else {
        double buttonWidth = (inner - 2 * gap) / 3;
        double buttonHeight = fmin(64, h - 2 * blockPad);
        double y = (h - buttonHeight) / 2;
        reverseButton.frame = CGRectMake(blockPad, y, buttonWidth, buttonHeight);
        pauseButton.frame = CGRectMake(blockPad + buttonWidth + gap, y, buttonWidth, buttonHeight);
        playButton.frame = CGRectMake(blockPad + 2 * (buttonWidth + gap), y, buttonWidth, buttonHeight);
    }

    // The mode dial: the largest circle the block holds
    double dial = fmin(inner, h - 2 * blockPad);
    modeDial.frame = CGRectMake((w - dial) / 2, (h - dial) / 2, dial, dial);
    [modeDial setNeedsDisplay];

    // The pair: its label on top, the two buttons side by side below
    stepLabel.frame = CGRectMake(blockPad, blockPad, inner, labelHeight);
    double pairTop = blockPad + labelHeight + gap;
    double pairWidth = (inner - gap) / 2;
    backButton.frame = CGRectMake(blockPad, pairTop, pairWidth, h - pairTop - blockPad);
    forwardButton.frame = CGRectMake(blockPad + pairWidth + gap, pairTop, pairWidth, h - pairTop - blockPad);
    padlock.frame = CGRectMake(0, pairTop, w, h - pairTop - blockPad);
}

// The wheels centred in the space left of the buttons; the keyboard button where Now goes while closed
- (void)layoutOdometer {
    double wheelsWidth = EOOdometerWidth - EOOdometerButtonsWidth;
    double total = eraWidth + yearWidth + 5 * wheelWidth + 5 * wheelGap + groupGap + 2;
    double x = (wheelsWidth - total) / 2;
    double y = 4;
    double height = EOOdometerHeight - 8;
    eraButton.frame = CGRectMake(x, y, eraWidth, height);
    x += eraWidth + wheelGap + 2;
    yearField.frame = CGRectMake(x, y, yearWidth, height);
    x += yearWidth + wheelGap;
    for (UITextField *field in [NSArray arrayWithObjects:monthField, dayField, hourField, minuteField, secondField, nil]) {
        field.frame = CGRectMake(x, y, wheelWidth, height);
        x += wheelWidth + (field == dayField ? groupGap : wheelGap);
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (UITextField *field in [NSArray arrayWithObjects:yearField, monthField, dayField, hourField, minuteField, secondField, nil]) {
        [[field.layer.sublayers objectAtIndex:0] setFrame:field.bounds];
    }
    [CATransaction commit];
    keyboardButton.frame = CGRectMake(wheelsWidth + 4, y, 69, height);
}

- (void)setOpen:(bool)isOpen {
    open = isOpen;
    for (UIView *block in [NSArray arrayWithObjects:nowBlock, driveBlock, modeBlock, stepBlock, nil]) {
        block.hidden = !open;
    }
    keyboardButton.hidden = !open;
    if (open) {
        [self refresh];
    }
}

//// The widgets' actions

- (void)nowPressed:(UIButton *)sender {
    [stepper now];
    [self refresh];
}

- (void)pausePressed:(UIButton *)sender {
    [stepper stop];
    [self refresh];
}

- (void)reversePressed:(UIButton *)sender {
    [stepper playReverse];
    [self refresh];
}

- (void)playPressed:(UIButton *)sender {
    [stepper play];
    [self refresh];
}

- (void)dialSelectedUnit:(EOTimeStepUnit)unit {
    [stepper selectUnit:unit];
    [self refresh];
}

- (void)dialSteppedBody:(int)direction {
    [stepper stepBody:direction];
    [self refresh];
}

- (void)stepTouchDown:(UIButton *)sender {
    offButton = false;
    if (![stepper pressInDirection:(sender == forwardButton ? 1 : -1)]) {
        [self flashFailure:sender];     // an astro search found no event here
    }
    [self refresh];
}

// A lift on the button, or a cancelled touch (a system gesture, a rotation): the scrub ends
- (void)stepTouchUp:(UIButton *)sender {
    offButton = false;
    [stepper endPress];
    [self refresh];
}

// A lift off the button: the latch, once the hold has engaged (the scrub runs on hands-free until the
// next press); before that it was a sloppy tap — one step, no latch
- (void)stepTouchUpOutside:(UIButton *)sender {
    offButton = false;
    if ([stepper isScrubbing]) {
        [stepper lockScrub];
    } else {
        [stepper endPress];
    }
    [self refresh];
}

// The held finger leaves the button and comes back: the padlock shows what a lift would do
- (void)stepTouchDragExit:(UIButton *)sender {
    offButton = true;
    [self refresh];
}

- (void)stepTouchDragEnter:(UIButton *)sender {
    offButton = false;
    [self refresh];
}

// The web's .flash-fail: the pressed button turns brown for a moment
- (void)flashFailure:(UIButton *)button {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(unflash:) object:button];
    styleAsFailed(button);
    [self performSelector:@selector(unflash:) withObject:button afterDelay:flashDuration];
}

- (void)unflash:(UIButton *)button {
    styleAsPlain(button);
}

//// The odometer's wheels

- (UITextField *)editingField {
    for (UITextField *field in [NSArray arrayWithObjects:yearField, monthField, dayField, hourField, minuteField, secondField, nil]) {
        if ([field isFirstResponder]) {
            return field;
        }
    }
    return nil;
}

// A wheel rolls only for a mostly vertical drag, and not while the keyboard switch makes it a field
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if (![recognizer isKindOfClass:[UIPanGestureRecognizer class]] || entering) {
        return NO;
    }
    CGPoint velocity = [(UIPanGestureRecognizer *)recognizer velocityInView:recognizer.view];
    return fabs(velocity.y) > fabs(velocity.x);
}

// Up rolls the wheel on, down rolls it back, a unit per notch of travel.  With the controller closed, the
// drag opens it first, as Set would.
- (void)wheelPanned:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (!open) {
            [clock openTimePanel];
        }
        rollCarry = 0;
    }
    rollCarry -= [recognizer translationInView:recognizer.view].y;
    [recognizer setTranslation:CGPointZero inView:recognizer.view];
    EOTimeStepUnit unit = (EOTimeStepUnit)recognizer.view.tag;
    while (rollCarry >= notch) {
        [stepper rollUnit:unit inDirection:1];
        rollCarry -= notch;
    }
    while (rollCarry <= -notch) {
        [stepper rollUnit:unit inDirection:-1];
        rollCarry += notch;
    }
    [self refresh];
}

// The keyboard switch.  On, the wheels become fields: the year takes the keyboard, a tap on another field
// moves to it, and Return or a tap elsewhere puts the keyboard away with the switch still on.  Off, any
// edit in progress applies and the wheels roll again.
- (void)setEntering:(bool)on {
    if (on == entering) {
        return;
    }
    if (!on) {
        [self endEditing:YES];
    }
    entering = on;
    for (UITextField *field in [NSArray arrayWithObjects:yearField, monthField, dayField, hourField, minuteField, secondField, nil]) {
        styleWheel(field, on);
    }
    if (on) {
        styleAsActive(keyboardButton);
        [keyboardButton setImage:[UIImage systemImageNamed:@"keyboard.fill"
                                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17]]
                        forState:UIControlStateNormal];
        keyboardButton.tintColor = rgb(0x88, 0xaa, 0xff);
        [yearField becomeFirstResponder];
    } else {
        styleAsPlain(keyboardButton);
        [keyboardButton setImage:[UIImage systemImageNamed:@"keyboard"
                                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17]]
                        forState:UIControlStateNormal];
        keyboardButton.tintColor = rgb(0x99, 0x99, 0xbb);
    }
}

- (void)keyboardTapped:(UIButton *)sender {
    [self setEntering:!entering];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return entering;    // with the switch off a tap on a wheel does nothing: wheels roll
}

// Digits only, and no more of them than the wheel can mean (a hardware keyboard types anything)
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if ([string length] == 0) {
        return YES;     // a deletion
    }
    if ([string rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location != NSNotFound) {
        return NO;
    }
    NSUInteger length = [textField.text length] - range.length + [string length];
    return length <= (textField == yearField ? 4 : 2);
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    // The whole value selected, so that typing replaces it
    textField.selectedTextRange = [textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];   // ends the edit, and the value applies (textFieldDidEndEditing:)
    return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self applyDateFields];
}

// The typed date and time, through the stepper.  A wheel left empty leaves the time alone; the next
// refresh fills it in again.
- (void)applyDateFields {
    for (UITextField *field in [NSArray arrayWithObjects:yearField, monthField, dayField, hourField, minuteField, secondField, nil]) {
        if ([field.text length] == 0) {
            return;
        }
    }
    [stepper setEra:(shownBCE ? 0 : 1) year:[yearField.text intValue] month:[monthField.text intValue] day:[dayField.text intValue]
               hour:[hourField.text intValue] minute:[minuteField.text intValue] second:[secondField.text intValue]];
    [self refresh];
}

- (void)showEra:(bool)bce {
    shownBCE = bce;
    [eraButton setTitle:(bce ? NSLocalizedString(@"BCE", @"era toggle: Before Common Era") : NSLocalizedString(@"CE", @"era toggle: Common Era"))
               forState:UIControlStateNormal];
    styleAsEra(eraButton, bce);
}

- (void)eraTapped:(UIButton *)sender {
    if (!open) {
        [clock openTimePanel];
    }
    [self showEra:!shownBCE];
    [self applyDateFields];
}

// A touch on a block's background or the odometer's ends an edit, and so applies it
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self endEditing:YES];
    [super touchesBegan:touches withEvent:event];
}

//// Keeping the controller current

- (void)refresh {
    // The wheels follow the time, all but the one being edited (a running clock must not overwrite
    // keystrokes); the era always does
    ESDateComponents cs;
    [stepper dateComponents:&cs];
    UITextField *editing = [self editingField];
    if (editing != yearField) {
        setFieldText(yearField, [NSString stringWithFormat:@"%d", cs.year]);
    }
    if (editing != monthField) {
        setFieldText(monthField, [NSString stringWithFormat:@"%02d", cs.month]);
    }
    if (editing != dayField) {
        setFieldText(dayField, [NSString stringWithFormat:@"%02d", cs.day]);
    }
    if (editing != hourField) {
        setFieldText(hourField, [NSString stringWithFormat:@"%02d", cs.hour]);
    }
    if (editing != minuteField) {
        setFieldText(minuteField, [NSString stringWithFormat:@"%02d", cs.minute]);
    }
    if (editing != secondField) {
        setFieldText(secondField, [NSString stringWithFormat:@"%02d", (int)floor(cs.seconds)]);
    }
    if ((cs.era == 0) != shownBCE) {
        [self showEra:(cs.era == 0)];
    }
    if (!open) {
        return;     // the rest is the blocks'
    }

    EOTimeStepUnit unit = stepper.unit;
    int body = [stepper bodyPlanetNumber];
    NSString *bodyName = [Utilities nameOfPlanetWithNumber:(ECPlanetNumber)body];
    if (unit != shownUnit || body != shownBody) {
        [modeDial setUnit:unit bodyName:bodyName];
        shownUnit = unit;
        shownBody = body;
    }
    setLabelText(stepLabel, [stepper stepLabelWithBodyName:bodyName]);
    NSString *status = [stepper statusString];
    if ([stepper isAtLimit]) {
        status = [NSString stringWithFormat:@"%@\n%@", status, NSLocalizedString(@"AT LIMIT", @"strip suffix: the time is clamped at the end of the supported range (4000 BCE to 2800 CE)")];
    }
    setLabelText(statusLabel, status);

    int drive = [stepper runDirection];
    if (drive != shownDrive) {
        styleAsPlain(reverseButton);
        styleAsPlain(pauseButton);
        styleAsPlain(playButton);
        styleAsActive(drive > 0 ? playButton : (drive < 0 ? reverseButton : pauseButton));
        shownDrive = drive;
    }
    bool atPresent = [stepper isAtPresent];
    if (atPresent != shownAtPresent) {
        nowButton.enabled = !atPresent;
        nowButton.alpha = atPresent ? 0.4 : 1.0;
        shownAtPresent = atPresent;
    }

    // The held button's look and the fade follow the scrub: on while it runs, off the moment it stops.
    // The fade is alpha only, never hidden: the held button must keep receiving its touch.  The odometer
    // never fades: it is what a scrub is watched on.
    bool scrubbing = [stepper isScrubbing];
    bool locked = [stepper isLocked];
    int held = scrubbing ? stepper.scrubDirection : 0;
    if (held != shownHeld) {
        styleAsPlain(backButton);
        styleAsPlain(forwardButton);
        if (held > 0) {
            styleAsHolding(forwardButton);
        } else if (held < 0) {
            styleAsHolding(backButton);
        }
        shownHeld = held;
    }
    // The lock zone: the held finger is off the button, where a lift would lock.  The blocks come back to
    // full alpha with the padlock, so the outcome is visible before it happens; back on the button they
    // fade again.  Locked, the padlock stays, dimmer, over the faded blocks.
    bool lockZone = scrubbing && !locked && offButton;
    int badge = locked ? 2 : (lockZone ? 1 : 0);
    if (badge != shownBadge) {
        padlock.hidden = (badge == 0);
        padlock.alpha = (badge == 2) ? lockedAlpha : lockZoneAlpha;
        shownBadge = badge;
    }
    bool shouldFade = scrubbing && !lockZone;
    if (shouldFade != faded) {
        faded = shouldFade;
        [UIView animateWithDuration:fadeDuration animations:^{
            for (UIView *block in [NSArray arrayWithObjects:nowBlock, driveBlock, modeBlock, stepBlock, nil]) {
                block.alpha = faded ? scrubAlpha : 1.0;
            }
        }];
    }
}

- (void)prepareToHide {
    [self setEntering:false];   // a pending edit applies; the keyboard goes
    [self endEditing:YES];
    [stepper endPress];
    offButton = false;
    [self refresh];
}

@end
