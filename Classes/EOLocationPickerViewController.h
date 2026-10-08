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
// blue dot (the device's location) snaps the cursor to the blue dot whenever it is on it, and lifting there picks
// Location Services instead.  The red dot (the current location) hides while the cursor is moving it elsewhere.  A label
// over the cursor names a nearby city in the time zone a lift would set, and gives the latitude and longitude.
@interface EOLocationPickerMapView : UIView {
    id<EOLocationPickerMapViewDelegate> delegate;  // not retained
    UIImage             *img;
    UIImage             *nightImg;
    CAShapeLayer        *cursorLayer;
    CAShapeLayer        *redDotLayer;  // not drawn with the map, so it can hide quickly while a drag moves the location
    CAShapeLayer        *blueDotLayer;
    CAShapeLayer        *matLayer;     // the black gap between the map and its border...
    CAShapeLayer        *borderLayer;  // ...and the border, like the clock's frame around the small map
    UIView              *labelPlate;   // the dark rounded plate holding the two labels
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
    bool                touchStartedOnBlueDot;
    bool                snappedToBlueDot;
}

@property (nonatomic, assign) id<EOLocationPickerMapViewDelegate> delegate;

- (void)setBlueDotLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees;
- (void)hideCursor;
- (void)hideCoordinateLabel;
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
