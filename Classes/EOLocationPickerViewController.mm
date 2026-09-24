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

#define GREEN_DOT_HIT_RADIUS 22.0  // points; a touch starting this close to the green dot picks Location Services...
#define DRAG_SLOP            10.0  // ...unless it moves farther than this before lifting
#define CURSOR_RADIUS        12.0
#define LABEL_OFFSET         44.0  // coordinate label's center above the finger, so the finger doesn't hide it

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

	greenDotLayer = [[CAShapeLayer alloc] init];
	greenDotLayer.fillColor = [UIColor clearColor].CGColor;  // path and line width are set in layoutSubviews to match the red dot
	greenDotLayer.strokeColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:1].CGColor;
	greenDotLayer.hidden = YES;
	[self.layer addSublayer:greenDotLayer];

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

- (void)setGreenDotLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees {
    showGreenDot = true;
    greenLatitudeDegrees = latitudeDegrees;
    greenLongitudeDegrees = longitudeDegrees;
    [self setNeedsLayout];
}

- (CGPoint)greenDotPoint {
    return [self pointForLatitude:greenLatitudeDegrees longitude:greenLongitudeDegrees];
}

// Scales the red dot drawn by EODrawEarthMap; the green dot matches it
- (double)markScale {
    return fmax(2, self.bounds.size.width / 400);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    greenDotLayer.hidden = !showGreenDot;
    double markScale = [self markScale];
    greenDotLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointZero radius:markScale startAngle:0 endAngle:2*M_PI clockwise:YES].CGPath;
    greenDotLayer.lineWidth = markScale;
    greenDotLayer.position = [self greenDotPoint];
    [CATransaction commit];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGSize size = self.bounds.size;
    // As on the clock, where the small map sits over the city lights: the day/night shading erases the day image,
    // so draw that in its own layer over the night image
    [nightImg drawInRect:self.bounds];
    CGContextBeginTransparencyLayer(context, NULL);
    EODrawEarthMap(context, img, size.width, size.height, [self markScale],
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
    if (touchStartedOnGreenDot) {
	coordinateLabel.text = NSLocalizedString(@"Location Services", @"label shown while touching the green dot on the location picker map");
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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [self clampedPointForTouch:[touches anyObject]];
    touchStartPoint = p;
    CGPoint green = [self greenDotPoint];
    touchStartedOnGreenDot = showGreenDot && hypot(p.x - green.x, p.y - green.y) <= GREEN_DOT_HIT_RADIUS;
    [self moveCursorToPoint:p];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [self clampedPointForTouch:[touches anyObject]];
    if (touchStartedOnGreenDot && hypot(p.x - touchStartPoint.x, p.y - touchStartPoint.y) > DRAG_SLOP) {
	touchStartedOnGreenDot = false;  // a drag, even one passing back over the green dot, picks a spot on the map
    }
    [self moveCursorToPoint:p];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [self clampedPointForTouch:[touches anyObject]];
    if (touchStartedOnGreenDot) {
	[delegate mapViewDidPickLocationServices:self];
    } else {
	[delegate mapView:self didPickLatitude:[self latitudeForPoint:p] longitude:[self longitudeForPoint:p]];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    touchStartedOnGreenDot = false;
    [self hideCursor];
}

- (void)dealloc {
    [img release];
    [nightImg release];
    [cursorLayer release];
    [greenDotLayer release];
    [coordinateLabel release];
    [super dealloc];
}

@end

@implementation EOLocationPickerViewController

- (id)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
	self.modalPresentationStyle = UIModalPresentationOverFullScreen;  // keep the clock visible, dimmed, behind the map
	self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];

    // Tapping the dimmed area outside the map closes without changing anything
    UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancel)];
    backgroundTap.delegate = self;
    [self.view addGestureRecognizer:backgroundTap];
    [backgroundTap release];

    mapView = [[EOLocationPickerMapView alloc] initWithFrame:CGRectZero];
    mapView.delegate = self;
    [self.view addSubview:mapView];

    // The green dot marks the device's location, if we know it and may use it
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    CLAuthorizationStatus status = locationManager.authorizationStatus;
    if (status != kCLAuthorizationStatusDenied && status != kCLAuthorizationStatusRestricted) {
	if (ESDeviceLocationManager::lastLocationValid()) {
	    [mapView setGreenDotLatitude:ESDeviceLocationManager::lastLatitudeDegrees() longitude:ESDeviceLocationManager::lastLongitudeDegrees()];
	} else if (locationManager.location) {  // CoreLocation's cached fix, when the app hasn't asked for one since launch
	    CLLocationCoordinate2D coord = locationManager.location.coordinate;
	    [mapView setGreenDotLatitude:coord.latitude longitude:coord.longitude];
	}
    }
    [locationManager release];

    hintLabel = [[UILabel alloc] init];
    hintLabel.font = [UIFont systemFontOfSize:17];
    hintLabel.textColor = [UIColor whiteColor];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.numberOfLines = 0;
    hintLabel.text = NSLocalizedString(@"Touch the map and drag to choose a location, then lift your finger to set it.  Tap the green dot to go back to Location Services.",
				       @"instructions above the location picker map");
    [self.view addSubview:hintLabel];

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
    CGRect safe = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    const CGFloat buttonSize = 44;
    const CGFloat gap = 8;
    CGFloat maxWidth = safe.size.width * 0.9;

    // Size the hint for the widest the map could be, then fit the 2:1 map in what's left of 90% of the height
    CGFloat hintHeight = ceil([hintLabel sizeThatFits:CGSizeMake(maxWidth - 2 * (buttonSize + gap), CGFLOAT_MAX)].height);
    CGFloat headerHeight = fmax(hintHeight, buttonSize) + gap;
    CGFloat maxHeight = safe.size.height * 0.9 - headerHeight;
    CGFloat mapWidth = floor(fmin(maxWidth, maxHeight * 2));
    CGFloat mapHeight = floor(mapWidth / 2);
    CGFloat x = round(CGRectGetMidX(safe) - mapWidth / 2);
    CGFloat y = round(CGRectGetMidY(safe) - (mapHeight + headerHeight) / 2 + headerHeight);
    mapView.frame = CGRectMake(x, y, mapWidth, mapHeight);

    CGFloat headerY = y - headerHeight;
    closeButton.frame = CGRectMake(x + mapWidth - buttonSize, headerY, buttonSize, buttonSize);
    CGFloat hintWidth = mapWidth - 2 * (buttonSize + gap);  // centered over the map, clear of the close button
    hintLabel.frame = CGRectMake(x + buttonSize + gap, headerY + (headerHeight - gap - hintHeight) / 2, hintWidth, hintHeight);
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

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)dealloc {
    mapView.delegate = nil;
    [mapView release];
    [hintLabel release];
    [closeButton release];
    [super dealloc];
}

@end
