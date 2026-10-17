//
//  EOBrass.mm
//  Emerald Observatory
//
//  See EOBrass.h.
//

#import "EOBrass.h"

static const double plateRadius = 14;       // the rim's outer corners
static const double rimWidth = 5;
static const double rivetRadius = 3.2;
static const double rivetInset = 10;        // from the plate's edges to a rivet's centre

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

@implementation EOBrassPlateView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = self.bounds;

    // The rim: brass between the outer and inner outlines, a dark line where it meets the plate and a
    // light one along its outer edge
    UIBezierPath *outer = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 0.5, 0.5) cornerRadius:plateRadius];
    UIBezierPath *inner = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, rimWidth, rimWidth) cornerRadius:plateRadius - rimWidth + 1];
    EOBrassFillPath(context, outer.CGPath);
    CGContextSetStrokeColorWithColor(context, rgba(0x3a, 0x29, 0x08, 1));
    CGContextSetLineWidth(context, 1);
    CGContextAddPath(context, outer.CGPath);
    CGContextStrokePath(context);

    // The plate, sunk a little below the rim
    EOIronFillPath(context, inner.CGPath);
    EOInsetShadow(context, inner.CGPath, 4, 0.9);
    CGContextSetStrokeColorWithColor(context, rgba(0x2a, 0x1e, 0x06, 1));
    CGContextAddPath(context, inner.CGPath);
    CGContextStrokePath(context);

    // A rivet in each corner of the rim
    double w = bounds.size.width, h = bounds.size.height;
    EOBrassDome(context, CGPointMake(rivetInset, rivetInset), rivetRadius);
    EOBrassDome(context, CGPointMake(w - rivetInset, rivetInset), rivetRadius);
    EOBrassDome(context, CGPointMake(rivetInset, h - rivetInset), rivetRadius);
    EOBrassDome(context, CGPointMake(w - rivetInset, h - rivetInset), rivetRadius);
}

@end
