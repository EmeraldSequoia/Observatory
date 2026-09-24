//
//  EOLocationPickerViewController.h
//  Emerald Observatory
//
//  Copyright 2026 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class EOLocationPickerMapView;

@protocol EOLocationPickerMapViewDelegate
- (void)mapView:(EOLocationPickerMapView *)mapView didPickLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees;
- (void)mapViewDidPickLocationServices:(EOLocationPickerMapView *)mapView;
@end

// A large Earth map.  Touch and drag to move a cursor; lifting sets the location there.  A touch that starts on the
// green dot (the device's location) and lifts without dragging away picks Location Services instead.
@interface EOLocationPickerMapView : UIView {
    id<EOLocationPickerMapViewDelegate> delegate;  // not retained
    UIImage             *img;
    UIImage             *nightImg;
    CAShapeLayer        *cursorLayer;
    CAShapeLayer        *greenDotLayer;
    UILabel             *coordinateLabel;
    bool                showGreenDot;
    double              greenLatitudeDegrees;
    double              greenLongitudeDegrees;
    bool                touchStartedOnGreenDot;
    CGPoint             touchStartPoint;
}

@property (nonatomic, assign) id<EOLocationPickerMapViewDelegate> delegate;

- (void)setGreenDotLatitude:(double)latitudeDegrees longitude:(double)longitudeDegrees;
- (void)hideCursor;
- (void)hideCoordinateLabel;

@end

// Presented full screen over the clock when the small Earth map is tapped.  The large map zooms out of the small one
// (sourceView) and back into it when closed.
@interface EOLocationPickerViewController : UIViewController <EOLocationPickerMapViewDelegate, UIGestureRecognizerDelegate,
							      UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning> {
    EOLocationPickerMapView *mapView;
    UILabel             *hintLabel;
    UIButton            *closeButton;
    UIView              *sourceView;  // not retained
    bool                picked;
    bool                pickedLocation;  // the cursor rides the map back down, landing where the red dot will be
    bool                presenting;      // which way the transition being animated goes
}

@property (nonatomic, assign) UIView *sourceView;  // an EOEarthView

@end
