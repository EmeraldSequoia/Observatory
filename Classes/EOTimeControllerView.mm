//
//  EOTimeControllerView.mm
//  Emerald Observatory
//
//  See EOTimeControllerView.h.
//

#import "EOTimeControllerView.h"
#import "EOClock.h"
#import <QuartzCore/QuartzCore.h>

// Geometry, in canvas units: the web panel's CSS values, with a sixth chip column for "cent"
static const double panelWidth = 308;
static const double padTop = 10;
static const double padSide = 12;
static const double padBottom = 12;
static const double rowHeight = 44;         // transport buttons, chips
static const double pairHeight = 56;        // the ◀ ▶ buttons
static const double gap = 4;
static const int    chipColumns = 6;
static const double panelRadius = 14;
static const double buttonRadius = 8;
static const double cornerMarginRight = 12;
static const double cornerMarginBottom = 56;    // clear of the Options (i) button at the window's lower right
static const double scrubAlpha = 0.38;          // the panel while a scrub runs (the web's tuned level)
static const NSTimeInterval fadeDuration = 0.15;

static UIColor *rgb(int r, int g, int b) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
}

// The looks a button can have: the web's .tp-btn, .tp-btn.holding, .tp-chip and .tp-chip.active
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

static void styleAsChip(UIButton *button, bool selected) {
    if (selected) {
        styleButton(button, rgb(0x2a, 0x2a, 0x3e), rgb(0x88, 0xaa, 0xff), rgb(0x88, 0xaa, 0xff));
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

- (UIButton *)addButtonWithTitle:(NSString *)title frame:(CGRect)frame font:(UIFont *)font {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
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

- (UILabel *)addLabelWithFrame:(CGRect)frame font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
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

        UIFont *chipFont = [UIFont fontWithName:@"Arial" size:12];
        UIFont *glyphFont = [UIFont systemFontOfSize:20];
        double inner = panelWidth - 2 * padSide;
        double y = padTop;

        // The top row: Now (the transport's other buttons arrive with the running modes), and the close ×
        nowButton = [self addButtonWithTitle:[NSString stringWithFormat:@"%@ ▶", NSLocalizedString(@"Now", @"button: return the clock to the present")]
                                       frame:CGRectMake(padSide, y, inner - rowHeight - gap, rowHeight)
                                        font:[UIFont fontWithName:@"Arial" size:15]];
        styleAsPlain(nowButton);
        [nowButton addTarget:self action:@selector(nowPressed:) forControlEvents:UIControlEventTouchDown];
        closeButton = [self addButtonWithTitle:@"×"
                                         frame:CGRectMake(padSide + inner - rowHeight, y, rowHeight, rowHeight)
                                          font:[UIFont systemFontOfSize:24]];
        styleButton(closeButton, [UIColor clearColor], [UIColor clearColor], rgb(0x66, 0x66, 0x77));
        [closeButton addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
        y += rowHeight + 6;

        // The status line
        statusLabel = [self addLabelWithFrame:CGRectMake(padSide, y, inner, 14)
                                         font:[UIFont fontWithName:@"Arial" size:11]
                                        color:rgb(0x88, 0xaa, 0xff)];
        y += 14 + 8;

        // "STEP BY" and the chips: six columns, the chips of a short second row the same width as the first's
        stepByLabel = [self addLabelWithFrame:CGRectMake(padSide, y, inner, 12)
                                         font:[UIFont fontWithName:@"Arial" size:10]
                                        color:rgb(0x66, 0x66, 0x77)];
        stepByLabel.text = [NSLocalizedString(@"Step by", @"caption above the unit chips") uppercaseString];
        y += 12 + 5;
        double chipWidth = (inner - (chipColumns - 1) * gap) / chipColumns;
        for (int i = 0; i < EOTimeStepNumUnits; i++) {
            int row = i / chipColumns;
            int column = i % chipColumns;
            CGRect frame = CGRectMake(padSide + column * (chipWidth + gap), y + row * (rowHeight + gap), chipWidth, rowHeight);
            chips[i] = [self addButtonWithTitle:[EOTimeStepper labelForUnit:(EOTimeStepUnit)i] frame:frame font:chipFont];
            chips[i].tag = i;
            styleAsChip(chips[i], false);
            [chips[i] addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        }
        int chipRows = (EOTimeStepNumUnits + chipColumns - 1) / chipColumns;
        y += chipRows * rowHeight + (chipRows - 1) * gap + 8;

        // The pair: tap to step, hold to scrub.  UIControl keeps tracking a touch wherever it goes,
        // so the release reaches the button however far the finger has wandered.
        backButton = [self addButtonWithTitle:@"◀" frame:CGRectMake(padSide, y, pairHeight, pairHeight) font:glyphFont];
        forwardButton = [self addButtonWithTitle:@"▶" frame:CGRectMake(padSide + inner - pairHeight, y, pairHeight, pairHeight) font:glyphFont];
        styleAsPlain(backButton);
        styleAsPlain(forwardButton);
        for (UIButton *button in [NSArray arrayWithObjects:backButton, forwardButton, nil]) {
            [button addTarget:self action:@selector(stepTouchDown:) forControlEvents:UIControlEventTouchDown];
            [button addTarget:self action:@selector(stepTouchUp:)
                 forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];
        }
        stepLabel = [self addLabelWithFrame:CGRectMake(padSide + pairHeight + 6, y, inner - 2 * pairHeight - 12, pairHeight)
                                       font:[UIFont fontWithName:@"Arial-BoldMT" size:15]
                                      color:rgb(0xcc, 0xcc, 0xdd)];
        y += pairHeight + 4;

        CGRect frame = self.frame;
        frame.size.height = y + padBottom;
        self.frame = frame;

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
    // The widgets are the view hierarchy's; the stepper and the clock are not ours
    [super dealloc];
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

- (void)closeTapped:(UIButton *)sender {
    [clock closeTimePanel];
}

- (void)chipTapped:(UIButton *)sender {
    [stepper selectUnit:(EOTimeStepUnit)sender.tag];
    [self refresh];
}

- (void)stepTouchDown:(UIButton *)sender {
    [stepper pressInDirection:(sender == forwardButton ? 1 : -1)];
    [self refresh];
}

- (void)stepTouchUp:(UIButton *)sender {
    [stepper endPress];
    [self refresh];
}

//// Keeping the panel current

- (void)refresh {
    setLabelText(statusLabel, [stepper statusString]);
    setLabelText(stepLabel, [stepper stepLabel]);

    EOTimeStepUnit unit = stepper.unit;
    if (unit != shownUnit) {
        for (int i = 0; i < EOTimeStepNumUnits; i++) {
            styleAsChip(chips[i], i == unit);
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
