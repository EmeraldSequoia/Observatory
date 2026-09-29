//
//  EOLocationPickerViewController.mm
//  Emerald Observatory
//
//  Copyright 2026 Emerald Sequoia LLC. All rights reserved.
//

#import "EOLocationPickerViewController.h"
#import "EOClock.h"
#import "EOEarthView.h"
#import <CoreLocation/CoreLocation.h>
#include "ESWatchTime.hpp"
#include "ESTimeLocAstroEnvironment.hpp"
#include "ESDeviceLocationManager.hpp"
#include "ESLocation.hpp"

#define BLUE_DOT_HIT_RADIUS 22.0  // points; a touch starting this close to the blue dot snaps to it while it stays this close
#define CURSOR_RADIUS        12.0
#define LABEL_OFFSET         44.0  // coordinate label's center above the finger, so the finger doesn't hide it

#define ZOOM_OUT_DURATION    0.65  // seconds; a spring with a little overshoot, as if the map were lifted out of the clock
#define ZOOM_OUT_DAMPING     0.72
#define ZOOM_IN_DURATION     0.5   // settles back into the clock without overshooting its frame
#define FADE_DURATION        0.25
#define MAP_SHADOW_OPACITY   0.6

// As EOClock's frame around the header (headerLineWidth and its stroke color), in clock canvas units
#define BORDER_LINE_WIDTH    2.0
#define BORDER_GAP           2.0
#define BORDER_GRAY          0.5
#define BORDER_ALPHA         0.5

static NSString *
coordinateString(double latitudeDegrees, double longitudeDegrees) {
    NSString *ns = latitudeDegrees >= 0
	? NSLocalizedString(@"N",@"one character abbreviation for 'north'")
	: NSLocalizedString(@"S",@"one character abbreviation for 'south'");
    NSString *ew = longitudeDegrees >= 0
	? NSLocalizedString(@"E",@"one character abbreviation for 'east'")
	: NSLocalizedString(@"W",@"one character abbreviation for 'west'");
    return [NSString stringWithFormat:@"%.2f° %@, %.2f° %@", fabs(latitudeDegrees), ns, fabs(longitudeDegrees), ew];
}

@implementation EOLocationPickerMapView

@synthesize delegate;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
	self.contentMode = UIViewContentModeRedraw;  // redraw the map (not stretch it) when the size changes
	self.backgroundColor = [UIColor blackColor];

	ESWatchTime *tim = [[EOClock theClock] time];
	ESTimeLocAstroEnvironment *env = [[EOClock theClock] env];
	int month = tim->monthNumberUsingEnv(env);
	NSString *path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%02d-large", month+1] ofType:@"jpg"];
	img = [[UIImage alloc] initWithContentsOfFile:path];  // not imageNamed:, which would cache this big image forever
	assert(img);
	nightImg = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"night-large" ofType:@"jpg"]];
	assert(nightImg);

	redDotLayer = [[CAShapeLayer alloc] init];
	// As EODrawEarthMap draws it on the small map; path, line width and position are set in layoutSubviews
	redDotLayer.fillColor = [UIColor clearColor].CGColor;
	redDotLayer.strokeColor = [UIColor redColor].CGColor;
	[self.layer addSublayer:redDotLayer];

	blueDotLayer = [[CAShapeLayer alloc] init];
	// Like the current-location dot in Apple Maps and Google Maps; path and line width are set in layoutSubviews
	blueDotLayer.fillColor = [UIColor colorWithRed:0 green:122/255.0 blue:1 alpha:1].CGColor;
	blueDotLayer.strokeColor = [UIColor whiteColor].CGColor;
	blueDotLayer.hidden = YES;
	[self.layer addSublayer:blueDotLayer];

	matLayer = [[CAShapeLayer alloc] init];
	matLayer.fillColor = [UIColor clearColor].CGColor;
	matLayer.strokeColor = [UIColor blackColor].CGColor;
	[self.layer addSublayer:matLayer];
	borderLayer = [[CAShapeLayer alloc] init];
	borderLayer.fillColor = [UIColor clearColor].CGColor;
	borderLayer.strokeColor = [UIColor colorWithWhite:BORDER_GRAY alpha:BORDER_ALPHA].CGColor;
	borderLayer.lineJoin = kCALineJoinRound;
	[self.layer addSublayer:borderLayer];
	[self setBorderScale:1];

	cursorLayer = [[CAShapeLayer alloc] init];
	UIBezierPath *cursorPath = [UIBezierPath bezierPathWithArcCenter:CGPointZero radius:CURSOR_RADIUS startAngle:0 endAngle:2*M_PI clockwise:YES];
	[cursorPath appendPath:[UIBezierPath bezierPathWithArcCenter:CGPointZero radius:2 startAngle:0 endAngle:2*M_PI clockwise:YES]];
	cursorLayer.path = cursorPath.CGPath;
	cursorLayer.fillColor = [UIColor clearColor].CGColor;
	cursorLayer.strokeColor = [UIColor systemYellowColor].CGColor;
	cursorLayer.lineWidth = 3;
	cursorLayer.shadowColor = [UIColor blackColor].CGColor;  // so it shows up on Antarctica's white, too
	cursorLayer.shadowOpacity = 0.8;
	cursorLayer.shadowRadius = 2;
	cursorLayer.shadowOffset = CGSizeZero;
	cursorLayer.hidden = YES;
	[self.layer addSublayer:cursorLayer];

	coordinateLabel = [[UILabel alloc] init];
	coordinateLabel.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightMedium];
	coordinateLabel.textColor = [UIColor whiteColor];
	coordinateLabel.textAlignment = NSTextAlignmentCenter;
	coordinateLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
	coordinateLabel.layer.cornerRadius = 6;
	coordinateLabel.layer.masksToBounds = YES;
	coordinateLabel.hidden = YES;
	[self addSubview:coordinateLabel];
    }
    return self;
}

- (CGPoint)pointForLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees {
    CGSize size = self.bounds.size;
    return CGPointMake((longitudeDegrees + 180) / 360 * size.width, (90 - latitudeDegrees) / 180 * size.height);
}

- (double)latitudeForPoint:(CGPoint)point {
    return 90 - point.y / self.bounds.size.height * 180;
}

- (double)longitudeForPoint:(CGPoint)point {
    return point.x / self.bounds.size.width * 360 - 180;
}

- (void)setBlueDotLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees {
    showBlueDot = true;
    blueLatitudeDegrees = latitudeDegrees;
    blueLongitudeDegrees = longitudeDegrees;
    [self setNeedsLayout];
}

- (CGPoint)blueDotPoint {
    return [self pointForLatitude:blueLatitudeDegrees longitude:blueLongitudeDegrees];
}

// Scales the red dot drawn by EODrawEarthMap; the blue dot is the same size
- (double)markScale {
    return fmax(2, self.bounds.size.width / 400);
}

- (void)setBorderScale:(double)clockScale {
    matLayer.lineWidth = BORDER_GAP * clockScale;
    borderLayer.lineWidth = BORDER_LINE_WIDTH * clockScale;
    [self setNeedsLayout];
}

// How far the border reaches outside the map
- (double)borderOutset {
    return matLayer.lineWidth + borderLayer.lineWidth;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGRect bounds = self.bounds;
    matLayer.path = [UIBezierPath bezierPathWithRect:CGRectInset(bounds, -matLayer.lineWidth / 2, -matLayer.lineWidth / 2)].CGPath;
    double borderInset = -(matLayer.lineWidth + borderLayer.lineWidth / 2);
    borderLayer.path = [UIBezierPath bezierPathWithRect:CGRectInset(bounds, borderInset, borderInset)].CGPath;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect:CGRectInset(bounds, -[self borderOutset], -[self borderOutset])].CGPath;
    blueDotLayer.hidden = !showBlueDot;
    double markScale = [self markScale];
    ESLocation *location = [[EOClock theClock] env]->location();
    redDotLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointZero radius:markScale startAngle:0 endAngle:2*M_PI clockwise:YES].CGPath;
    redDotLayer.lineWidth = markScale;
    redDotLayer.position = [self pointForLatitude:location->latitudeDegrees() longitude:location->longitudeDegrees()];
    // The red dot is a ring of radius markScale and width markScale, so 1.5 * markScale across its outer edge
    blueDotLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointZero radius:1.25 * markScale startAngle:0 endAngle:2*M_PI clockwise:YES].CGPath;
    blueDotLayer.lineWidth = 0.5 * markScale;
    blueDotLayer.position = [self blueDotPoint];
    [CATransaction commit];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGSize size = self.bounds.size;
    // As on the clock, where the small map sits over the city lights: the day/night shading erases the day image,
    // so draw that in its own layer over the night image
    [nightImg drawInRect:self.bounds];
    CGContextBeginTransparencyLayer(context, NULL);
    EODrawEarthMap(context, img, size.width, size.height, [self markScale], false/*drawLocation*/,
		   [[EOClock theClock] time], [[EOClock theClock] env]);
    CGContextEndTransparencyLayer(context);
}

- (CGPoint)clampedPointForTouch:(UITouch *)touch {
    CGPoint p = [touch locationInView:self];
    CGSize size = self.bounds.size;
    return CGPointMake(fmin(fmax(p.x, 0), size.width), fmin(fmax(p.y, 0), size.height));
}

- (void)moveCursorToPoint:(CGPoint)p {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    cursorLayer.hidden = NO;
    cursorLayer.position = p;
    [CATransaction commit];

    coordinateLabel.hidden = NO;
    if (snappedToBlueDot) {
	coordinateLabel.text = NSLocalizedString(@"Location Services", @"label shown while touching the blue dot on the location picker map");
    } else {
	coordinateLabel.text = coordinateString([self latitudeForPoint:p], [self longitudeForPoint:p]);
    }
    CGSize labelSize = [coordinateLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    labelSize.width += 16;
    labelSize.height += 8;
    CGFloat y = p.y - LABEL_OFFSET;
    if (y - labelSize.height/2 < 0) {
	y = p.y + LABEL_OFFSET;  // near the top edge, below the finger instead
    }
    CGFloat x = fmin(fmax(p.x, labelSize.width/2), self.bounds.size.width - labelSize.width/2);
    coordinateLabel.bounds = CGRectMake(0, 0, labelSize.width, labelSize.height);
    coordinateLabel.center = CGPointMake(x, y);
}

- (void)hideCursor {
    cursorLayer.hidden = YES;
    coordinateLabel.hidden = YES;
}

- (void)hideCoordinateLabel {
    coordinateLabel.hidden = YES;
}

- (bool)pointIsOnBlueDot:(CGPoint)p {
    CGPoint blue = [self blueDotPoint];
    return showBlueDot && hypot(p.x - blue.x, p.y - blue.y) <= BLUE_DOT_HIT_RADIUS;
}

// Only a touch that started on the blue dot snaps to it, so one that started elsewhere can set the location right
// next to the blue dot.  Such a touch snaps whenever it is on the blue dot, even after dragging away and back.
// Otherwise the cursor stands for the new location, so the red dot hides.
- (void)trackTouchAtPoint:(CGPoint)p {
    snappedToBlueDot = touchStartedOnBlueDot && [self pointIsOnBlueDot:p];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    redDotLayer.hidden = !snappedToBlueDot;
    [CATransaction commit];
    [self moveCursorToPoint:(snappedToBlueDot ? [self blueDotPoint] : p)];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [self clampedPointForTouch:[touches anyObject]];
    touchStartedOnBlueDot = [self pointIsOnBlueDot:p];
    [self trackTouchAtPoint:p];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self trackTouchAtPoint:[self clampedPointForTouch:[touches anyObject]]];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [self clampedPointForTouch:[touches anyObject]];
    [self trackTouchAtPoint:p];
    if (snappedToBlueDot) {
	[delegate mapViewDidPickLocationServices:self];
    } else {
	[delegate mapView:self didPickLatitude:[self latitudeForPoint:p] longitude:[self longitudeForPoint:p]];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    touchStartedOnBlueDot = false;
    snappedToBlueDot = false;
    [self hideCursor];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    redDotLayer.hidden = NO;
    [CATransaction commit];
}

- (void)dealloc {
    [img release];
    [nightImg release];
    [cursorLayer release];
    [redDotLayer release];
    [blueDotLayer release];
    [matLayer release];
    [borderLayer release];
    [coordinateLabel release];
    [super dealloc];
}

@end

@implementation EOLocationPickerViewController

@synthesize sourceView;

static UIColor *
dimColor() {
    return [UIColor colorWithWhite:0 alpha:0.6];
}

- (id)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
	self.modalPresentationStyle = UIModalPresentationOverFullScreen;  // keep the clock visible, dimmed, behind the map
	self.transitioningDelegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = dimColor();

    // Tapping the dimmed area outside the map closes without changing anything
    UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancel)];
    backgroundTap.delegate = self;
    [self.view addGestureRecognizer:backgroundTap];
    [backgroundTap release];

    mapView = [[EOLocationPickerMapView alloc] initWithFrame:CGRectZero];
    mapView.delegate = self;
    mapView.layer.shadowColor = [UIColor blackColor].CGColor;
    mapView.layer.shadowOpacity = MAP_SHADOW_OPACITY;
    mapView.layer.shadowRadius = 24;
    mapView.layer.shadowOffset = CGSizeMake(0, 10);
    [self.view addSubview:mapView];

    // The blue dot marks the device's location, if we know it and may use it
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    CLAuthorizationStatus status = locationManager.authorizationStatus;
    if (status != kCLAuthorizationStatusDenied && status != kCLAuthorizationStatusRestricted) {
	if (ESDeviceLocationManager::lastLocationValid()) {
	    [mapView setBlueDotLatitude:ESDeviceLocationManager::lastLatitudeDegrees() longitude:ESDeviceLocationManager::lastLongitudeDegrees()];
	} else if (locationManager.location) {  // CoreLocation's cached fix, when the app hasn't asked for one since launch
	    CLLocationCoordinate2D coord = locationManager.location.coordinate;
	    [mapView setBlueDotLatitude:coord.latitude longitude:coord.longitude];
	}
    }
    [locationManager release];

    // No instructions on screen (touching the map should explain itself), but VoiceOver reads them
    mapView.isAccessibilityElement = YES;
    mapView.accessibilityLabel = NSLocalizedString(@"World map", @"VoiceOver name of the location picker map");
    mapView.accessibilityHint = NSLocalizedString(@"Touch the map and drag to choose a location, then lift your finger to set it.  Tap the blue dot to go back to Location Services.",
						  @"VoiceOver instructions for the location picker map");

    closeButton = [[UIButton buttonWithType:UIButtonTypeSystem] retain];
    [closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"
				 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:30]]
		 forState:UIControlStateNormal];
    closeButton.tintColor = [UIColor whiteColor];
    closeButton.accessibilityLabel = NSLocalizedString(@"Cancel", @"Cancel");
    [closeButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Match the border to the clock's frame around the small map, at the size the clock is drawn now
    if (sourceView.superview) {
	[mapView setBorderScale:[sourceView.superview convertRect:CGRectMake(0, 0, 1, 1) toView:nil].size.width];
    }

    // The 2:1 map, centered, as large as fits in 90% of the safe area
    CGRect safe = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    CGFloat mapWidth = floor(fmin(safe.size.width * 0.9, safe.size.height * 0.9 * 2));
    CGFloat mapHeight = floor(mapWidth / 2);
    CGFloat x = round(CGRectGetMidX(safe) - mapWidth / 2);
    CGFloat y = round(CGRectGetMidY(safe) - mapHeight / 2);
    CGAffineTransform transform = mapView.transform;  // set frame without a transform, and then put it back, if animating
    mapView.transform = CGAffineTransformIdentity;
    mapView.frame = CGRectMake(x, y, mapWidth, mapHeight);
    mapView.transform = transform;

    // The close button sits on the border's top right corner, like a badge
    const CGFloat buttonSize = 44;
    CGFloat outset = [mapView borderOutset];
    closeButton.frame = CGRectMake(x + mapWidth + outset - buttonSize / 2, y - outset - buttonSize / 2, buttonSize, buttonSize);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return touch.view == self.view;  // only the dimmed background, not the map or the close button
}

- (void)cancel {
    if (picked) {
	return;
    }
    picked = true;
    [self dismissViewControllerAnimated:YES completion:NULL];
}

// Change the location after the map has gone, so the clock's hands can be seen sweeping to their new positions
- (void)mapView:(EOLocationPickerMapView *)aMapView didPickLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees {
    if (picked) {
	return;
    }
    picked = true;
    pickedLocation = true;
    [self dismissViewControllerAnimated:YES completion:^{
	[[EOClock theClock] setManualLocationLatitude:latitudeDegrees longitude:longitudeDegrees];
    }];
}

- (void)mapViewDidPickLocationServices:(EOLocationPickerMapView *)aMapView {
    if (picked) {
	return;
    }
    picked = true;
    [self dismissViewControllerAnimated:YES completion:^{
	[[EOClock theClock] resumeLocationServices];
    }];
}

// UIViewControllerTransitioningDelegate			---------------------------------------------------------

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
								   presentingController:(UIViewController *)presentingController
								       sourceController:(UIViewController *)source {
    presenting = true;
    return self;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    presenting = false;
    return self;
}

// UIViewControllerAnimatedTransitioning			---------------------------------------------------------

- (bool)zooms {
    return sourceView && sourceView.window && !UIAccessibilityIsReduceMotionEnabled();
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context {
    if (![self zooms]) {
	return FADE_DURATION;
    }
    return presenting ? ZOOM_OUT_DURATION : ZOOM_IN_DURATION;
}

// Takes mapView from its own frame to the small map's, as it appears on the clock right now
- (CGAffineTransform)transformToSourceView {
    CGRect source = [sourceView convertRect:[(EOEarthView *)sourceView mapRect] toView:self.view];
    CGAffineTransform saved = mapView.transform;
    mapView.transform = CGAffineTransformIdentity;
    CGRect map = mapView.frame;
    mapView.transform = saved;
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(source) - CGRectGetMidX(map), CGRectGetMidY(source) - CGRectGetMidY(map));
    return CGAffineTransformScale(t, source.size.width / map.size.width, source.size.height / map.size.height);
}

- (void)animateShadowOpacityTo:(float)opacity duration:(NSTimeInterval)duration {
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    fade.fromValue = @(mapView.layer.presentationLayer ? mapView.layer.presentationLayer.shadowOpacity : mapView.layer.shadowOpacity);
    fade.toValue = @(opacity);
    fade.duration = duration;
    mapView.layer.shadowOpacity = opacity;
    [mapView.layer addAnimation:fade forKey:@"shadowOpacity"];
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context {
    UIView *containerView = context.containerView;
    NSTimeInterval duration = [self transitionDuration:context];
    if (presenting) {
	UIView *toView = [context viewForKey:UITransitionContextToViewKey];
	toView.frame = [context finalFrameForViewController:self];
	[containerView addSubview:toView];
	[toView layoutIfNeeded];
	closeButton.alpha = 0;
	if (![self zooms]) {
	    toView.alpha = 0;
	    [UIView animateWithDuration:duration animations:^{
		toView.alpha = 1;
		closeButton.alpha = 1;
	    } completion:^(BOOL finished) {
		[context completeTransition:!context.transitionWasCancelled];
	    }];
	    return;
	}
	// The map itself lifts out of the clock (leaving its place empty), swells to full size, and casts a shadow
	sourceView.hidden = YES;
	self.view.backgroundColor = [UIColor clearColor];
	mapView.transform = [self transformToSourceView];
	mapView.layer.shadowOpacity = 0;
	[self animateShadowOpacityTo:MAP_SHADOW_OPACITY duration:duration];
	[UIView animateWithDuration:duration delay:0 usingSpringWithDamping:ZOOM_OUT_DAMPING initialSpringVelocity:0 options:0 animations:^{
	    mapView.transform = CGAffineTransformIdentity;
	    self.view.backgroundColor = dimColor();
	} completion:^(BOOL finished) {
	    [context completeTransition:!context.transitionWasCancelled];
	}];
	// Then the close button, once the map has nearly arrived
	[UIView animateWithDuration:FADE_DURATION delay:duration * 0.6 options:0 animations:^{
	    closeButton.alpha = 1;
	} completion:NULL];
    } else {
	UIView *fromView = [context viewForKey:UITransitionContextFromViewKey];
	if (pickedLocation) {
	    [mapView hideCoordinateLabel];
	} else {
	    [mapView hideCursor];
	}
	if (![self zooms]) {
	    sourceView.hidden = NO;
	    [UIView animateWithDuration:duration animations:^{
		fromView.alpha = 0;
	    } completion:^(BOOL finished) {
		[fromView removeFromSuperview];
		[context completeTransition:!context.transitionWasCancelled];
	    }];
	    return;
	}
	[UIView animateWithDuration:FADE_DURATION * 0.6 animations:^{
	    closeButton.alpha = 0;
	}];
	[self animateShadowOpacityTo:0 duration:duration];
	[UIView animateWithDuration:duration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{
	    mapView.transform = [self transformToSourceView];
	    self.view.backgroundColor = [UIColor clearColor];
	} completion:^(BOOL finished) {
	    sourceView.hidden = NO;  // the small map takes over exactly where the large one landed
	    [fromView removeFromSuperview];
	    [context completeTransition:!context.transitionWasCancelled];
	}];
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)dealloc {
    sourceView.hidden = NO;  // in case the picker goes away some other way
    mapView.delegate = nil;
    [mapView release];
    [closeButton release];
    [super dealloc];
}

@end
