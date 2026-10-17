//
//  EOBrass.h
//  Emerald Observatory
//
//  The time controller's steampunk look, drawn rather than painted: polished brass (rims, knobs,
//  buttons, rivets) on blackened iron, with engraved lettering.  Plain Core Graphics, in the
//  current context's units, so it is sharp at any scale the canvas is drawn at.
//

#import <UIKit/UIKit.h>

// Brass across a path's bounds, lit from the upper left: a band of highlights and shadows like a
// polished, slightly curved surface
void EOBrassFillPath(CGContextRef context, CGPathRef path);

// A domed brass disc: a rivet, a button's crown, a knob's cap
void EOBrassDome(CGContextRef context, CGPoint center, double radius);

// Blackened iron filling a path: near black, a little lighter toward the top
void EOIronFillPath(CGContextRef context, CGPathRef path);

// A shadow cast inward from a path's edge, as if the area it encloses were sunk below its surround
void EOInsetShadow(CGContextRef context, CGPathRef path, double blur, double alpha);

// Text cut into a surface: a dark lip above and a light one below the filled letters
void EOEngraveText(NSString *text, CGPoint center, UIFont *font, UIColor *color);

// The lettering face the controls are engraved in (Copperplate, the logo's small caps)
UIFont *EOEngravingFont(double size);

// The colours of the engraving and of the brass it goes with
UIColor *EOBrassTextColor(void);
UIColor *EOCreamTextColor(void);

// A block of the controller: a round gauge, after the old steam gauges.  A thick, rolled brass bezel
// steps down to a thinner ring sloping in to the face, which is silvered metal or blackened iron.
typedef enum EOGaugeFace {
    EOGaugeFaceSilver,
    EOGaugeFaceIron
} EOGaugeFace;

@interface EOGaugeView : UIView {
    EOGaugeFace face;
}
@property (nonatomic) EOGaugeFace face;
- (CGPoint)faceCenter;
- (double)faceRadius;          // the face inside the bezel, for laying out what goes on it
@end
