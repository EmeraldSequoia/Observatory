//
//  EOEclipseRingImageView.h
//  Emerald Orrery
//
//  Created by Steve Pucci on 27 Nov 2010
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"


@interface EOEclipseRingImageView : EOHandView {
    UIImage	*img;
    double	radius;
}

@property (readonly, nonatomic) double radius;

- (EOEclipseRingImageView *)initWithKind:(EOHandKind)aKind name:(NSString *)fn radius:(double)aRadius x:(double)ax y:(double)ay update:(double)aUpdate;

@end
