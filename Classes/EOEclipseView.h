//
//  EOEclipseView.h
//  Emerald Orrery
//
//  Created by Steve Pucci on 28 Nov 2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"


@interface EOEclipseView : EOHandView {
    UIImage	*sunImage;
    UIImage	*moonImage;
    UIImage     *earthShadowImage;
    UIImage     *totalSolarImage;
    UILabel     *statusLabel;
    UILabel     *horizonLabel;
    double      sunRadiusFraction;
    double      earthShadowRadiusFraction;
    double	moonRadiusAtPerigee;
    double      viewRadius;
}

- (EOEclipseView *)initWithMoonImageName:(NSString *)moonImageName
			    sunImageName:(NSString *)sunImageName
		    earthShadowImageName:(NSString *)earthShadowImageName
		     totalSolarImageName:(NSString *)totalSolarImageName
	       earthShadowRadiusFraction:(double)anEarthShadowRadiusFraction
		       sunRadiusFraction:(double)sunRadiusFraction  // The fraction of the image width/height that is taken up by the Sun itself
				       x:(double)ax
				       y:(double)ay
			      viewRadius:(double)aViewRadius
		     moonRadiusAtPerigee:(double)aRadius
				  update:(double)aUpdate;

- (void)setStatusLabel:(UILabel *)statusLabel horizonLabel:(UILabel *)horizonLabel;

@end
