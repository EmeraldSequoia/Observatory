//
//  Utilities.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 4/16/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "ESAstroConstants.hpp"

extern size_t ECMaxLoadedTextureSize;
extern double EC_fmod(double arg1, double arg2);
extern void printADate(NSTimeInterval dt);


@interface Utilities: NSObject {
}

+ (void)startOfMain;
+ (void)noteTimeAtPhase:(const char *)phaseName;
+ (void)noteTimeAtPhaseWithString:(NSString *)phaseName;
+ (void)setNewOrientation:(UIInterfaceOrientation)newOrient;
+ (UIInterfaceOrientation)currentOrientation;
+ (bool)currentOrientationIsLandscape;
+ (void)translatePointIntoCurrentOrientation:(CGPoint *)point;
+ (CGSize)applicationSize;
+ (CGSize)untranslatedApplicationSize;
+ (void)translateCornerRelativeOrigin:(CGPoint *)origin;
+ (UIImage *)imageFromResource:(NSString *)imgName;
+ (void)printAllFonts;
+ (NSString *)nameOfPlanetWithNumber:(ECPlanetNumber)planetNumber;
@end
