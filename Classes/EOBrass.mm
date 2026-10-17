//
//  EOBrass.mm
//  Emerald Observatory
//
//  See EOBrass.h.
//

#import "EOBrass.h"

static const double rollWidth = 0.15;       // the bezel's outer roll, as a fraction of the gauge's radius
static const double grooveWidth = 0.015;    // the dark step between the roll and the inner ring
static const double flareWidth = 0.065;     // the inner ring, sloping in to the face

static CGColorRef rgba(int r, int g, int b, double a) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a].CGColor;
}

// Polished brass: alternating light and dark bands, so that a flat fill reads as a curved, reflective surface
static CGGradientRef brassGradient(void) {
    static CGGradientRef gradient = NULL;
    if (!gradient) {
        NSArray *colors = [NSArray arrayWithObjects:(id)rgba(0x6b, 0x4e, 0x17, 1), (id)rgba(0xc9, 0xa2, 0x4a, 1), (id)rgba(0xf6, 0xe3, 0xa1, 1),
                                   (id)rgba(0xc3, 0x9a, 0x3e, 1), (id)rgba(0x8a, 0x6a, 0x24, 1), (id)rgba(0xd9, 0xb8, 0x5f, 1),
                                   (id)rgba(0x6b, 0x4e, 0x17, 1), nil];
        const CGFloat locations[] = { 0, 0.18, 0.35, 0.5, 0.7, 0.85, 1 };
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        gradient = CGGradientCreateWithColors(space, (CFArrayRef)colors, locations);
        CGColorSpaceRelease(space);
    }
    return gradient;
}

void EOBrassFillPath(CGContextRef context, CGPathRef path) {
    CGRect bounds = CGPathGetBoundingBox(path);
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
    // Lit from the upper left: the bands run diagonally across the bounds
    CGContextDrawLinearGradient(context, brassGradient(), bounds.origin, CGPointMake(CGRectGetMaxX(bounds), CGRectGetMaxY(bounds)),
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGContextRestoreGState(context);
}

void EOBrassDome(CGContextRef context, CGPoint center, double radius) {
    static CGGradientRef dome = NULL;
    if (!dome) {
        NSArray *colors = [NSArray arrayWithObjects:(id)rgba(0xff, 0xf4, 0xc8, 1), (id)rgba(0xd9, 0xb2, 0x58, 1),
                                   (id)rgba(0x8a, 0x66, 0x1e, 1), (id)rgba(0x4a, 0x34, 0x0c, 1), nil];
        const CGFloat locations[] = { 0, 0.35, 0.8, 1 };
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        dome = CGGradientCreateWithColors(space, (CFArrayRef)colors, locations);
        CGColorSpaceRelease(space);
    }
    CGContextSaveGState(context);
    // A soft shadow under the dome, down and to the right
    CGContextSetShadowWithColor(context, CGSizeMake(radius * 0.25, radius * 0.35), radius * 0.6, rgba(0, 0, 0, 0.8));
    CGContextSetFillColorWithColor(context, rgba(0x4a, 0x34, 0x0c, 1));
    CGContextFillEllipseInRect(context, CGRectMake(center.x - radius, center.y - radius, 2 * radius, 2 * radius));
    CGContextRestoreGState(context);
    CGContextSaveGState(context);
    CGContextAddEllipseInRect(context, CGRectMake(center.x - radius, center.y - radius, 2 * radius, 2 * radius));
    CGContextClip(context);
    // The highlight sits up and to the left of centre
    CGPoint highlight = CGPointMake(center.x - radius * 0.35, center.y - radius * 0.4);
    CGContextDrawRadialGradient(context, dome, highlight, 0, center, radius, kCGGradientDrawsAfterEndLocation);
    CGContextRestoreGState(context);
}

void EOIronFillPath(CGContextRef context, CGPathRef path) {
    static CGGradientRef iron = NULL;
    if (!iron) {
        NSArray *colors = [NSArray arrayWithObjects:(id)rgba(0x2c, 0x2b, 0x2e, 1), (id)rgba(0x1a, 0x1a, 0x1c, 1), (id)rgba(0x0e, 0x0e, 0x10, 1), nil];
        const CGFloat locations[] = { 0, 0.45, 1 };
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        iron = CGGradientCreateWithColors(space, (CFArrayRef)colors, locations);
        CGColorSpaceRelease(space);
    }
    CGRect bounds = CGPathGetBoundingBox(path);
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, iron, bounds.origin, CGPointMake(bounds.origin.x, CGRectGetMaxY(bounds)), 0);
    CGContextRestoreGState(context);
}

void EOInsetShadow(CGContextRef context, CGPathRef path, double blur, double alpha) {
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
    // A thick ring just outside the path, whose shadow falls inside it
    CGRect outer = CGRectInset(CGPathGetBoundingBox(path), -4 * blur, -4 * blur);
    CGMutablePathRef ring = CGPathCreateMutable();
    CGPathAddRect(ring, NULL, outer);
    CGPathAddPath(ring, NULL, path);
    CGContextSetShadowWithColor(context, CGSizeMake(0, blur * 0.4), blur, rgba(0, 0, 0, alpha));
    CGContextSetFillColorWithColor(context, rgba(0, 0, 0, 1));
    CGContextAddPath(context, ring);
    CGContextEOFillPath(context);
    CGPathRelease(ring);
    CGContextRestoreGState(context);
}

UIFont *EOEngravingFont(double size) {
    UIFont *font = [UIFont fontWithName:@"Copperplate" size:size];
    return font ? font : [UIFont systemFontOfSize:size];
}

UIColor *EOBrassTextColor(void) {
    return [UIColor colorWithRed:0xe0/255.0 green:0xc0/255.0 blue:0x6e/255.0 alpha:1];
}

UIColor *EOCreamTextColor(void) {
    return [UIColor colorWithRed:0xf2/255.0 green:0xe8/255.0 blue:0xcf/255.0 alpha:1];
}

void EOEngraveText(NSString *text, CGPoint center, UIFont *font, UIColor *color) {
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, color, NSForegroundColorAttributeName, nil];
    CGSize size = [text sizeWithAttributes:attributes];
    CGPoint origin = CGPointMake(center.x - size.width / 2, center.y - size.height / 2);
    NSDictionary *dark = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, [UIColor colorWithWhite:0 alpha:0.85], NSForegroundColorAttributeName, nil];
    NSDictionary *light = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, [UIColor colorWithWhite:1 alpha:0.18], NSForegroundColorAttributeName, nil];
    [text drawAtPoint:CGPointMake(origin.x, origin.y - 0.7) withAttributes:dark];
    [text drawAtPoint:CGPointMake(origin.x, origin.y + 0.7) withAttributes:light];
    [text drawAtPoint:origin withAttributes:attributes];
}

@implementation EOGaugeView

@synthesize face;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        face = EOGaugeFaceSilver;
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setFace:(EOGaugeFace)aFace {
    face = aFace;
    [self setNeedsDisplay];
}

- (double)radius {
    return fmin(self.bounds.size.width, self.bounds.size.height) / 2 - 2;     // room for the shadow
}

- (CGPoint)faceCenter {
    return CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
}

- (double)faceRadius {
    return [self radius] * (1 - rollWidth - grooveWidth - flareWidth);
}

static CGPathRef circle(CGPoint center, double radius) {
    return [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:0 endAngle:2 * M_PI clockwise:YES].CGPath;
}

static CGPathRef ring(CGPoint center, double outer, double inner) {
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:outer startAngle:0 endAngle:2 * M_PI clockwise:YES];
    [path appendPath:[UIBezierPath bezierPathWithArcCenter:center radius:inner startAngle:0 endAngle:2 * M_PI clockwise:NO]];
    return path.CGPath;
}

// Shading across a ring's width, over the brass: dark at both edges and light along its crown, so a flat
// band reads as a rounded roll
static void shadeRoll(CGContextRef context, CGPoint center, double outer, double inner) {
    static CGGradientRef roll = NULL;
    if (!roll) {
        NSArray *colors = [NSArray arrayWithObjects:(id)rgba(0, 0, 0, 0.7), (id)rgba(0, 0, 0, 0.15), (id)rgba(0xff, 0xf8, 0xe0, 0.55),
                                   (id)rgba(0xff, 0xf8, 0xe0, 0.1), (id)rgba(0, 0, 0, 0.25), (id)rgba(0, 0, 0, 0.75), nil];
        const CGFloat locations[] = { 0, 0.22, 0.48, 0.62, 0.82, 1 };
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        roll = CGGradientCreateWithColors(space, (CFArrayRef)colors, locations);
        CGColorSpaceRelease(space);
    }
    CGContextSaveGState(context);
    CGContextAddPath(context, ring(center, outer, inner));
    CGContextEOClip(context);
    CGContextDrawRadialGradient(context, roll, center, inner, center, outer, 0);
    CGContextRestoreGState(context);
}

// Brass lit from the lower right instead: a surface sloping away from the light, the ring falling in to the face
static void fillFlare(CGContextRef context, CGPoint center, double outer, double inner) {
    CGContextSaveGState(context);
    CGContextAddPath(context, ring(center, outer, inner));
    CGContextEOClip(context);
    CGContextTranslateCTM(context, center.x, center.y);
    CGContextRotateCTM(context, M_PI);
    CGContextTranslateCTM(context, -center.x, -center.y);
    EOBrassFillPath(context, circle(center, outer));
    CGContextRestoreGState(context);
}

- (void)drawSilverFaceAt:(CGPoint)center radius:(double)r context:(CGContextRef)context {
    static CGGradientRef silver = NULL;
    if (!silver) {
        NSArray *colors = [NSArray arrayWithObjects:(id)rgba(0xec, 0xe6, 0xd4, 1), (id)rgba(0xcf, 0xc7, 0xb0, 1), (id)rgba(0xa8, 0x9e, 0x84, 1), nil];
        const CGFloat locations[] = { 0, 0.6, 1 };
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        silver = CGGradientCreateWithColors(space, (CFArrayRef)colors, locations);
        CGColorSpaceRelease(space);
    }
    CGContextSaveGState(context);
    CGContextAddPath(context, circle(center, r));
    CGContextClip(context);
    CGContextDrawRadialGradient(context, silver, CGPointMake(center.x - r * 0.25, center.y - r * 0.3), 0, center, r, kCGGradientDrawsAfterEndLocation);
    // Spun metal: fine concentric rings, alternately a shade lighter and darker
    CGContextSetLineWidth(context, 0.5);
    for (double rr = 1.5; rr < r; rr += 1.5) {
        CGContextSetStrokeColorWithColor(context, ((int)(rr / 1.5) % 2) ? rgba(0xff, 0xff, 0xff, 0.10) : rgba(0x50, 0x40, 0x20, 0.06));
        CGContextAddPath(context, circle(center, rr));
        CGContextStrokePath(context);
    }
    CGContextRestoreGState(context);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint center = [self faceCenter];
    double r = [self radius];
    double rollInner = r * (1 - rollWidth);
    double flareOuter = r * (1 - rollWidth - grooveWidth);
    double faceR = [self faceRadius];

    // The gauge's shadow on the sky behind it
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1.5), 4, rgba(0, 0, 0, 0.9));
    CGContextSetFillColorWithColor(context, rgba(0x3a, 0x29, 0x08, 1));
    CGContextAddPath(context, circle(center, r));
    CGContextFillPath(context);
    CGContextRestoreGState(context);

    // The outer roll: brass, then the shading that rounds it
    CGContextSaveGState(context);
    CGContextAddPath(context, ring(center, r, rollInner));
    CGContextEOClip(context);
    EOBrassFillPath(context, circle(center, r));
    CGContextRestoreGState(context);
    shadeRoll(context, center, r, rollInner);

    // The step down, and the inner ring sloping in to the face
    CGContextSetFillColorWithColor(context, rgba(0x2a, 0x1c, 0x04, 1));
    CGContextAddPath(context, ring(center, rollInner, flareOuter));
    CGContextEOFillPath(context);
    fillFlare(context, center, flareOuter, faceR);

    // The face, sunk below the ring
    if (face == EOGaugeFaceSilver) {
        [self drawSilverFaceAt:center radius:faceR context:context];
    } else {
        EOIronFillPath(context, circle(center, faceR));
    }
    EOInsetShadow(context, circle(center, faceR), faceR * 0.08, face == EOGaugeFaceSilver ? 0.55 : 0.9);
    CGContextSetStrokeColorWithColor(context, rgba(0x2a, 0x1c, 0x04, 1));
    CGContextSetLineWidth(context, 0.75);
    CGContextAddPath(context, circle(center, faceR));
    CGContextStrokePath(context);
    CGContextAddPath(context, circle(center, r - 0.4));
    CGContextStrokePath(context);
}

@end
