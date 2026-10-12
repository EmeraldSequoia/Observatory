//
//  EOLocationPickerViewController.h
//  Emerald Observatory
//
//  Copyright 2026 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class EOLocationPickerMapView;
class ESGeoNames;

@protocol EOLocationPickerMapViewDelegate
- (void)mapView:(EOLocationPickerMapView *)mapView didPickLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees;
- (void)mapViewDidPickLocationServices:(EOLocationPickerMapView *)mapView;
@end

// A large Earth map.  Touch and drag to move a cursor; lifting sets the location there.  A touch that starts on the
// blue dot (the device's location), or any touch while the clock is on Location Services, snaps the cursor to the blue
// dot whenever it is on it, and lifting there picks Location Services instead.  The red dot (the current location)
// hides while the cursor is moving it elsewhere.  A magnifier at the map's top center shows the map under the finger,
// so the finger hides nothing; and a label above that names a nearby city in the time zone a lift would set, and gives
// the latitude and longitude.  Between touches, they show the current location.  The map's frame and shadow go around
// the magnifier and label too.
@interface EOLocationPickerMapView : UIView {
    id<EOLocationPickerMapViewDelegate> delegate;  // not retained
    UIImage             *img;
    UIImage             *nightImg;
    CAShapeLayer        *cursorLayer;
    CAShapeLayer        *redDotLayer;  // not drawn with the map, so it can hide quickly while a drag moves the location
    CAShapeLayer        *blueDotLayer;
    CAShapeLayer        *matLayer;     // the black gap between the map and its border...
    CAShapeLayer        *borderLayer;  // ...and the border, like the clock's frame around the small map
    CALayer             *loupeLayer;   // the magnifier, with its shadow...
    CALayer             *loupeMapLayer;     // ...the whole map, magnified, placed so the cursor's point is at its center...
    CAShapeLayer        *loupeRedDotLayer;  // ...with the dots on it
    CAShapeLayer        *loupeBlueDotLayer;
    CAShapeLayer        *loupeCursorLayer;
    UIImage             *loupeImage;   // the map as drawn, at the image's own resolution; made at the first touch
    bool                framed;        // the magnifier and label show, with the frame around them
    UIView              *labelPlate;   // the black rounded plate holding the two labels
    UILabel             *cityLabel;
    UILabel             *coordinateLabel;
    UIFont              *cityFont;     // made as needed, at the current Dynamic Type size
    UIFont              *coordinateFont;
    CGFloat             latitudeTabStop;   // where the latitude's number ends in its fixed-width field...
    CGFloat             longitudeTabStop;  // ...and the longitude's
    CGFloat             coordinatesWidth;  // the coordinate line's fixed width
    ESGeoNames          *geoNames;     // kept for the picker's lifetime, so the city data stays loaded while dragging
    NSString            *cityText;     // nil if no city is near
    long                cityKeyLatitude;  // the cursor position cityText is for, in hundredths of a degree
    long                cityKeyLongitude;
    bool                cityKeyValid;
    bool                showBlueDot;
    double              blueLatitudeDegrees;
    double              blueLongitudeDegrees;
    bool                touchSnapsToBlueDot;
    bool                snappedToBlueDot;
    bool                ignoringTouch; // it started on the magnifier or label
}

@property (nonatomic, assign) id<EOLocationPickerMapViewDelegate> delegate;

- (void)setBlueDotLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees;
- (void)hideCursor;
- (void)setFramed:(bool)framed duration:(NSTimeInterval)duration;
- (void)setBorderScale:(double)clockScale;  // points per clock canvas unit, so the border matches the clock's

@end

// Presented full screen over the clock when the small Earth map is tapped.  The large map zooms out of the small one
// (sourceView) and back into it when closed.
@interface EOLocationPickerViewController : UIViewController <EOLocationPickerMapViewDelegate, UIGestureRecognizerDelegate,
							      UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning> {
    EOLocationPickerMapView *mapView;
    UIButton            *closeButton;
    UIView              *sourceView;  // not retained
    bool                picked;
    bool                pickedLocation;  // the cursor rides the map back down, landing where the red dot will be
    bool                presenting;      // which way the transition being animated goes
}

@property (nonatomic, assign) UIView *sourceView;  // an EOEarthView

@end
