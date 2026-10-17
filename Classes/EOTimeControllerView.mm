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
static const double labelHeight = 18;           // the pair's label
static const double statusHeight = 30;          // the status over Now: two lines, for a scrub at the limit
// The blocks' and the odometer's frame, as the location picker's large map has it: black, a gray border
// (EOClock's header box), a shadow
static const double frameRadius = 12;
static const double frameLineWidth = 2;
static const double frameGray = 0.5;
static const double frameAlpha = 0.5;
static const double frameShadowOpacity = 0.6;
// Opening, the blocks and the odometer swell out of Set / Done on a spring with a little overshoot, as the
// picker's map does out of the small one; closing, they settle back into it without
static const NSTimeInterval growDuration = 0.65;
static const double growDamping = 0.72;
static const NSTimeInterval shrinkDuration = 0.5;
static const double vanishStart = 0.8;          // a shrinking view fades out from this fraction of its travel...
static const double vanishEnd = 0.95;           // ...and is gone by this one, before it is a speck under Set / Done
static const double buttonRadius = 8;
static const double gap = 4;
static const double wheelGap = 4;               // between the wheels of a group
static const double groupGap = 14;              // between the date's wheels and the time's
static const double eraWidth = 40;
static const double yearWidth = 52;
static const double wheelWidth = 34;            // month, day, hour, minute, second
static const double notch = 20;                 // a wheel drag's travel per unit rolled
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
//// anywhere on it turns the hand to the nearest position, and a drag around it keeps turning.

@interface EOTimeControllerView (Selectors)
- (void)dialSelectedUnit:(EOTimeStepUnit)unit;
- (void)ringSelectedBody:(int)planetNumber;
@end

@interface EOTimeModeDial : UIView {
    EOTimeControllerView *controller;   // not retained: our superview's superview
    EOTimeStepUnit       unit;
}
- (id)initWithController:(EOTimeControllerView *)aController;
- (void)setUnit:(EOTimeStepUnit)aUnit;
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

- (void)setUnit:(EOTimeStepUnit)aUnit {
    unit = aUnit;
    [self setNeedsDisplay];
}

- (CGPoint)hub {
    return CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
}

- (double)rimRadius {
    return fmin(self.bounds.size.width, self.bounds.size.height) / 2 - 1;
}

static double angleForPosition(int i) {
    return i * 2 * M_PI / EOTimeStepNumUnits;
}

// One graduation of ticks around the band, n to the turn, from radius r1 out to r2
static void drawTicks(CGContextRef context, CGPoint c, int n, double r1, double r2, double width, UIColor *color, double offset) {
    CGContextSetLineWidth(context, width);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    for (int i = 0; i < n; i++) {
        double a = (i + offset) * 2 * M_PI / n;
        CGContextMoveToPoint(context, c.x + r1 * sin(a), c.y - r1 * cos(a));
        CGContextAddLineToPoint(context, c.x + r2 * sin(a), c.y - r2 * cos(a));
    }
    CGContextStrokePath(context);
}

// After the Moon azimuth dial: a translucent band around the rim carrying the graduations, faint spokes from a
// small hub, and an outline hand; the positions' words lie radially just inside the band, in the location
// picker's Hoefler Text, reading out from the centre on the right and in toward it on the left
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint c = [self hub];
    double rim = [self rimRadius];
    double band = rim * 0.17;
    double hubR = rim * 0.1;
    double wordsOuter = rim - band - 2;
    double wordsInner = rim * 0.26;
    double step = 2 * M_PI / EOTimeStepNumUnits;

    // The band
    CGContextSetLineWidth(context, 0.5);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 0.6);
    CGContextSetRGBFillColor(context, 1, 1, 1, 0.15);
    CGContextAddArc(context, c.x, c.y, rim, 0, 2 * M_PI, 0);
    CGContextAddArc(context, c.x, c.y, rim - band, 0, 2 * M_PI, 0);
    CGContextDrawPath(context, kCGPathEOFillStroke);

    // Spokes between the positions, as the azimuth dial's between its compass points
    drawTicks(context, c, EOTimeStepNumUnits, hubR, wordsOuter, 1, [UIColor colorWithRed:0.3 green:0.3 blue:0.9 alpha:0.35], 0.5);

    // The graduations: a long tick at each position, short ones between
    UIColor *tickColor = [UIColor lightGrayColor];
    drawTicks(context, c, EOTimeStepNumUnits * 4, rim - band * 0.45, rim, 1, tickColor, 0);
    drawTicks(context, c, EOTimeStepNumUnits, rim - band, rim, 1.2, tickColor, 0);

    // The hand, an outline as the azimuth dial's, out to the band at the selected position
    double a = unit * step;
    CGPoint tip = CGPointMake(c.x + (rim - band) * sin(a), c.y - (rim - band) * cos(a));
    CGPoint left = CGPointMake(c.x - hubR * 0.6 * cos(a), c.y - hubR * 0.6 * sin(a));
    CGPoint right = CGPointMake(c.x + hubR * 0.6 * cos(a), c.y + hubR * 0.6 * sin(a));
    CGContextSetLineWidth(context, 1);
    CGContextSetStrokeColorWithColor(context, [UIColor lightGrayColor].CGColor);
    CGContextMoveToPoint(context, left.x, left.y);
    CGContextAddLineToPoint(context, tip.x, tip.y);
    CGContextAddLineToPoint(context, right.x, right.y);
    CGContextClosePath(context);
    CGContextStrokePath(context);

    // The hub over the hand's base: the band's translucent white, made solid
    CGContextSetLineWidth(context, 0.5);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 0.6);
    CGContextSetRGBFillColor(context, 0.15, 0.15, 0.15, 1);
    CGContextAddArc(context, c.x, c.y, hubR, 0, 2 * M_PI, 0);
    CGContextDrawPath(context, kCGPathFillStroke);

    // The words, all at one size: the largest at which the longest fits between the hub and the band
    double size = rim * 0.17;
    UIFont *font, *bold;
    double widest;
    do {
        font = [UIFont fontWithName:@"HoeflerText-Regular" size:size];
        bold = [UIFont fontWithName:@"HoeflerText-Black" size:size];
        widest = 0;
        for (int i = 0; i < EOTimeStepNumUnits; i++) {
            UIFont *f = (i == unit) ? bold : font;
            widest = fmax(widest, [[EOTimeStepper labelForUnit:(EOTimeStepUnit)i] sizeWithAttributes:[NSDictionary dictionaryWithObject:f forKey:NSFontAttributeName]].width);
        }
        size -= 0.25;
    } while (widest > wordsOuter - wordsInner && size > 5);
    UIColor *gold = [UIColor colorWithRed:1 green:0xc1/256.0 blue:0x25/256.0 alpha:1];      // the clock's minute hand
    UIColor *white = [UIColor colorWithWhite:1 alpha:0.85];
    UIColor *blue = [UIColor colorWithRed:0.65 green:0.75 blue:1 alpha:0.9];
    for (int i = 0; i < EOTimeStepNumUnits; i++) {
        NSString *label = [EOTimeStepper labelForUnit:(EOTimeStepUnit)i];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:(i == unit ? bold : font), NSFontAttributeName,
                                                 (i == unit ? gold : ([EOTimeStepper unitIsAstro:(EOTimeStepUnit)i] ? blue : white)), NSForegroundColorAttributeName, nil];
        CGSize extent = [label sizeWithAttributes:attributes];
        double angle = i * step;
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, c.x, c.y);
        if (angle < M_PI) {
            // The right half: along the radius, reading outward, ending at the band
            CGContextRotateCTM(context, angle - M_PI / 2);
            [label drawAtPoint:CGPointMake(wordsOuter - extent.width, -extent.height / 2) withAttributes:attributes];
        } else {
            // The left half: turned around, reading inward, starting at the band
            CGContextRotateCTM(context, angle + M_PI / 2);
            [label drawAtPoint:CGPointMake(-wordsOuter, -extent.height / 2) withAttributes:attributes];
        }
        CGContextRestoreGState(context);
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
    [controller dialSelectedUnit:[self unitAtPoint:[[touches anyObject] locationInView:self]]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [controller dialSelectedUnit:[self unitAtPoint:[[touches anyObject] locationInView:self]]];
}

@end

//// The body ring, for rise / set / transit: the bodies' symbols in a horseshoe around the pair, open at the top
//// for its label, from the Sun at the upper left down and around to Neptune at the upper right.  A tap on a
//// symbol picks that body; the middle is the pair's, and takes no touches.

static const double ringFirstAngle = 320;       // degrees clockwise from the top: the Sun
static const double ringSpacing = 35;           // between neighbours, so the nine span 280 degrees

static NSString *symbolForBody(int planet) {
    switch (planet) {
      case ECPlanetSun:     return @"\u2609";
      case ECPlanetMoon:    return @"\u263D";
      case ECPlanetMercury: return @"\u263F";
      case ECPlanetVenus:   return @"\u2640\uFE0E";     // as text: not the emoji
      case ECPlanetMars:    return @"\u2642\uFE0E";
      case ECPlanetJupiter: return @"\u2643";
      case ECPlanetSaturn:  return @"\u2644";
      case ECPlanetUranus:  return @"\u2645";
      case ECPlanetNeptune: return @"\u2646";
      default:              return @"?";
    }
}

@interface EOTimeBodyRing : UIView {
    EOTimeControllerView *controller;   // not retained
    int                  body;          // the selected ECPlanetNumber
}
- (id)initWithController:(EOTimeControllerView *)aController;
- (void)setBody:(int)planetNumber;
- (double)symbolSize;
- (double)symbolRadius;
- (double)innerRadius;                  // inside the symbols: the pair's room
@end

@implementation EOTimeBodyRing

- (id)initWithController:(EOTimeControllerView *)aController {
    if ((self = [super initWithFrame:CGRectZero])) {
        controller = aController;
        body = -1;
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setBody:(int)planetNumber {
    body = planetNumber;
    [self setNeedsDisplay];
}

- (CGPoint)center_ {
    return CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
}

- (double)symbolSize {
    return fmin(self.bounds.size.width, self.bounds.size.height) * 0.125;
}

- (double)symbolRadius {
    return fmin(self.bounds.size.width, self.bounds.size.height) / 2 - [self symbolSize] * 0.75;
}

- (double)innerRadius {
    return [self symbolRadius] - [self symbolSize] * 0.8;
}

static CGPoint ringPoint(CGPoint c, double r, double degrees) {
    return CGPointMake(c.x + r * sin(degrees * M_PI / 180), c.y - r * cos(degrees * M_PI / 180));
}

- (void)drawRect:(CGRect)rect {
    CGPoint c = [self center_];
    double r = [self symbolRadius];
    double size = [self symbolSize];

    // The track the symbols sit on, around the bottom
    UIBezierPath *track = [UIBezierPath bezierPathWithArcCenter:c radius:r startAngle:(ringFirstAngle - 90) * M_PI / 180
                                                       endAngle:(ringFirstAngle - 90 - ringSpacing * ([EOTimeStepper numBodies] - 1)) * M_PI / 180 clockwise:NO];
    track.lineWidth = 1;
    [rgb(0x3a, 0x3a, 0x5e) setStroke];
    [track stroke];

    for (int i = 0; i < [EOTimeStepper numBodies]; i++) {
        int planet = [EOTimeStepper bodyAtIndex:i];
        CGPoint p = ringPoint(c, r, ringFirstAngle - i * ringSpacing);
        bool selected = (planet == body);
        UIBezierPath *disc = [UIBezierPath bezierPathWithArcCenter:p radius:size * 0.72 startAngle:0 endAngle:2 * M_PI clockwise:YES];
        [(selected ? rgb(0x2a, 0x2a, 0x3e) : [UIColor blackColor]) setFill];
        [disc fill];
        if (selected) {
            disc.lineWidth = 1.5;
            [rgb(0x88, 0xaa, 0xff) setStroke];
            [disc stroke];
        }
        NSString *symbol = symbolForBody(planet);
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:size], NSFontAttributeName,
                                                 (selected ? rgb(0xcc, 0xcc, 0xff) : rgb(0x99, 0x99, 0xbb)), NSForegroundColorAttributeName, nil];
        CGSize extent = [symbol sizeWithAttributes:attributes];
        [symbol drawAtPoint:CGPointMake(p.x - extent.width / 2, p.y - extent.height / 2) withAttributes:attributes];
    }
}

// Only the band the symbols are in takes touches
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint c = [self center_];
    double d = hypot(point.x - c.x, point.y - c.y);
    return d >= [self innerRadius] && d <= [self symbolRadius] + [self symbolSize] && [super pointInside:point withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self];
    CGPoint c = [self center_];
    double angle = atan2(point.x - c.x, c.y - point.y) * 180 / M_PI;      // clockwise from the top
    if (angle < 0) {
        angle += 360;
    }
    double last = ringFirstAngle - ringSpacing * ([EOTimeStepper numBodies] - 1);
    if (angle < last - ringSpacing / 2 || angle > ringFirstAngle + ringSpacing / 2) {
        return;     // the opening at the top
    }
    int i = (int)lround((ringFirstAngle - angle) / ringSpacing);
    i = i < 0 ? 0 : (i >= [EOTimeStepper numBodies] ? [EOTimeStepper numBodies] - 1 : i);
    [controller ringSelectedBody:[EOTimeStepper bodyAtIndex:i]];
}

@end

@implementation EOTimeControllerView

@synthesize nowBlock, driveBlock, modeBlock, stepBlock, odometer;

// The location picker's frame, on a block or the odometer: solid black, so the dial beneath shows only
// through a scrub's fade
static void styleAsFrame(UIView *view) {
    view.backgroundColor = [UIColor blackColor];
    view.layer.cornerRadius = frameRadius;
    view.layer.borderWidth = frameLineWidth;
    view.layer.borderColor = [UIColor colorWithWhite:frameGray alpha:frameAlpha].CGColor;
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = frameShadowOpacity;
    view.layer.shadowRadius = 6;
    view.layer.shadowOffset = CGSizeMake(0, 3);
}

- (UIView *)addBlock {
    UIView *block = [[UIView alloc] initWithFrame:CGRectZero];
    styleAsFrame(block);
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
    // Digits want no spelling, and no shortcut bar (cut, copy, paste) over the keys; less for the first
    // keyboard of a launch to load
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.inputAssistantItem.leadingBarButtonGroups = [NSArray array];
    field.inputAssistantItem.trailingBarButtonGroups = [NSArray array];
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
        // Under the pair, the body ring for rise / set / transit
        bodyRing = [[EOTimeBodyRing alloc] initWithController:self];
        [stepBlock addSubview:bodyRing];
        [bodyRing release];
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
        styleAsFrame(odometer);
        odometer.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:odometer.bounds cornerRadius:frameRadius].CGPath;

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
        odometer.hidden = YES;
        [keyboardButton addTarget:self action:@selector(keyboardTapped:) forControlEvents:UIControlEventTouchUpInside];

        [self layoutOdometer];
        [self layoutForLandscape:false];
        for (UIView *view in [self openingViews]) {
            view.hidden = YES;
        }
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
        CGAffineTransform transform = block.transform;     // the bounds as they are at rest, mid-animation or not
        block.transform = CGAffineTransformIdentity;
        block.bounds = CGRectMake(0, 0, w, h);
        block.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:block.bounds cornerRadius:frameRadius].CGPath;
        block.transform = transform;
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

    [self layoutStepBlock];
}

// The pair.  Without a body: its label on top, the two buttons side by side below, filling the block.  With
// one: the body ring, as large as the block holds and at its foot, the buttons in the ring's middle and the
// label above them (in the ring's opening, in a square block).
- (void)layoutStepBlock {
    double w = landscape ? landscapeBlockWidth : portraitBlockWidth;
    double h = landscape ? landscapeBlockHeight : portraitBlockHeight;
    double inner = w - 2 * blockPad;
    bodyRing.hidden = !ringShown;
    if (!ringShown) {
        stepLabel.frame = CGRectMake(blockPad, blockPad, inner, labelHeight);
        double pairTop = blockPad + labelHeight + gap;
        double pairWidth = (inner - gap) / 2;
        backButton.frame = CGRectMake(blockPad, pairTop, pairWidth, h - pairTop - blockPad);
        forwardButton.frame = CGRectMake(blockPad + pairWidth + gap, pairTop, pairWidth, h - pairTop - blockPad);
        padlock.frame = CGRectMake(0, pairTop, w, h - pairTop - blockPad);
        return;
    }
    double side = fmin(inner, h - 2 * blockPad);
    bodyRing.frame = CGRectMake((w - side) / 2, h - blockPad - side, side, side);
    [bodyRing setNeedsDisplay];
    CGPoint c = CGPointMake(w / 2, h - blockPad - side / 2);
    double r = [bodyRing innerRadius];
    if (h - side > labelHeight + 2 * blockPad) {
        stepLabel.frame = CGRectMake(blockPad, blockPad, inner, labelHeight);
    } else {
        double chord = 1.3 * [bodyRing symbolRadius] * sin(ringSpacing * M_PI / 180 * 1.15);
        stepLabel.frame = CGRectMake(c.x - chord, blockPad - 3, 2 * chord, labelHeight);
    }
    double pairWidth = 0.8 * r - gap / 2;
    double pairHeight = 1.25 * r;
    backButton.frame = CGRectMake(c.x - 0.8 * r, c.y - pairHeight / 2 + 0.1 * r, pairWidth, pairHeight);
    forwardButton.frame = CGRectMake(c.x + gap / 2, c.y - pairHeight / 2 + 0.1 * r, pairWidth, pairHeight);
    padlock.frame = CGRectMake(c.x - r, c.y - r, 2 * r, 2 * r);
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

- (NSArray *)openingViews {
    return [NSArray arrayWithObjects:nowBlock, driveBlock, modeBlock, stepBlock, odometer, nil];
}

// The transform that puts a view, at rest, over the given rect
static CGAffineTransform transformOnto(UIView *view, CGRect rect) {
    CGSize size = view.bounds.size;
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(rect) - view.center.x, CGRectGetMidY(rect) - view.center.y);
    return CGAffineTransformScale(t, rect.size.width / size.width, rect.size.height / size.height);
}

// Each frame of the shrink: a view fades out over the last of its travel, by how far it has shrunk rather
// than by time (the spring covers most of the distance early), as the picker's magnifier and label do
- (void)shrinkStep:(CADisplayLink *)link {
    for (UIView *view in [self openingViews]) {
        CALayer *layer = view.layer.presentationLayer;
        if (!layer) {
            continue;
        }
        double end = transformOnto(view, shrinkTarget).a;
        double progress = end < 1 ? (1 - layer.transform.m11) / (1 - end) : 1;
        view.alpha = fmin(fmax((vanishEnd - progress) / (vanishEnd - vanishStart), 0), 1);
    }
}

- (void)stopShrinkFade {
    [shrinkLink invalidate];    // it retains us until then
    shrinkLink = nil;
}

- (void)setOpen:(bool)isOpen fromRect:(CGRect)source {
    open = isOpen;
    NSArray *views = [self openingViews];
    bool animate = self.window && !UIAccessibilityIsReduceMotionEnabled();
    if (open) {
        [self stopShrinkFade];
        faded = false;
        [self refresh];
        for (UIView *view in views) {
            view.alpha = 1;
            if (animate && view.hidden) {
                view.transform = transformOnto(view, source);
            }
            view.hidden = NO;
            view.userInteractionEnabled = YES;
        }
        if (!animate) {
            return;
        }
        [UIView animateWithDuration:growDuration delay:0 usingSpringWithDamping:growDamping initialSpringVelocity:0
                            options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            for (UIView *view in views) {
                view.transform = CGAffineTransformIdentity;
            }
        } completion:NULL];
        return;
    }
    // Closing: nothing on the way back takes a touch, and once it is all in Set / Done, it goes (unless it has
    // opened again meanwhile)
    for (UIView *view in views) {
        view.userInteractionEnabled = NO;
    }
    void (^done)(BOOL) = ^(BOOL finished) {
        if (open) {
            return;
        }
        [self stopShrinkFade];
        for (UIView *view in views) {
            view.hidden = YES;
            view.transform = CGAffineTransformIdentity;
            view.alpha = 1;
        }
    };
    if (!animate) {
        done(YES);
        return;
    }
    shrinkTarget = source;
    [self stopShrinkFade];
    shrinkLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(shrinkStep:)];
    [shrinkLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [UIView animateWithDuration:shrinkDuration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        for (UIView *view in views) {
            view.transform = transformOnto(view, source);
        }
    } completion:done];
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

- (void)ringSelectedBody:(int)planetNumber {
    [stepper selectBody:planetNumber];
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

// Up rolls the wheel on, down rolls it back, a unit per notch of travel
- (void)wheelPanned:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
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
    if (unit != shownUnit) {
        [modeDial setUnit:unit];
        shownUnit = unit;
        if ([EOTimeStepper unitUsesBody:unit] != ringShown) {
            ringShown = [EOTimeStepper unitUsesBody:unit];
            [self layoutStepBlock];
        }
    }
    if (body != shownBody) {
        [bodyRing setBody:body];
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
