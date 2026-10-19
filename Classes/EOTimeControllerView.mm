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
#include <algorithm>
#include <vector>

// Geometry, in canvas units.  The blocks cover the small dials (radius 60, the eclipse ring 63) with their
// labels; landscape's are taller, each pair filling its side's column between the Moon or the map and the
// big date.
static const double portraitBlockWidth = 130;
static const double portraitBlockHeight = 130;
static const double landscapeBlockWidth = 170;
static const double landscapeBlockHeight = 215;
static const double blockPad = 8;
static const double statusHeight = 30;          // the status over Now: two lines, for a scrub at the limit
static const double offsetHeight = 16;          // and under it, the offset from the real time
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
static const double doneGap = 6;                // between Set / Done and the wheels either side
static const double keyboardGap = 8;            // before the keyboard button
static const double eraWidth = 40;
static const double yearWidth = 47.5;           // the wheels' windows; each has its thumbwheel's rim beside it
static const double wheelWidth = 31;            // month, day, hour, minute, second
static const double notch = 20;                 // a wheel drag's travel per unit rolled, half of it to the next
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
//// A pair button: the visible button (its face) drawn inside a larger, invisible target.  The target is the
//// button's frame; with a target circle, only the part of the frame inside that circle takes touches, so
//// that what lies beyond it (the body dial's band) gets them instead.

@interface EOPairButton : UIButton {
    UIView    *face;
    UILabel   *glyph;
    UIColor   *glyphColor;
    CGPoint   circleCenter;     // in the button's coordinates
    double    circleRadius;     // 0: the whole frame is the target
}
@property (readonly) UIView *face;
- (void)setGlyph:(NSString *)text font:(UIFont *)font;
- (void)setGlyphColor:(UIColor *)color;
- (void)setFaceFrame:(CGRect)rect;
- (void)setTargetCircleCenter:(CGPoint)center radius:(double)radius;
@end

@implementation EOPairButton

@synthesize face;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        face = [[UIView alloc] initWithFrame:CGRectZero];
        face.userInteractionEnabled = NO;
        face.layer.borderWidth = 1;
        [self addSubview:face];
        [face release];
        glyph = [[UILabel alloc] initWithFrame:CGRectZero];
        glyph.textAlignment = NSTextAlignmentCenter;
        glyph.backgroundColor = [UIColor clearColor];
        [face addSubview:glyph];
        [glyph release];
        circleRadius = 0;
    }
    return self;
}

- (void)dealloc {
    [glyphColor release];
    [super dealloc];
}

- (void)setGlyph:(NSString *)text font:(UIFont *)font {
    glyph.text = text;
    glyph.font = font;
}

- (void)setGlyphColor:(UIColor *)color {
    [glyphColor release];
    glyphColor = [color retain];
    glyph.textColor = self.highlighted ? [UIColor colorWithRed:0xcc/255.0 green:0xcc/255.0 blue:1 alpha:1] : color;
}

// A press's feedback, the other buttons' highlighted title colour (the web's hover colour)
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    glyph.textColor = highlighted ? [UIColor colorWithRed:0xcc/255.0 green:0xcc/255.0 blue:1 alpha:1] : glyphColor;
}

- (void)setFaceFrame:(CGRect)rect {
    face.frame = rect;
    face.layer.cornerRadius = 8;
    glyph.frame = face.bounds;
}

- (void)setTargetCircleCenter:(CGPoint)center radius:(double)radius {
    circleCenter = center;
    circleRadius = radius;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (![super pointInside:point withEvent:event]) {
        return NO;
    }
    return circleRadius <= 0 || hypot(point.x - circleCenter.x, point.y - circleCenter.y) < circleRadius;
}

@end

static void styleButton(UIButton *button, UIColor *background, UIColor *border, UIColor *text) {
    if ([button isKindOfClass:[EOPairButton class]]) {
        EOPairButton *pair = (EOPairButton *)button;
        pair.face.backgroundColor = background;
        pair.face.layer.borderColor = border.CGColor;
        [pair setGlyphColor:text];
        return;
    }
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

// A wheel's field.  Rolling, it is invisible: its thumbwheel beneath it shows the value.  Typing, while the
// keyboard switch is on: a plain white field over the thumbwheel's window.
static void styleWheel(UITextField *field, bool typing) {
    if (typing) {
        field.backgroundColor = [UIColor whiteColor];
        field.textColor = rgb(0x11, 0x11, 0x22);
        field.layer.borderWidth = 2;
        field.layer.borderColor = rgb(0x88, 0xaa, 0xff).CGColor;
        field.layer.cornerRadius = 4;
    } else {
        field.backgroundColor = [UIColor clearColor];
        field.textColor = [UIColor clearColor];
        field.layer.borderWidth = 0;
    }
}

// A wheel's field: digits only, with no edit menu (a Mac's right click, a long press) and nothing to cut,
// copy, paste or look up in it
@interface EOWheelField : UITextField
@end

@implementation EOWheelField

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return NO;
}

@end

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
//// anywhere on it turns the handle to the nearest position, and a drag around it keeps turning.

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

// A ship's engine order telegraph's handle, framing a dial's selected position: in its own frame, x out
// along that position's radius, a wedge narrow at the hub, its sides reaching the rim halfway between the full
// tick midway to each neighbour and the half tick before it, its end following the rim, its corners rounded;
// and a stem back to the hub it turns on.  Drawn in outline, so the selection shows through.  With a start
// radius, the wedge begins there instead, with no stem: where the dial's middle is taken by other things.
static void drawHandle(CGContextRef context, CGPoint c, double angle, double rim, double hubR, double step, UIColor *color, double start) {
    bool stem = (start == 0);
    double inner = stem ? hubR * 1.8 : start;
    double outer = rim - 0.5;
    double innerHalf = hubR * 0.35;
    double spread = 3.5 / 8 * step;     // the full tick is at 4/8 of a step from a position, the half tick at 3/8
    double corner = 3.5;                // the rounding where the sides meet the rim
    double cornerAngle = corner / outer;
    CGPoint first = CGPointMake(outer * cos(spread), -outer * sin(spread));
    CGPoint second = CGPointMake(outer * cos(spread), outer * sin(spread));
    CGMutablePathRef loop = CGPathCreateMutable();
    CGPathMoveToPoint(loop, NULL, inner, -innerHalf);
    // Each corner turns from the side onto the rim's tangent there, and the end follows the rim between them
    CGPathAddArcToPoint(loop, NULL, first.x, first.y, first.x + sin(spread), first.y + cos(spread), corner);
    CGPathAddArc(loop, NULL, 0, 0, outer, -spread + cornerAngle, spread - cornerAngle, false);
    CGPathAddArcToPoint(loop, NULL, second.x, second.y, inner, innerHalf, corner);
    CGPathAddLineToPoint(loop, NULL, inner, innerHalf);
    CGPathAddArc(loop, NULL, inner, 0, innerHalf, M_PI / 2, 3 * M_PI / 2, false);
    CGPathCloseSubpath(loop);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, c.x, c.y);
    CGContextRotateCTM(context, angle - M_PI / 2);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetLineWidth(context, 2);
    CGContextAddPath(context, loop);
    CGContextStrokePath(context);
    if (stem) {
        CGContextMoveToPoint(context, 0, 0);
        CGContextAddLineToPoint(context, inner - innerHalf, 0);
        CGContextStrokePath(context);
    }
    CGContextRestoreGState(context);
    CGPathRelease(loop);
}

// The graduations around a dial of n positions, eight to a gap but none within clear (an angle) of a
// position: full ticks midway between them, half ticks at the quarters, short ones between
static void drawGraduations(CGContextRef context, CGPoint c, int n, double rim, double band, double clear) {
    double step = 2 * M_PI / n;
    CGContextSetStrokeColorWithColor(context, [UIColor lightGrayColor].CGColor);
    for (int k = 0; k < n * 8; k++) {
        int sub = k % 8;
        double a = k * step / 8;
        double fromPosition = fmin(sub, 8 - sub) * step / 8;
        if (fromPosition < clear) {
            continue;
        }
        double length = (sub == 4) ? band : ((sub % 2 == 0) ? band * 0.6 : band * 0.35);
        CGContextSetLineWidth(context, sub == 4 ? 1.2 : 0.8);
        CGContextMoveToPoint(context, c.x + (rim - length) * sin(a), c.y - (rim - length) * cos(a));
        CGContextAddLineToPoint(context, c.x + rim * sin(a), c.y - rim * cos(a));
        CGContextStrokePath(context);
    }
}

// After the Moon azimuth dial, simplified: a line around the rim with the graduations inside it, and faint
// spokes from a small hub.  The positions' words, full and capitalized, in the azimuth dial's Arial, lie
// radially out to the rim, the calendar units reading out from the centre and the astronomical events in
// toward it; the graduations fill the gaps between them.  The selection is a ship's engine order telegraph's
// handle: an open, tapered loop in gold from the hub to the rim, framing the selected word.
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint c = [self hub];
    double rim = [self rimRadius];
    double band = rim * 0.17;
    double hubR = rim * 0.1;
    double wordsOuter = rim - 3;
    double wordsInner = rim * 0.26;
    double step = 2 * M_PI / (int)EOTimeStepNumUnits;

    // The words, all at one size whatever is selected: the largest at which the longest fits between the hub
    // and the rim
    double size = rim * 0.2;
    UIFont *font;
    double widest;
    do {
        font = [UIFont fontWithName:@"Arial" size:size];
        widest = 0;
        for (int i = 0; i < EOTimeStepNumUnits; i++) {
            widest = fmax(widest, [[EOTimeStepper dialLabelForUnit:(EOTimeStepUnit)i] sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width);
        }
        size -= 0.25;
    } while (widest > wordsOuter - wordsInner && size > 5);

    // The rim: a single line, the graduations inside it
    CGContextSetLineWidth(context, 0.5);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 0.6);
    CGContextAddArc(context, c.x, c.y, rim, 0, 2 * M_PI, 0);
    CGContextStrokePath(context);

    // Spokes between the positions, as the azimuth dial's between its compass points
    drawTicks(context, c, EOTimeStepNumUnits, hubR, rim - band, 1, [UIColor colorWithRed:0.3 green:0.3 blue:0.9 alpha:0.35], 0.5);

    // The graduations between the words, none where a word crosses them
    drawGraduations(context, c, EOTimeStepNumUnits, rim, band, (font.lineHeight / 2 + 1.5) / (rim - band));

    UIColor *white = [UIColor colorWithWhite:1 alpha:0.85];
    UIColor *blue = [UIColor colorWithRed:0.65 green:0.75 blue:1 alpha:0.9];
    for (int i = 0; i < EOTimeStepNumUnits; i++) {
        NSString *label = [EOTimeStepper dialLabelForUnit:(EOTimeStepUnit)i];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName,
                                                 ([EOTimeStepper unitIsAstro:(EOTimeStepUnit)i] ? blue : white), NSForegroundColorAttributeName, nil];
        CGSize extent = [label sizeWithAttributes:attributes];
        double angle = i * step;
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, c.x, c.y);
        if (![EOTimeStepper unitIsAstro:(EOTimeStepUnit)i]) {
            // The calendar units: along the radius, reading outward, ending at the rim
            CGContextRotateCTM(context, angle - M_PI / 2);
            [label drawAtPoint:CGPointMake(wordsOuter - extent.width, -extent.height / 2) withAttributes:attributes];
        } else {
            // The astronomical events: turned around, reading inward, starting at the rim
            CGContextRotateCTM(context, angle + M_PI / 2);
            [label drawAtPoint:CGPointMake(-wordsOuter, -extent.height / 2) withAttributes:attributes];
        }
        CGContextRestoreGState(context);
    }

    // The handle, always the same, framing the selected word
    UIColor *gold = [UIColor colorWithRed:1 green:0xc1/256.0 blue:0x25/256.0 alpha:1];      // the clock's minute hand
    drawHandle(context, c, (int)unit * step, rim, hubR, step, gold, 0);

    // The hub the handle turns on
    CGContextSetLineWidth(context, 1);
    CGContextSetStrokeColorWithColor(context, gold.CGColor);
    CGContextSetRGBFillColor(context, 0.15, 0.15, 0.15, 1);
    CGContextAddArc(context, c.x, c.y, hubR, 0, 2 * M_PI, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
}

// The position nearest a point on the rim
- (EOTimeStepUnit)unitAtPoint:(CGPoint)point {
    CGPoint hub = [self hub];
    double angle = atan2(point.x - hub.x, hub.y - point.y);     // clockwise from the top
    if (angle < 0) {
        angle += 2 * M_PI;
    }
    int i = (int)lround(angle / (2 * M_PI / (int)EOTimeStepNumUnits)) % EOTimeStepNumUnits;
    return (EOTimeStepUnit)i;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [controller dialSelectedUnit:[self unitAtPoint:[[touches anyObject] locationInView:self]]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [controller dialSelectedUnit:[self unitAtPoint:[[touches anyObject] locationInView:self]]];
}

@end

//// The body dial, for rise / set / transit: as large as the mode dial, a line around the rim with graduations
//// between the bodies' symbols, which are spread evenly around it clockwise from the Sun at the top, and the
//// same telegraph handle framing the selected one, across the band only.  A touch on the symbols' band picks the nearest, and a drag
//// around it keeps picking; the middle is the pair's, and takes no touches.

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

- (CGPoint)hub {
    return CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
}

- (double)rimRadius {
    return fmin(self.bounds.size.width, self.bounds.size.height) / 2 - 1;     // as the mode dial's
}

- (double)symbolSize {
    return [self rimRadius] * 0.24;
}

- (double)symbolRadius {
    return [self rimRadius] - [self symbolSize] * 0.75;
}

- (double)innerRadius {
    return [self symbolRadius] - [self symbolSize] * 0.65;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint c = [self hub];
    double rim = [self rimRadius];
    double r = [self symbolRadius];
    double size = [self symbolSize];
    int n = [EOTimeStepper numBodies];
    double step = 2 * M_PI / n;

    CGContextSetLineWidth(context, 0.5);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 0.6);
    CGContextAddArc(context, c.x, c.y, rim, 0, 2 * M_PI, 0);
    CGContextStrokePath(context);
    drawGraduations(context, c, n, rim, rim * 0.17, (size * 0.6 + 1.5) / r);

    UIFont *font = [UIFont systemFontOfSize:size];
    for (int i = 0; i < n; i++) {
        double a = i * step;
        CGPoint p = CGPointMake(c.x + r * sin(a), c.y - r * cos(a));
        NSString *symbol = symbolForBody([EOTimeStepper bodyAtIndex:i]);
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName,
                                                 [UIColor colorWithRed:0.65 green:0.75 blue:1 alpha:0.9], NSForegroundColorAttributeName, nil];
        CGSize extent = [symbol sizeWithAttributes:attributes];
        [symbol drawAtPoint:CGPointMake(p.x - extent.width / 2, p.y - extent.height / 2) withAttributes:attributes];
    }

    for (int i = 0; i < n; i++) {
        if ([EOTimeStepper bodyAtIndex:i] == body) {
            // From the band's inner edge only: the pair and its label have the middle
            drawHandle(context, c, i * step, rim, rim * 0.1, step, [UIColor colorWithRed:1 green:0xc1/256.0 blue:0x25/256.0 alpha:1],
                       [self innerRadius] - 2);
        }
    }
}

// Only the band the symbols are in takes touches
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint c = [self hub];
    double d = hypot(point.x - c.x, point.y - c.y);
    return d >= [self innerRadius] && [super pointInside:point withEvent:event];
}

- (void)selectAtPoint:(CGPoint)point {
    CGPoint c = [self hub];
    double angle = atan2(point.x - c.x, c.y - point.y);       // clockwise from the top
    if (angle < 0) {
        angle += 2 * M_PI;
    }
    int n = [EOTimeStepper numBodies];
    int i = (int)lround(angle / (2 * M_PI / n)) % n;
    int planet = [EOTimeStepper bodyAtIndex:i];
    if (planet != body) {
        [controller ringSelectedBody:planet];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self selectAtPoint:[[touches anyObject] locationInView:self]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self selectAtPoint:[[touches anyObject] locationInView:self]];
}

@end

//// A thumbwheel: an odometer wheel drawn as the thumbwheel switch it stands for.  The digits are on a drum
//// behind a window in the panel, flat like the rest of the controller; beside them the wheel's toothed rim
//// stands out of a slot, drawn in cabinet projection (depth recedes up and to the right at thumbAngle, at
//// half scale) so that it has the substance that says it turns.  The drum and the rim turn together: with a
//// drag (rolled by the controller, settling on the nearest value), with each change of the value by a step,
//// and in a nudge as the controller opens.  The look was tuned on a web prototype ("steel slim").

static const double thumbAngle = 35 * M_PI / 180;  // the oblique angle depth recedes at
static const double thumbDepthScale = 0.5;         // depth's scale: cabinet projection
static const double thumbRadius = 22;              // the rim, at its teeth's tips
static const double thumbProtrusion = 3;           // the teeth stand out of the panel by this
static const double thumbToothDepth = 2;
static const int    thumbTeethPerStep = 2;
static const double thumbPanelThickness = 1.5;     // the walls of the window and the slot
static const double thumbRimWidth = 5;             // beside the window, after a gap of thumbRimGap
static const double thumbRimGap = 1;
static const double thumbShine = 0.7;
static const double thumbLightFrom = 30 * M_PI / 180;      // from above, this far toward the right
static const double thumbLightHeight = 40 * M_PI / 180;    // above the panel
static const NSTimeInterval thumbRollDuration = 0.26;      // a change of value by a step
static const NSTimeInterval thumbSettleDuration = 0.18;    // after a drag
static const NSTimeInterval thumbNudgeOut = 0.18;          // the opening nudge: a third of a step on, and back
static const NSTimeInterval thumbNudgeBack = 0.34;
static const double thumbNudgeTurn = 0.32;

typedef struct { double x, y, z; } EOVec;       // x right, y down, z toward the viewer; the panel's face is z = 0

static EOVec vec(double x, double y, double z) {
    EOVec v = { x, y, z };
    return v;
}

static double dot(EOVec a, EOVec b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

static EOVec normalized(EOVec a) {
    double l = sqrt(dot(a, a));
    return l > 0 ? vec(a.x / l, a.y / l, a.z / l) : a;
}

static CGPoint project(EOVec p) {
    return CGPointMake(p.x - p.z * thumbDepthScale * cos(thumbAngle), p.y + p.z * thumbDepthScale * sin(thumbAngle));
}

static EOVec towardViewer() {       // along the projection
    return normalized(vec(thumbDepthScale * cos(thumbAngle), -thumbDepthScale * sin(thumbAngle), 1));
}

typedef struct {
    double base[3];
    double shininess;
    double ambient;
} EOFinish;

static const EOFinish steelFinish = { { 0.5, 0.53, 0.57 }, 30, 0.3 };
static const EOFinish panelFinish = { { 0.16, 0.16, 0.19 }, 16, 0.35 };

// A surface facing n, lit from the upper right with a white highlight
static CGColorRef createShade(EOVec n, const EOFinish &finish, double shine) {
    EOVec light = normalized(vec(cos(thumbLightHeight) * sin(thumbLightFrom), -cos(thumbLightHeight) * cos(thumbLightFrom), sin(thumbLightHeight)));
    EOVec v = towardViewer();
    EOVec half = normalized(vec(light.x + v.x, light.y + v.y, light.z + v.z));
    double diffuse = fmax(0, dot(n, light));
    double highlight = pow(fmax(0, dot(n, half)), finish.shininess) * thumbShine * shine;
    CGFloat c[4];
    for (int i = 0; i < 3; i++) {
        c[i] = fmin(1, finish.base[i] * (finish.ambient + (1 - finish.ambient) * 1.4 * diffuse) + highlight);
    }
    c[3] = 1;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGColorRef color = CGColorCreate(space, c);
    CGColorSpaceRelease(space);
    return color;
}

// The part of a polygon in front of the panel (sign 1) or behind it (sign -1)
static std::vector<EOVec> clipAtPanel(const std::vector<EOVec> &poly, int sign) {
    std::vector<EOVec> out;
    for (size_t i = 0; i < poly.size(); i++) {
        EOVec a = poly[i], b = poly[(i + 1) % poly.size()];
        double da = sign * a.z, db = sign * b.z;
        if (da >= 0) {
            out.push_back(a);
        }
        if ((da >= 0) != (db >= 0)) {
            double t = da / (da - db);
            out.push_back(vec(a.x + t * (b.x - a.x), a.y + t * (b.y - a.y), 0));
        }
    }
    return out;
}

static void fillFacet(CGContextRef context, const std::vector<EOVec> &poly, CGColorRef color) {
    if (poly.size() < 3) {
        return;
    }
    for (size_t i = 0; i < poly.size(); i++) {
        CGPoint p = project(poly[i]);
        if (i == 0) {
            CGContextMoveToPoint(context, p.x, p.y);
        } else {
            CGContextAddLineToPoint(context, p.x, p.y);
        }
    }
    CGContextClosePath(context);
    CGContextSetFillColorWithColor(context, color);
    CGContextSetStrokeColorWithColor(context, color);
    CGContextSetLineWidth(context, 0.15);       // over the seams between facets
    CGContextDrawPath(context, kCGPathFillStroke);
}

// The walls of a hole in the panel: with depth receding up and to the right, its left and bottom walls show
static void drawHoleWalls(CGContextRef context, CGRect hole) {
    double x = hole.origin.x, y = hole.origin.y, w = hole.size.width, h = hole.size.height, t = thumbPanelThickness;
    CGColorRef left = createShade(vec(1, 0, 0), panelFinish, 0.3);
    CGColorRef bottom = createShade(vec(0, -1, 0), panelFinish, 0.3);
    std::vector<EOVec> leftWall = { vec(x, y, 0), vec(x, y + h, 0), vec(x, y + h, -t), vec(x, y, -t) };
    std::vector<EOVec> bottomWall = { vec(x, y + h, 0), vec(x + w, y + h, 0), vec(x + w, y + h, -t), vec(x, y + h, -t) };
    fillFacet(context, leftWall, left);
    fillFacet(context, bottomWall, bottom);
    CGColorRelease(left);
    CGColorRelease(bottom);
}

@interface EOThumbwheel : UIView {
    UITextField   *field;       // the wheel's field, over the window, for typing (not retained: the odometer's)
    CGRect        window;       // the digits' window, in our coordinates
    CGRect        rim;          // the rim's slot, beside it
    NSString      *labels[5];   // the value two steps back to two steps on; nil where there is none
    double        roll;         // how far the wheel stands turned from its value, in steps: + toward the next
    long          steps;        // the steps it has turned, which set its teeth
    bool          dragging;
    bool          typing;
    CADisplayLink *link;        // while a roll animates
    CFTimeInterval animationStart;
    int           keyCount;     // the animation's keyframes: times from its start, and rolls
    double        keyTimes[4];
    double        keyRolls[4];
}
@property (readonly) UITextField *field;
- (id)initWithField:(UITextField *)aField;
- (void)setWindow:(CGRect)aWindow;
- (void)showLabels:(NSString **)newLabels;      // five: see labels
- (void)setDragging:(bool)isDragging;
- (void)setRoll:(double)aRoll;                  // while dragging
- (void)setTyping:(bool)isTyping;
- (void)nudgeAfter:(NSTimeInterval)delay;
- (NSString *)currentLabel;
@end

@implementation EOThumbwheel

@synthesize field;

- (id)initWithField:(UITextField *)aField {
    if ((self = [super initWithFrame:CGRectZero])) {
        field = aField;
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;        // the teeth stand out a little down and to the left
        self.userInteractionEnabled = NO;   // the odometer's drag rolls it
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)dealloc {
    for (int i = 0; i < 5; i++) {
        [labels[i] release];
    }
    [super dealloc];
}

// The window; the rim beside it, its full height
- (void)setWindow:(CGRect)aWindow {
    window = aWindow;
    rim = CGRectMake(CGRectGetMaxX(window) + thumbRimGap, 0, thumbRimWidth, self.bounds.size.height);
    [self setNeedsDisplay];
}

- (NSString *)currentLabel {
    return labels[2];
}

- (void)stopAnimation {
    [link invalidate];      // it retains us until then
    link = nil;
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (!newWindow) {
        [self stopAnimation];
    }
}

- (void)animateWithCount:(int)count times:(const double *)times rolls:(const double *)rolls {
    if (UIAccessibilityIsReduceMotionEnabled() || !self.window) {
        roll = rolls[count - 1];
        [self stopAnimation];
        [self setNeedsDisplay];
        return;
    }
    keyCount = count;
    for (int i = 0; i < count; i++) {
        keyTimes[i] = times[i];
        keyRolls[i] = rolls[i];
    }
    roll = rolls[0];
    animationStart = CACurrentMediaTime();
    if (!link) {
        link = [CADisplayLink displayLinkWithTarget:self selector:@selector(animationStep:)];
        [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    [self setNeedsDisplay];
}

- (void)animationStep:(CADisplayLink *)aLink {
    double t = CACurrentMediaTime() - animationStart;
    if (t >= keyTimes[keyCount - 1]) {
        roll = keyRolls[keyCount - 1];
        [self stopAnimation];
    } else {
        int i = 0;
        while (i + 1 < keyCount && keyTimes[i + 1] <= t) {
            i++;
        }
        double span = keyTimes[i + 1] - keyTimes[i];
        double u = span > 0 ? fmax(0, (t - keyTimes[i]) / span) : 1;
        roll = keyRolls[i] + (keyRolls[i + 1] - keyRolls[i]) * u * u * (3 - 2 * u);     // smoothstep
    }
    [self setNeedsDisplay];
}

// A new value.  A step on or back rolls into place, unless a drag has the wheel (it sets the roll itself);
// anything further is a jump.
- (void)showLabels:(NSString **)newLabels {
    bool same = true;
    for (int i = 0; i < 5; i++) {
        same = same && (labels[i] == newLabels[i] || [labels[i] isEqualToString:newLabels[i]]);
    }
    if (same) {
        return;
    }
    bool changed = !labels[2] || ![labels[2] isEqualToString:newLabels[2]];
    int direction = 0;
    if (labels[2] && changed) {
        if ([labels[3] isEqualToString:newLabels[2]]) {
            direction = 1;
        } else if ([labels[1] isEqualToString:newLabels[2]]) {
            direction = -1;
        }
    }
    for (int i = 0; i < 5; i++) {
        [labels[i] release];
        labels[i] = [newLabels[i] retain];
    }
    steps += direction;
    if (!dragging) {
        if (direction != 0 && !typing) {
            double times[2] = { 0, thumbRollDuration };
            double rolls[2] = { (double)-direction, 0 };
            [self animateWithCount:2 times:times rolls:rolls];
        } else if (changed) {
            [self stopAnimation];
            roll = 0;
        }
    }
    [self setNeedsDisplay];
}

- (void)setDragging:(bool)isDragging {
    dragging = isDragging;
    if (dragging) {
        [self stopAnimation];
    } else {
        double times[2] = { 0, thumbSettleDuration };
        double rolls[2] = { roll, 0 };
        [self animateWithCount:2 times:times rolls:rolls];
    }
}

- (void)setRoll:(double)aRoll {
    roll = aRoll;
    [self setNeedsDisplay];
}

- (void)setTyping:(bool)isTyping {
    typing = isTyping;
    if (typing) {
        [self stopAnimation];
        roll = 0;
    }
    [self setNeedsDisplay];
}

- (void)nudgeAfter:(NSTimeInterval)delay {
    if (dragging || typing) {
        return;
    }
    double times[4] = { 0, delay, delay + thumbNudgeOut, delay + thumbNudgeOut + thumbNudgeBack };
    double rolls[4] = { 0, 0, thumbNudgeTurn, 0 };
    [self animateWithCount:4 times:times rolls:rolls];
}

//// Drawing

- (double)axisDepth {               // the wheel's axis, behind the panel
    return thumbRadius - thumbProtrusion;
}

- (double)drumRadius {              // the digits' drum, just behind the window
    return fmax([self axisDepth] - 1.2, 6);
}

- (double)stepAngle {               // the turn from one value to the next: the digits' pitch on the drum
    return field.font.pointSize * 1.15 / [self drumRadius];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!typing) {
        [self drawWindowIn:context];
    }
    [self drawRimIn:context];
}

// The drum through the window: the value, its neighbours curving away above and below as it turns, the
// thumbwheel's shading (dark toward the drum's top and bottom, lit across its middle), and the window's walls
- (void)drawWindowIn:(CGContextRef)context {
    double yc = CGRectGetMidY(window);
    double d = [self axisDepth], r = [self drumRadius], step = [self stepAngle];
    CGContextSaveGState(context);
    UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:window cornerRadius:3];
    [frame addClip];
    CGContextSetFillColorWithColor(context, rgb(0x5a, 0x5a, 0x6a).CGColor);
    CGContextFillRect(context, window);
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:field.font, NSFontAttributeName,
                                             [UIColor whiteColor], NSForegroundColorAttributeName, nil];
    for (int k = -2; k <= 2; k++) {
        double phi = (k - roll) * step;
        if (fabs(phi) >= M_PI / 2 || !labels[k + 2]) {
            continue;
        }
        CGPoint p = project(vec(CGRectGetMidX(window), yc + r * sin(phi), -d + r * cos(phi)));
        CGSize extent = [labels[k + 2] sizeWithAttributes:attributes];
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, p.x, p.y);
        CGContextScaleCTM(context, 1, cos(phi));
        [labels[k + 2] drawAtPoint:CGPointMake(-extent.width / 2, -extent.height / 2) withAttributes:attributes];
        CGContextRestoreGState(context);
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = { 0, 0, 0, 0.92,  0, 0, 0, 0.35,  1, 1, 1, 0.12,  0, 0, 0, 0.35,  0, 0, 0, 0.92 };
    CGFloat locations[] = { 0, 0.28, 0.5, 0.72, 1 };
    CGGradientRef shading = CGGradientCreateWithColorComponents(space, components, locations, 5);
    CGContextDrawLinearGradient(context, shading, CGPointMake(0, window.origin.y), CGPointMake(0, CGRectGetMaxY(window)), 0);
    CGGradientRelease(shading);
    CGColorSpaceRelease(space);
    drawHoleWalls(context, window);
    CGContextRestoreGState(context);
    CGContextSetStrokeColorWithColor(context, rgb(0x22, 0x22, 0x2a).CGColor);
    CGContextSetLineWidth(context, 1);
    CGContextAddPath(context, frame.CGPath);
    CGContextStrokePath(context);
}

// The rim: its teeth's faces, in the profile's plane extruded across the rim's width, each shaded by where it
// faces; and its side, which faces the way depth recedes and so is in front of all of them.  What is behind
// the panel shows only through the slot.
- (void)drawRimIn:(CGContextRef)context {
    double yc = CGRectGetMidY(window);
    double d = [self axisDepth], step = [self stepAngle];
    double tip = thumbRadius, root = thumbRadius - thumbToothDepth;
    double pitch = step / thumbTeethPerStep;
    double tipHalf = pitch * 0.2, rootHalf = pitch * 0.34;
    double turned = (steps + roll) * step;
    double reach = M_PI / 2 + pitch;
    double x0 = rim.origin.x + 0.3, x1 = CGRectGetMaxX(rim) - 0.3;

    // The profile across the front of the wheel, top to bottom: (y, z) at each corner of each tooth
    std::vector<CGPoint> profile;
    for (long i = (long)ceil((turned - reach) / pitch); i <= (long)floor((turned + reach) / pitch); i++) {
        double a = i * pitch - turned;
        double corners[4][2] = { { a - rootHalf, root }, { a - tipHalf, tip }, { a + tipHalf, tip }, { a + rootHalf, root } };
        for (int c = 0; c < 4; c++) {
            profile.push_back(CGPointMake(yc + corners[c][1] * sin(corners[c][0]), -d + corners[c][1] * cos(corners[c][0])));
        }
    }
    struct Facet {
        std::vector<EOVec> poly;
        CGColorRef color;
        double depth;
    };
    std::vector<Facet> facets;
    EOVec v = towardViewer();
    for (size_t j = 0; j + 1 < profile.size(); j++) {
        CGPoint p = profile[j], q = profile[j + 1];
        EOVec n = normalized(vec(0, -(q.y - p.y), q.x - p.x));
        if (dot(n, v) <= 0) {
            continue;       // facing away
        }
        Facet facet;
        facet.poly = { vec(x0, p.x, p.y), vec(x1, p.x, p.y), vec(x1, q.x, q.y), vec(x0, q.x, q.y) };
        facet.color = createShade(n, steelFinish, 1);
        facet.depth = v.y * (p.x + q.x) / 2 + v.z * (p.y + q.y) / 2;
        facets.push_back(facet);
    }
    std::sort(facets.begin(), facets.end(), [](const Facet &a, const Facet &b) { return a.depth < b.depth; });
    std::vector<EOVec> side;
    for (CGPoint p : profile) {
        side.push_back(vec(x1, p.x, p.y));
    }
    side.push_back(vec(x1, yc, -d));
    CGColorRef sideColor = createShade(vec(1, 0, 0), steelFinish, 0.8);

    // The slot, as long as the teeth that stand out of it
    double half = fmin(17, fmax(sqrt(fmax(0, tip * tip - d * d)) + 1, 4));
    CGRect slot = CGRectMake(rim.origin.x, yc - half, rim.size.width, 2 * half);
    CGContextSaveGState(context);
    CGContextClipToRect(context, slot);
    CGContextSetRGBFillColor(context, 0.02, 0.02, 0.025, 1);
    CGContextFillRect(context, slot);
    for (const Facet &facet : facets) {
        fillFacet(context, clipAtPanel(facet.poly, -1), facet.color);
    }
    fillFacet(context, clipAtPanel(side, -1), sideColor);
    drawHoleWalls(context, slot);
    CGContextRestoreGState(context);
    for (const Facet &facet : facets) {
        fillFacet(context, clipAtPanel(facet.poly, 1), facet.color);
        CGColorRelease(facet.color);
    }
    fillFacet(context, clipAtPanel(side, 1), sideColor);
    CGColorRelease(sideColor);
}

@end

// The values a wheel shows around the time's: two steps back to two on, as rolling would make them (a day
// wraps at its month's end; the year has no neighbours past the supported range's ends, and counts down
// before the Common Era)
static int daysInMonth(int era, int year, int month) {
    static const int days[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    if (month != 2) {
        return days[(month - 1 + 12) % 12];
    }
    bool leap;
    if (era == 0) {
        leap = (year - 1) % 4 == 0;     // proleptic Julian: 1 BCE, 5 BCE, ...
    } else if (year < 1582) {
        leap = year % 4 == 0;
    } else {
        leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    }
    return leap ? 29 : 28;
}

static void wheelLabels(EOTimeStepUnit unit, const ESDateComponents &cs, NSString **labels) {
    for (int k = -2; k <= 2; k++) {
        NSString *label = nil;
        switch (unit) {
          case EOTimeStepYear: {
            int year = cs.era == 0 ? cs.year - k : cs.year + k;
            if (year >= 1 && !(cs.era == 0 && year > 4000) && !(cs.era != 0 && year > 2800)) {
                label = [NSString stringWithFormat:@"%d", year];
            }
            break;
          }
          case EOTimeStepMonth:
            label = [NSString stringWithFormat:@"%02d", (cs.month - 1 + k + 24) % 12 + 1];
            break;
          case EOTimeStepDay: {
            int n = daysInMonth(cs.era, cs.year, cs.month);
            label = [NSString stringWithFormat:@"%02d", (cs.day - 1 + k + 2 * n) % n + 1];
            break;
          }
          case EOTimeStepHour:
            label = [NSString stringWithFormat:@"%02d", (cs.hour + k + 48) % 24];
            break;
          case EOTimeStepMinute:
            label = [NSString stringWithFormat:@"%02d", (cs.minute + k + 120) % 60];
            break;
          default:
            label = [NSString stringWithFormat:@"%02d", ((int)floor(cs.seconds) + k + 120) % 60];
            break;
        }
        labels[k + 2] = label;
    }
}

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

// An odometer wheel: a thumbwheel, which a vertical drag on it rolls (the odometer's, wheelPanned:), and over
// its window a field, which takes digits from the keyboard only while the keyboard switch is on (keyboardTapped:)
- (UITextField *)addWheelWithPlaceholder:(NSString *)placeholder unit:(EOTimeStepUnit)unit {
    UITextField *field = [[EOWheelField alloc] initWithFrame:CGRectZero];
    field.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightMedium];
    field.tintColor = rgb(0x33, 0x55, 0xcc);
    field.textAlignment = NSTextAlignmentCenter;
    field.clipsToBounds = YES;
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
    field.userInteractionEnabled = NO;      // a field only while the keyboard switch is on (setEntering:)
    EOThumbwheel *wheel = [[EOThumbwheel alloc] initWithField:field];
    [odometer addSubview:wheel];
    [thumbwheels addObject:wheel];
    [wheel release];
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
        thumbwheels = [[NSMutableArray alloc] init];

        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];

        // Over the altitude dial: what the clock is doing, and Now (the live-clock icon), acting on the press
        nowBlock = [self addBlock];
        statusLabel = [self addLabelTo:nowBlock font:[UIFont fontWithName:@"Arial" size:12] color:rgb(0x88, 0xaa, 0xff)];
        statusLabel.numberOfLines = 2;
        offsetLabel = [self addLabelTo:nowBlock font:[UIFont fontWithName:@"Arial" size:12] color:rgb(0xcc, 0xcc, 0xdd)];
        nowButton = [self addButtonTo:nowBlock title:nil font:nil];
        nowButton.accessibilityLabel = NSLocalizedString(@"Now", @"button: return the clock to the present");
        nowButton.adjustsImageWhenHighlighted = NO;
        nowButton.adjustsImageWhenDisabled = NO;    // dimmed by alpha instead (refresh)
        styleAsPlain(nowButton);
        nowButton.tintColor = rgb(0xcc, 0xcc, 0xdd);
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

        // Over the equation-of-time dial: the pair.  Tap to step, hold to scrub, lift outside the dial's
        // circle to scrub hands-free.  UIControl keeps tracking a touch wherever it goes, so the release
        // reaches the button however far the finger has wandered; the drags say meanwhile whether it is
        // outside the circle (stepTouchDragged:withEvent:).
        stepBlock = [self addBlock];
        // Under the pair, the body ring for rise / set / transit
        bodyRing = [[EOTimeBodyRing alloc] initWithController:self];
        [stepBlock addSubview:bodyRing];
        [bodyRing release];
        stepLabel = [self addLabelTo:stepBlock font:[UIFont fontWithName:@"Arial-BoldMT" size:14] color:rgb(0xcc, 0xcc, 0xdd)];
        UIFont *pairFont = [UIFont systemFontOfSize:22];
        backButton = [EOPairButton buttonWithType:UIButtonTypeCustom];
        forwardButton = [EOPairButton buttonWithType:UIButtonTypeCustom];
        [(EOPairButton *)backButton setGlyph:@"◀" font:pairFont];
        [(EOPairButton *)forwardButton setGlyph:@"▶" font:pairFont];
        backButton.accessibilityLabel = @"◀";
        forwardButton.accessibilityLabel = @"▶";
        [stepBlock addSubview:backButton];
        [stepBlock addSubview:forwardButton];
        styleAsPlain(backButton);
        styleAsPlain(forwardButton);
        for (UIButton *button in [NSArray arrayWithObjects:backButton, forwardButton, nil]) {
            [button addTarget:self action:@selector(stepTouchDown:) forControlEvents:UIControlEventTouchDown];
            [button addTarget:self action:@selector(stepTouchUp:) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
            [button addTarget:self action:@selector(stepTouchCancel:) forControlEvents:UIControlEventTouchCancel];
            [button addTarget:self action:@selector(stepTouchDragged:withEvent:) forControlEvents:(UIControlEventTouchDragInside | UIControlEventTouchDragOutside)];
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

        // The odometer: the date's wheels, Set / Done (EOClock's), the time's wheels and the keyboard button.
        // A typed value applies when its wheel's edit ends; the era, at once.
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
        // The wheels' drag is the odometer's, not the fields': a text field keeps a mouse's click-drag for
        // selecting its text (an iPad app on a Mac), even with editing refused.  A trackpad's or a mouse
        // wheel's scroll over a wheel rolls it too.
        UIPanGestureRecognizer *roll = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(wheelPanned:)];
        roll.delegate = self;
        roll.allowedScrollTypesMask = UIScrollTypeMaskAll;
        [odometer addGestureRecognizer:roll];
        [roll release];

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
    [thumbwheels release];
    // The widgets are the view hierarchy's; the stepper and the clock are not ours
    [super dealloc];
}

// The icon: nowLive.png's clock and its broadcast waves, and in place of its box around "LIVE", a box as wide as
// "GO LIVE" needs, drawn as the original is (in the png's 512-unit square: a 16-unit line with rounded ends and
// corners, a break in each side) around the words in a rounded bold face of the original's height
static const double iconSquare = 512;           // the png's size
static const double iconLine = 16;
static const double iconBoxLeft = 144;          // the box's outer edges
static const double iconBoxTop = 280;
static const double iconBoxBottom = 440;
static const double iconTextLeft = 200;         // the words: where they start, their baseline, their capitals' height
static const double iconBaseline = 400;
static const double iconCapHeight = 80;
static const double iconTextRightPad = 57;      // inside the box's line, after the words
static const double iconRightMargin = 17;       // outside it

static UIFont *iconFont() {
    UIFont *font = [UIFont fontWithName:@"ArialRoundedMTBold" size:100];
    if (!font) {
        font = [UIFont systemFontOfSize:100 weight:UIFontWeightBold];
    }
    return [font fontWithSize:100 * iconCapHeight / font.capHeight];
}

static NSString *iconWords() {
    return @"GO LIVE";      // as the png's LIVE, in English everywhere
}

static NSDictionary *iconAttributes() {
    return [NSDictionary dictionaryWithObjectsAndKeys:iconFont(), NSFontAttributeName, [UIColor blackColor], NSForegroundColorAttributeName,
                                                      [UIColor blackColor], NSStrokeColorAttributeName,
                                                      [NSNumber numberWithDouble:6], NSKernAttributeName,
                                                      [NSNumber numberWithDouble:-3], NSStrokeWidthAttributeName, nil];   // filled, and outlined to the box's weight
}

// The icon's width, in the png's units
static double iconWidth() {
    double textWidth = [iconWords() sizeWithAttributes:iconAttributes()].width;
    return iconTextLeft + textWidth + iconTextRightPad + iconLine + iconRightMargin;
}

+ (double)nowIconAspect {
    return iconWidth() / iconSquare;
}

+ (UIImage *)nowIconOfSize:(double)size {
    UIImage *source = [UIImage imageNamed:@"nowLive"];
    double width = iconWidth();
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 4;       // the screen's 2 or 3, and the canvas's scaling up to fill the window on top
    UIGraphicsImageRenderer *renderer = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size * width / iconSquare, size) format:format] autorelease];
    UIImage *icon = [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
        CGContextRef context = rendererContext.CGContext;
        CGContextScaleCTM(context, size / iconSquare, size / iconSquare);
        // The clock and the waves: all of the png but its box
        CGContextSaveGState(context);
        CGContextAddRect(context, CGRectMake(0, 0, width, iconSquare));
        CGContextAddRect(context, CGRectMake(iconBoxLeft - 2, iconBoxTop - 2, iconSquare, iconBoxBottom - iconBoxTop + 4));
        CGContextEOClip(context);
        [source drawInRect:CGRectMake(0, 0, iconSquare, iconSquare)];
        CGContextRestoreGState(context);
        // The box, along its line's middle; each side's break is where the png's is
        double l = iconBoxLeft + iconLine / 2, t = iconBoxTop + iconLine / 2, b = iconBoxBottom - iconLine / 2;
        double r = width - iconRightMargin - iconLine / 2;
        CGContextSetLineWidth(context, iconLine);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextSetGrayStrokeColor(context, 0, 1);
        CGContextMoveToPoint(context, l, 344);
        CGContextAddLineToPoint(context, l, b);
        CGContextAddLineToPoint(context, r, b);
        CGContextAddLineToPoint(context, r, 408);
        CGContextMoveToPoint(context, r, 376);
        CGContextAddLineToPoint(context, r, t);
        CGContextAddLineToPoint(context, l, t);
        CGContextAddLineToPoint(context, l, 312);
        CGContextStrokePath(context);
        UIFont *font = iconFont();
        [iconWords() drawAtPoint:CGPointMake(iconTextLeft, iconBaseline - font.ascender) withAttributes:iconAttributes()];
    }];
    return [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
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

    // The status on top, the offset under it, Now below them, in the middle of what is left
    statusLabel.frame = CGRectMake(blockPad, blockPad, inner, statusHeight);
    offsetLabel.frame = CGRectMake(blockPad, blockPad + statusHeight, inner, offsetHeight);
    double nowTop = blockPad + statusHeight + offsetHeight + gap;
    double nowHeight = fmin(64, h - nowTop - blockPad);
    nowButton.frame = CGRectMake(blockPad, nowTop + (h - nowTop - blockPad - nowHeight) / 2, inner, nowHeight);
    [nowButton setImage:[EOTimeControllerView nowIconOfSize:nowHeight - 10] forState:UIControlStateNormal];

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

// The pair, always the same size and in the same place whether the body dial shows or not: in the middle of
// the dial's room (the mode dial's size, centred in the block), inside the symbols' band, with its label above
- (void)layoutStepBlock {
    double w = landscape ? landscapeBlockWidth : portraitBlockWidth;
    double h = landscape ? landscapeBlockHeight : portraitBlockHeight;
    double side = fmin(w - 2 * blockPad, h - 2 * blockPad);
    bodyRing.frame = CGRectMake((w - side) / 2, (h - side) / 2, side, side);
    [bodyRing setNeedsDisplay];
    bodyRing.hidden = !ringShown;
    CGPoint c = CGPointMake(w / 2, h / 2);
    double r = [bodyRing innerRadius];
    stepLabel.frame = CGRectMake(c.x - 0.8 * r, c.y - 0.78 * r, 1.6 * r, 0.42 * r);
    double pairWidth = 0.78 * r - gap / 2;
    double pairHeight = 0.95 * r;
    double pairTop = c.y - 0.3 * r;
    CGRect backFace = CGRectMake(c.x - 0.78 * r, pairTop, pairWidth, pairHeight);
    CGRect forwardFace = CGRectMake(c.x + gap / 2, pairTop, pairWidth, pairHeight);
    padlock.frame = CGRectMake(c.x - r, pairTop, 2 * r, pairHeight);

    // The targets, larger than the faces.  Without the body dial: each its half of the whole block, edge to
    // edge and top to bottom.  With it: each its half of the circle inside the dial's band, which takes
    // the touches beyond, so that no touch falls between the two.
    EOPairButton *back = (EOPairButton *)backButton;
    EOPairButton *forward = (EOPairButton *)forwardButton;
    if (!ringShown) {
        back.frame = CGRectMake(0, 0, w / 2, h);
        forward.frame = CGRectMake(w / 2, 0, w / 2, h);
        [back setTargetCircleCenter:CGPointZero radius:0];
        [forward setTargetCircleCenter:CGPointZero radius:0];
    } else {
        back.frame = CGRectMake(c.x - r, c.y - r, r, 2 * r);
        forward.frame = CGRectMake(c.x, c.y - r, r, 2 * r);
        [back setTargetCircleCenter:CGPointMake(r, r) radius:r];
        [forward setTargetCircleCenter:CGPointMake(0, r) radius:r];
    }
    [back setFaceFrame:CGRectOffset(backFace, -back.frame.origin.x, -back.frame.origin.y)];
    [forward setFaceFrame:CGRectOffset(forwardFace, -forward.frame.origin.x, -forward.frame.origin.y)];
}

// CE YYYY MM DD to the left of Set / Done in the middle, HH MM SS and the keyboard button to its right; each
// wheel's rim beside its window
- (void)layoutOdometer {
    double middle = EOOdometerWidth / 2;
    double rimRoom = thumbRimGap + thumbRimWidth;
    double dateWidth = eraWidth + 2 + yearWidth + 2 * wheelWidth + 3 * rimRoom + 3 * wheelGap;
    double x = middle - EOOdometerDoneWidth / 2 - doneGap - dateWidth;
    double y = 4;
    double height = EOOdometerHeight - 8;
    eraButton.frame = CGRectMake(x, y, eraWidth, height);
    x += eraWidth + wheelGap + 2;
    for (EOThumbwheel *wheel in thumbwheels) {
        UITextField *field = wheel.field;
        double width = (field == yearField) ? yearWidth : wheelWidth;
        if (field == hourField) {
            x = middle + EOOdometerDoneWidth / 2 + doneGap;
        }
        wheel.frame = CGRectMake(x, 0, width + rimRoom, EOOdometerHeight);
        [wheel setWindow:CGRectMake(0, y, width, height)];
        field.frame = CGRectMake(x, y, width, height);
        x += width + rimRoom + (field == secondField ? keyboardGap : wheelGap);
    }
    keyboardButton.frame = CGRectMake(x, y, EOOdometerWidth - 4 - x, height);
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
        // As the odometer arrives, its wheels turn a little and back, one after another: they roll
        int i = 0;
        for (EOThumbwheel *wheel in thumbwheels) {
            [wheel nudgeAfter:growDuration * 0.5 + 0.07 * i++];
        }
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
    [stepper togglePause];      // a second press un-pauses
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

// The lift.  Off the dial's circle (offButton): the latch, once the hold has engaged (the scrub runs on
// hands-free until the next press); before that it was a sloppy tap, one step and no latch.  On it, the
// scrub ends.
- (void)stepTouchUp:(UIButton *)sender {
    bool latch = offButton && [stepper isScrubbing];
    offButton = false;
    if (latch) {
        [stepper lockScrub];
    } else {
        [stepper endPress];
    }
    [self refresh];
}

// A cancelled touch (a system gesture, a rotation): the scrub ends
- (void)stepTouchCancel:(UIButton *)sender {
    offButton = false;
    [stepper endPress];
    [self refresh];
}

// The held finger leaves the dial's circle (the body dial's rim, whether that shows or not) and comes back:
// the padlock shows what a lift would do.  The circle, not UIKit's margin around the button, which on the
// block at the screen's edge lies partly off the screen.
- (void)stepTouchDragged:(UIButton *)sender withEvent:(UIEvent *)event {
    CGPoint p = [[[event touchesForView:sender] anyObject] locationInView:stepBlock];
    CGSize size = stepBlock.bounds.size;
    double radius = fmin(size.width, size.height) / 2 - blockPad - 1;     // as the body dial's rim
    bool off = hypot(p.x - size.width / 2, p.y - size.height / 2) > radius;
    if (off != offButton) {
        offButton = off;
        [self refresh];
    }
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

// A wheel rolls only for a mostly vertical drag that started on it, and not while the keyboard switch makes
// it a field; a drag from anywhere else on the odometer (the era, the keyboard button) is theirs
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if (![recognizer isKindOfClass:[UIPanGestureRecognizer class]] || entering) {
        return NO;
    }
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)recognizer;
    CGPoint velocity = [pan velocityInView:odometer];
    if (fabs(velocity.y) <= fabs(velocity.x)) {
        return NO;
    }
    // Where it started: the pan has moved a little by now
    CGPoint location = [pan locationInView:odometer];
    CGPoint translation = [pan translationInView:odometer];
    CGPoint start = CGPointMake(location.x - translation.x, location.y - translation.y);
    rollingWheel = nil;
    for (EOThumbwheel *wheel in thumbwheels) {
        if (CGRectContainsPoint(wheel.frame, start)) {
            rollingWheel = wheel;
        }
    }
    return rollingWheel != nil;
}

// Up rolls the wheel on, down rolls it back: half a notch of travel rolls to the next unit, and the wheel turns
// with the finger meanwhile, settling on its value when the drag ends.  At the range's end it goes no further.
- (void)wheelPanned:(UIPanGestureRecognizer *)recognizer {
    EOThumbwheel *wheel = rollingWheel;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        rollCarry = 0;
        [wheel setDragging:true];
    } else if (recognizer.state != UIGestureRecognizerStateChanged) {
        [wheel setDragging:false];      // ended, cancelled or failed
        return;
    }
    rollCarry -= [recognizer translationInView:odometer].y;
    [recognizer setTranslation:CGPointZero inView:odometer];
    EOTimeStepUnit unit = (EOTimeStepUnit)wheel.field.tag;
    while (fabs(rollCarry) >= notch / 2) {
        int direction = rollCarry > 0 ? 1 : -1;
        NSString *before = [[[wheel currentLabel] retain] autorelease];
        [stepper rollUnit:unit inDirection:direction];
        [self refresh];
        if ([[wheel currentLabel] isEqualToString:before]) {
            rollCarry = 0;      // at the limit
            break;
        }
        rollCarry -= direction * notch;
    }
    [wheel setRoll:rollCarry / notch];
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
        field.userInteractionEnabled = on;
    }
    for (EOThumbwheel *wheel in thumbwheels) {
        [wheel setTyping:on];
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

// No edit menu over a wheel (see EOWheelField)
- (UIMenu *)textField:(UITextField *)textField editMenuForCharactersInRange:(NSRange)range suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    return [UIMenu menuWithChildren:[NSArray array]];
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
        return;     // the rest is the blocks' and the thumbwheels'
    }
    for (EOThumbwheel *wheel in thumbwheels) {
        NSString *labels[5];
        wheelLabels((EOTimeStepUnit)wheel.field.tag, cs, labels);
        [wheel showLabels:labels];
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
    setLabelText(offsetLabel, [stepper offsetString]);

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
