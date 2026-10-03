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

// Geometry, in canvas units: the web panel's CSS values, with a sixth chip column for "cent"
static const double panelWidth = 308;
static const double padTop = 10;
static const double padSide = 12;
static const double padBottom = 12;
static const double rowHeight = 44;         // transport buttons, chips, the body row
static const double pairHeight = 56;        // the ◀ ▶ buttons
static const double gap = 4;
static const int    chipColumns = 6;        // a short last row stretches its chips to the same width
static const double panelRadius = 14;
static const double buttonRadius = 8;
static const double cornerMarginRight = 12;
static const double cornerMarginBottom = 56;    // clear of the Options (i) button at the window's lower right
static const double scrubAlpha = 0.38;          // the panel while a scrub runs (the web's tuned level)
static const NSTimeInterval fadeDuration = 0.15;
static const NSTimeInterval flashDuration = 0.3;    // a pair button after a search that found nothing

static UIColor *rgb(int r, int g, int b) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
}

// The looks a button can have: the web's .tp-btn, .tp-btn.holding, .tp-btn.flash-fail,
// .tp-chip, .tp-chip-astro and their .active states
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

static void styleAsActive(UIButton *button) {     // the web's .tp-btn.active: ‖ while the clock runs
    styleButton(button, rgb(0x44, 0x44, 0x55), rgb(0x88, 0xaa, 0xff), rgb(0x88, 0xaa, 0xff));
}

static void styleAsFailed(UIButton *button) {
    styleButton(button, rgb(0x44, 0x33, 0x22), rgb(0x77, 0x55, 0x44), rgb(0xaa, 0x88, 0x66));
}

static void styleAsChip(UIButton *button, bool selected, bool astro) {
    if (selected) {
        styleButton(button, rgb(0x2a, 0x2a, 0x3e), rgb(0x88, 0xaa, 0xff), rgb(0x88, 0xaa, 0xff));
    } else if (astro) {   // tinted, so the group reads as one
        styleButton(button, rgb(0x1e, 0x25, 0x36), rgb(0x34, 0x40, 0x5c), rgb(0x7a, 0x8a, 0xa8));
    } else {
        styleButton(button, rgb(0x22, 0x22, 0x38), rgb(0x3a, 0x3a, 0x5e), rgb(0x77, 0x77, 0x88));
    }
}

// Write a label only when its text changes: refresh runs twenty times a second
static void setLabelText(UILabel *label, NSString *text) {
    if (![label.text isEqualToString:text]) {
        label.text = text;
    }
}

@implementation EOTimeControllerView

- (UIButton *)addButtonWithTitle:(NSString *)title font:(UIFont *)font {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = font;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.layer.cornerRadius = buttonRadius;
    button.layer.borderWidth = 1;
    [button setTitleColor:rgb(0xcc, 0xcc, 0xff) forState:UIControlStateHighlighted];   // a tap's feedback (the web's hover colour)
    [self addSubview:button];
    return button;
}

- (UILabel *)addLabelWithFont:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = font;
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.adjustsFontSizeToFitWidth = YES;
    [self addSubview:label];
    [label release];
    return label;
}

- (id)initWithStepper:(EOTimeStepper *)aStepper clock:(EOClock *)aClock {
    if ((self = [super initWithFrame:CGRectMake(0, 0, panelWidth, 100)])) {
        stepper = aStepper;
        clock = aClock;
        bodyRowShown = [EOTimeStepper unitUsesBody:stepper.unit];
        shownUnit = EOTimeStepNumUnits;     // nothing drawn as selected yet
        shownHeld = 0;
        faded = false;
        userMoved = false;

        self.opaque = NO;
        self.backgroundColor = [UIColor colorWithRed:26/255.0 green:26/255.0 blue:46/255.0 alpha:0.96];
        self.layer.cornerRadius = panelRadius;
        self.layer.borderWidth = 1;
        self.layer.borderColor = rgb(0x3a, 0x3a, 0x5e).CGColor;
        self.hidden = YES;

        // The widgets, top to bottom; layoutWidgets gives them their frames
        nowButton = [self addButtonWithTitle:[NSString stringWithFormat:@"%@ ▶", NSLocalizedString(@"Now", @"button: return the clock to the present")]
                                        font:[UIFont fontWithName:@"Arial" size:15]];
        styleAsPlain(nowButton);
        [nowButton addTarget:self action:@selector(nowPressed:) forControlEvents:UIControlEventTouchDown];
        // ‖ while the clock runs, ◀ ▶ while it is stopped; like Now, they act on the press
        UIFont *transportFont = [UIFont systemFontOfSize:16];
        pauseButton = [self addButtonWithTitle:@"‖" font:transportFont];
        styleAsActive(pauseButton);
        [pauseButton addTarget:self action:@selector(pausePressed:) forControlEvents:UIControlEventTouchDown];
        reverseButton = [self addButtonWithTitle:@"◀" font:transportFont];
        styleAsPlain(reverseButton);
        [reverseButton addTarget:self action:@selector(reversePressed:) forControlEvents:UIControlEventTouchDown];
        playButton = [self addButtonWithTitle:@"▶" font:transportFont];
        styleAsPlain(playButton);
        [playButton addTarget:self action:@selector(playPressed:) forControlEvents:UIControlEventTouchDown];
        closeButton = [self addButtonWithTitle:@"×" font:[UIFont systemFontOfSize:24]];
        styleButton(closeButton, [UIColor clearColor], [UIColor clearColor], rgb(0x66, 0x66, 0x77));
        [closeButton addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];

        statusLabel = [self addLabelWithFont:[UIFont fontWithName:@"Arial" size:11] color:rgb(0x88, 0xaa, 0xff)];

        stepByLabel = [self addLabelWithFont:[UIFont fontWithName:@"Arial" size:10] color:rgb(0x66, 0x66, 0x77)];
        stepByLabel.text = [NSLocalizedString(@"Step by", @"caption above the unit chips") uppercaseString];
        UIFont *chipFont = [UIFont fontWithName:@"Arial" size:12];
        for (int i = 0; i < EOTimeStepNumUnits; i++) {
            chips[i] = [self addButtonWithTitle:[EOTimeStepper labelForUnit:(EOTimeStepUnit)i] font:chipFont];
            chips[i].tag = i;
            styleAsChip(chips[i], false, [EOTimeStepper unitIsAstro:(EOTimeStepUnit)i]);
            [chips[i] addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        }

        // ‹ Body ›, for rise / set / transit
        UIFont *glyphFont = [UIFont systemFontOfSize:22];
        bodyPrevButton = [self addButtonWithTitle:@"‹" font:glyphFont];
        bodyNextButton = [self addButtonWithTitle:@"›" font:glyphFont];
        styleAsPlain(bodyPrevButton);
        styleAsPlain(bodyNextButton);
        [bodyPrevButton addTarget:self action:@selector(bodyStepped:) forControlEvents:UIControlEventTouchUpInside];
        [bodyNextButton addTarget:self action:@selector(bodyStepped:) forControlEvents:UIControlEventTouchUpInside];
        bodyLabel = [self addLabelWithFont:[UIFont fontWithName:@"Arial" size:15] color:rgb(0x88, 0xaa, 0xff)];

        // The pair: tap to step, hold to scrub.  UIControl keeps tracking a touch wherever it goes,
        // so the release reaches the button however far the finger has wandered.
        UIFont *pairFont = [UIFont systemFontOfSize:20];
        backButton = [self addButtonWithTitle:@"◀" font:pairFont];
        forwardButton = [self addButtonWithTitle:@"▶" font:pairFont];
        styleAsPlain(backButton);
        styleAsPlain(forwardButton);
        for (UIButton *button in [NSArray arrayWithObjects:backButton, forwardButton, nil]) {
            [button addTarget:self action:@selector(stepTouchDown:) forControlEvents:UIControlEventTouchDown];
            [button addTarget:self action:@selector(stepTouchUp:)
                 forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];
        }
        stepLabel = [self addLabelWithFont:[UIFont fontWithName:@"Arial-BoldMT" size:15] color:rgb(0xcc, 0xcc, 0xdd)];

        [self layoutWidgets];

        // Dragging, from the captions, labels and background only: a touch that begins on a button
        // is the button's (see gestureRecognizer:shouldReceiveTouch:)
        UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        drag.delegate = self;
        [self addGestureRecognizer:drag];
        [drag release];

        [self refresh];
    }
    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    // The widgets are the view hierarchy's; the stepper and the clock are not ours
    [super dealloc];
}

//// Layout

// Frames for every widget, top to bottom, and the panel's height to match; the body row is laid
// out only while a rise / set / transit unit is selected
- (void)layoutWidgets {
    double inner = panelWidth - 2 * padSide;
    double y = padTop;

    // The top row: the transport, and the close ×
    [self layoutTransportRow];
    closeButton.frame = CGRectMake(padSide + inner - rowHeight, y, rowHeight, rowHeight);
    y += rowHeight + 6;

    statusLabel.frame = CGRectMake(padSide, y, inner, 14);
    y += 14 + 8;

    // "STEP BY" and the chips, six to a row; a short last row's chips share its width
    stepByLabel.frame = CGRectMake(padSide, y, inner, 12);
    y += 12 + 5;
    for (int first = 0; first < EOTimeStepNumUnits; first += chipColumns) {
        int count = EOTimeStepNumUnits - first;
        if (count > chipColumns) {
            count = chipColumns;
        }
        double chipWidth = (inner - (count - 1) * gap) / count;
        for (int i = 0; i < count; i++) {
            chips[first + i].frame = CGRectMake(padSide + i * (chipWidth + gap), y, chipWidth, rowHeight);
        }
        y += rowHeight + gap;
    }
    y += 8 - gap;

    // ‹ Body ›
    bodyPrevButton.hidden = bodyNextButton.hidden = bodyLabel.hidden = !bodyRowShown;
    if (bodyRowShown) {
        bodyPrevButton.frame = CGRectMake(padSide, y, rowHeight, rowHeight);
        bodyNextButton.frame = CGRectMake(padSide + inner - rowHeight, y, rowHeight, rowHeight);
        bodyLabel.frame = CGRectMake(padSide + rowHeight + 6, y, inner - 2 * rowHeight - 12, rowHeight);
        y += rowHeight + 8;
    }

    // The pair
    backButton.frame = CGRectMake(padSide, y, pairHeight, pairHeight);
    forwardButton.frame = CGRectMake(padSide + inner - pairHeight, y, pairHeight, pairHeight);
    stepLabel.frame = CGRectMake(padSide + pairHeight + 6, y, inner - 2 * pairHeight - 12, pairHeight);
    y += pairHeight + 4;

    CGRect frame = self.frame;
    frame.size.height = y + padBottom;
    self.frame = frame;
}

// The transport, left of the ×: Now ▶ while the time is not the present, then ‖ while the clock runs
// or ◀ ▶ while it is stopped.  The buttons present share the row, as the web's do; laid out again
// only when that set changes (refresh), so a pressed button keeps its frame under the finger.
- (void)layoutTransportRow {
    shownAtPresent = [stepper isAtPresent];
    shownRunning = [stepper isRunning];
    nowButton.hidden = shownAtPresent;
    pauseButton.hidden = !shownRunning;
    reverseButton.hidden = shownRunning;
    playButton.hidden = shownRunning;
    NSMutableArray *row = [NSMutableArray arrayWithCapacity:3];
    for (UIButton *button in [NSArray arrayWithObjects:nowButton, pauseButton, reverseButton, playButton, nil]) {
        if (button.hidden) {
            button.highlighted = NO;    // a press can hide the button it landed on, mid-touch
        } else {
            [row addObject:button];
        }
    }
    double inner = panelWidth - 2 * padSide;
    double width = (inner - rowHeight - gap - ([row count] - 1) * gap) / [row count];
    double x = padSide;
    for (UIButton *button in row) {
        button.frame = CGRectMake(x, padTop, width, rowHeight);
        x += width + gap;
    }
}

- (void)setBodyRowShown:(bool)shown {
    if (shown == bodyRowShown) {
        return;
    }
    double oldHeight = self.bounds.size.height;
    bodyRowShown = shown;
    [self layoutWidgets];
    if (userMoved) {
        // Grow and shrink from the bottom edge, where the pair is, so the buttons stay put under the finger
        offset.y += (self.bounds.size.height - oldHeight) / 2;
    }
    [self placeWithClockCenter:clockCenter halfWidth:halfWidth halfHeight:halfHeight];
}

//// Placement

- (void)placeWithClockCenter:(CGPoint)center halfWidth:(double)halfW halfHeight:(double)halfH {
    clockCenter = center;
    halfWidth = halfW;
    halfHeight = halfH;
    CGSize size = self.bounds.size;
    if (!userMoved) {
        offset.x = halfW - cornerMarginRight - size.width / 2;
        offset.y = -(halfH - cornerMarginBottom - size.height / 2);
    }
    // Wherever it came from, keep the whole panel on the canvas
    double maxX = halfW - size.width / 2;
    double maxY = halfH - size.height / 2;
    offset.x = fmax(-maxX, fmin(maxX, offset.x));
    offset.y = fmax(-maxY, fmin(maxY, offset.y));
    self.center = CGPointMake(center.x + offset.x, center.y - offset.y);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    // A pan does not overlap a button's default action, so UIKit would otherwise let the recogniser
    // take a touch that began on the pair and cancel the hold.  Drags start elsewhere on the panel.
    return ![touch.view isKindOfClass:[UIControl class]];
}

- (void)drag:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:self.superview];
    offset.x += translation.x;
    offset.y -= translation.y;      // offset is y up
    userMoved = true;
    [recognizer setTranslation:CGPointZero inView:self.superview];
    [self placeWithClockCenter:clockCenter halfWidth:halfWidth halfHeight:halfHeight];
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

- (void)closeTapped:(UIButton *)sender {
    [clock closeTimePanel];
}

- (void)chipTapped:(UIButton *)sender {
    [stepper selectUnit:(EOTimeStepUnit)sender.tag];
    [self refresh];
}

- (void)bodyStepped:(UIButton *)sender {
    [stepper stepBody:(sender == bodyNextButton ? 1 : -1)];
    [self refresh];
}

- (void)stepTouchDown:(UIButton *)sender {
    if (![stepper pressInDirection:(sender == forwardButton ? 1 : -1)]) {
        [self flashFailure:sender];     // an astro search found no event here
    }
    [self refresh];
}

- (void)stepTouchUp:(UIButton *)sender {
    [stepper endPress];
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

//// Keeping the panel current

- (void)refresh {
    EOTimeStepUnit unit = stepper.unit;
    [self setBodyRowShown:[EOTimeStepper unitUsesBody:unit]];

    setLabelText(statusLabel, [stepper statusString]);
    if ([stepper isAtPresent] != shownAtPresent || [stepper isRunning] != shownRunning) {
        [self layoutTransportRow];
    }
    NSString *bodyName = [Utilities nameOfPlanetWithNumber:(ECPlanetNumber)[stepper bodyPlanetNumber]];
    setLabelText(bodyLabel, bodyName);
    setLabelText(stepLabel, [stepper stepLabelWithBodyName:bodyName]);

    if (unit != shownUnit) {
        for (int i = 0; i < EOTimeStepNumUnits; i++) {
            styleAsChip(chips[i], i == unit, [EOTimeStepper unitIsAstro:(EOTimeStepUnit)i]);
        }
        shownUnit = unit;
    }

    // The held button's look and the fade follow the scrub: on while it runs, off the moment it stops.
    // The fade is alpha only, never hidden: the held button must keep receiving its touch.
    int held = [stepper isScrubbing] ? stepper.scrubDirection : 0;
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
    bool shouldFade = (held != 0);
    if (shouldFade != faded) {
        faded = shouldFade;
        [UIView animateWithDuration:fadeDuration animations:^{
            self.alpha = faded ? scrubAlpha : 1.0;
        }];
    }
}

- (void)prepareToHide {
    [stepper endPress];
    [self refresh];
}

@end
