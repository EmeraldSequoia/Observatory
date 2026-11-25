//
//  EOHandImageView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/18/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"


@interface EOHandImageView : EOHandView {
    UIImage	*img;
    double	radius;
    // Saturn only: the ring geometry last drawn (radians), drawn in code rather than from img
    double	ringEarthTilt;
    double	ringSunTilt;
    double	ringDeltaU;
    bool	ringGeometryValid;
}

- (EOHandImageView *)initWithKind:(EOHandKind)aKind name:(NSString *)fn x:(double)ax y:(double)ay radius:(double)aRadius update:(double)aUpdate;

@end
