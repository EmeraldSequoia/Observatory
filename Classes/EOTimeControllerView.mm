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
static const double lockBadgeSize = 96;             // the padlock (the web's #tp-lock-badge)
static const double lockZoneAlpha = 0.75;           // the padlock while a lift would lock
static const double lockedAlpha = 0.4;              // and once locked, over the faded panel (the two multiply)
static const double keyboardMargin = 8;             // kept between the panel's bottom and the software keyboard

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

static void styleAsEra(UIButton *button, bool bce) {     // the web's #tp-bce, and its .active: BCE in red
    if (bce) {
        styleButton(button, rgb(0x2a, 0x2a, 0x3e), rgb(0xaa, 0x44, 0x44), rgb(0xff, 0x44, 0x44));
    } else {
        styleButton(button, rgb(0x2a, 0x2a, 0x3e), rgb(0x3a, 0x3a, 0x5e), rgb(0x99, 0x99, 0xbb));
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

// A date field: digits from the number pad, the web's monospace look
- (UITextField *)addFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
    field.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightMedium];
    field.textColor = rgb(0xdd, 0xdd, 0xdd);
    field.tintColor = rgb(0x88, 0xaa, 0xff);
    field.textAlignment = NSTextAlignmentCenter;
    field.backgroundColor = rgb(0x2a, 0x2a, 0x3e);
    field.layer.cornerRadius = 6;
    field.layer.borderWidth = 1;
    field.layer.borderColor = rgb(0x44, 0x44, 0x44).CGColor;
    field.placeholder = placeholder;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.keyboardAppearance = UIKeyboardAppearanceDark;
    field.returnKeyType = UIReturnKeyDone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.delegate = self;
    [self addSubview:field];
    [field release];
    return field;
}

- (id)initWithStepper:(EOTimeStepper *)aStepper clock:(EOClock *)aClock {
    if ((self = [super initWithFrame:CGRectMake(0, 0, panelWidth, 100)])) {
        stepper = aStepper;
        clock = aClock;
        bodyRowShown = [EOTimeStepper unitUsesBody:stepper.unit];
        shownUnit = EOTimeStepNumUnits;     // nothing drawn as selected yet
        shownHeld = 0;
        shownBadge = 0;
        offButton = false;
        faded = false;
        shownBCE = false;
        keyboardLift = 0;
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

        // The pair: tap to step, hold to scrub, lift off the button to scrub hands-free.  UIControl keeps
        // tracking a touch wherever it goes, so the release reaches the button however far the finger
        // has wandered, classed inside or outside; the drag events say which side it is on meanwhile.
        UIFont *pairFont = [UIFont systemFontOfSize:20];
        backButton = [self addButtonWithTitle:@"◀" font:pairFont];
        forwardButton = [self addButtonWithTitle:@"▶" font:pairFont];
        styleAsPlain(backButton);
        styleAsPlain(forwardButton);
        for (UIButton *button in [NSArray arrayWithObjects:backButton, forwardButton, nil]) {
            [button addTarget:self action:@selector(stepTouchDown:) forControlEvents:UIControlEventTouchDown];
            [button addTarget:self action:@selector(stepTouchUp:) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchCancel)];
            [button addTarget:self action:@selector(stepTouchUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
            [button addTarget:self action:@selector(stepTouchDragExit:) forControlEvents:UIControlEventTouchDragExit];
            [button addTarget:self action:@selector(stepTouchDragEnter:) forControlEvents:UIControlEventTouchDragEnter];
        }
        stepLabel = [self addLabelWithFont:[UIFont fontWithName:@"Arial-BoldMT" size:15] color:rgb(0xcc, 0xcc, 0xdd)];

        // The date fields, the web's two rows: year / month / day, then CE·BCE / hour / minute.  A value
        // applies when its field ends editing; the era, at once.
        dateCaption = [self addLabelWithFont:[UIFont fontWithName:@"Arial" size:10] color:rgb(0x66, 0x66, 0x77)];
        dateCaption.text = [NSLocalizedString(@"Set date & time", @"caption above the date fields") uppercaseString];
        yearField = [self addFieldWithPlaceholder:@"YYYY"];
        monthField = [self addFieldWithPlaceholder:@"MM"];
        dayField = [self addFieldWithPlaceholder:@"DD"];
        eraButton = [self addButtonWithTitle:NSLocalizedString(@"CE", @"era toggle: Common Era") font:[UIFont fontWithName:@"Arial" size:12]];
        eraButton.layer.cornerRadius = 6;
        styleAsEra(eraButton, false);
        [eraButton addTarget:self action:@selector(eraTapped:) forControlEvents:UIControlEventTouchUpInside];
        hourField = [self addFieldWithPlaceholder:@"HH"];
        minuteField = [self addFieldWithPlaceholder:@"mm"];

        // The padlock, the hands-free tell: over the panel at full alpha while a lift would lock, dimmer once
        // it has.  An image view takes no touches, so the pair keeps tracking beneath it.
        padlock = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"
                                                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:lockBadgeSize]]];
        padlock.tintColor = rgb(0x4c, 0xd9, 0x64);
        padlock.contentMode = UIViewContentModeCenter;
        padlock.hidden = YES;
        [self addSubview:padlock];
        [padlock release];

        [self layoutWidgets];

        // Dragging, from the captions, labels and background only: a touch that begins on a button
        // is the button's (see gestureRecognizer:shouldReceiveTouch:)
        UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        drag.delegate = self;
        [self addGestureRecognizer:drag];
        [drag release];

        // The software keyboard (an iPad without a hardware one) covers the bottom of the screen, where the
        // panel sits: the panel lifts clear of it while a field is edited (keyboardWillChangeFrame:)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:)
                                                     name:UIKeyboardWillChangeFrameNotification object:nil];

        [self refresh];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    y += pairHeight + 8;

    // SET DATE & TIME: two rows of three cells
    dateCaption.frame = CGRectMake(padSide, y, inner, 12);
    y += 12 + 5;
    double cellWidth = (inner - 2 * gap) / 3;
    yearField.frame = CGRectMake(padSide, y, cellWidth, rowHeight);
    monthField.frame = CGRectMake(padSide + cellWidth + gap, y, cellWidth, rowHeight);
    dayField.frame = CGRectMake(padSide + 2 * (cellWidth + gap), y, cellWidth, rowHeight);
    y += rowHeight + gap;
    eraButton.frame = CGRectMake(padSide, y, cellWidth, rowHeight);
    hourField.frame = CGRectMake(padSide + cellWidth + gap, y, cellWidth, rowHeight);
    minuteField.frame = CGRectMake(padSide + 2 * (cellWidth + gap), y, cellWidth, rowHeight);
    y += rowHeight + 4;

    CGRect frame = self.frame;
    frame.size.height = y + padBottom;
    self.frame = frame;
    padlock.frame = self.bounds;     // centred over the whole panel
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
    self.center = CGPointMake(center.x + offset.x, center.y - offset.y - keyboardLift);
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

//// The date fields

- (UITextField *)editingField {
    for (UITextField *field in [NSArray arrayWithObjects:yearField, monthField, dayField, hourField, minuteField, nil]) {
        if ([field isFirstResponder]) {
            return field;
        }
    }
    return nil;
}

// Digits only, and no more of them than the field can mean (a hardware keyboard types anything)
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

// The typed date and time, through the stepper.  A field left empty leaves the time alone; the next
// refresh fills it in again.
- (void)applyDateFields {
    for (UITextField *field in [NSArray arrayWithObjects:yearField, monthField, dayField, hourField, minuteField, nil]) {
        if ([field.text length] == 0) {
            return;
        }
    }
    [stepper setEra:(shownBCE ? 0 : 1) year:[yearField.text intValue] month:[monthField.text intValue] day:[dayField.text intValue]
               hour:[hourField.text intValue] minute:[minuteField.text intValue]];
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

// A touch on the panel's background or captions ends an edit, and so applies it
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self endEditing:YES];
    [super touchesBegan:touches withEvent:event];
}

// The software keyboard's frame, in the canvas: the panel lifts clear of it, as far as the canvas's top
// allows, and comes back down when it goes (the frame then lies below the screen)
- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    if (self.hidden || !self.superview) {
        return;
    }
    CGRect keyboard = [self.superview convertRect:[[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGSize size = self.bounds.size;
    double top = clockCenter.y - offset.y - size.height / 2;        // the panel's edges, unlifted
    double bottom = top + size.height;
    double lift = fmax(0, bottom + keyboardMargin - CGRectGetMinY(keyboard));
    lift = fmin(lift, fmax(0, top));
    if (lift == keyboardLift) {
        return;
    }
    keyboardLift = lift;
    NSTimeInterval duration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        [self placeWithClockCenter:clockCenter halfWidth:halfWidth halfHeight:halfHeight];
    }];
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

    // The date fields follow the time, all but the one being edited (a running clock must not overwrite
    // keystrokes); the era button always does
    ESDateComponents cs;
    [stepper dateComponents:&cs];
    UITextField *editing = [self editingField];
    if (editing != yearField) {
        setFieldText(yearField, [NSString stringWithFormat:@"%d", cs.year]);
    }
    if (editing != monthField) {
        setFieldText(monthField, [NSString stringWithFormat:@"%d", cs.month]);
    }
    if (editing != dayField) {
        setFieldText(dayField, [NSString stringWithFormat:@"%d", cs.day]);
    }
    if (editing != hourField) {
        setFieldText(hourField, [NSString stringWithFormat:@"%d", cs.hour]);
    }
    if (editing != minuteField) {
        setFieldText(minuteField, [NSString stringWithFormat:@"%d", cs.minute]);
    }
    if ((cs.era == 0) != shownBCE) {
        [self showEra:(cs.era == 0)];
    }

    if (unit != shownUnit) {
        for (int i = 0; i < EOTimeStepNumUnits; i++) {
            styleAsChip(chips[i], i == unit, [EOTimeStepper unitIsAstro:(EOTimeStepUnit)i]);
        }
        shownUnit = unit;
    }

    // The held button's look and the fade follow the scrub: on while it runs, off the moment it stops.
    // The fade is alpha only, never hidden: the held button must keep receiving its touch.
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
    // The lock zone: the held finger is off the button, where a lift would lock.  The panel comes back to
    // full alpha with the padlock, so the outcome is visible before it happens; back on the button it
    // fades again.  Locked, the padlock stays, dimmer, over the faded panel.
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
            self.alpha = faded ? scrubAlpha : 1.0;
        }];
    }
}

- (void)prepareToHide {
    [self endEditing:YES];      // a pending edit applies; the keyboard goes
    keyboardLift = 0;
    [stepper endPress];
    offButton = false;
    [self refresh];
}

@end
