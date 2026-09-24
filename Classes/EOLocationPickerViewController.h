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

@end

// Presented full screen over the clock when the small Earth map is tapped
@interface EOLocationPickerViewController : UIViewController <EOLocationPickerMapViewDelegate, UIGestureRecognizerDelegate> {
    EOLocationPickerMapView *mapView;
    UILabel             *hintLabel;
    UIButton            *closeButton;
    bool                picked;
}

@end
