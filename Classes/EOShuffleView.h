//
//  EOShuffleView.h
//  Emerald Observatory
//
//  Created by Steve Pucci on 3/30/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// A shuffle view is a view which shuffles from one spot to another during device orientation animation
@interface EOShuffleView : UIView {
    double masterScale;
    CGRect                  requestedFrame;  // The frame we ask for prior to masterScale, with the zero point exactly at the center
    CGPoint                 zeroOffset;      // The offset of zero (the "center" of the view, which may be offset by fractional pixels from the actual center)
}

@property(nonatomic) double masterScale;
@property(nonatomic) CGRect requestedFrame;
@property(nonatomic) CGPoint zeroOffset;

-(void)setMasterScale:(double)masterScale;

@end

@interface EORingsAndPlanetsShuffleView : EOShuffleView {
    double mainR;
    double subR;
    double zR;
    double tickHeight;
    CGPoint utcOffset;
    CGPoint solarOffset;
    CGPoint siderealOffset;
    double secLen;
    double plR2;
    double orbitInc;
    int sunD;
    int zD;
    int mainFontSize;
    int subdialFontSize;
    double zodiacFontSize;
    double smallZodiacFontSize;
    BOOL noonOnTop;
}

- (id)initAtCenter:(CGPoint)cent
	      sunD:(int)sunDi
                zD:(int)zDi
	     mainR:(double)mainRa
	      subR:(double)subRa
		zR:(double)zRa
	tickHeight:(double)aTickHeight
	 utcOffset:(CGPoint)aUTCOffset
       solarOffset:(CGPoint)aSolarOffset
    siderealOffset:(CGPoint)aSiderealOffset
	    secLen:(double)aSecLen
	      plR2:(double)plR2
	  orbitInc:(double)orbitInc
      mainFontSize:(double)mainFontSize
   subdialFontSize:(double)subdialFontSize
    zodiacFontSize:(double)zodiacFontSize
smallZodiacFontSize:(double)smallZodiacFontSize
	 noonOnTop:(BOOL)aNoonOnTop;

@end

@interface EOLogoShuffleView : EOShuffleView {
    double logoWidth;
    double logoHeight;
}

- (id)initAtCenter:(CGPoint)cent logoWidth:(double)logoW logoHeight:(double)logoH;
    
@end

@interface EOAltitudeDialShuffleView : EOShuffleView {
    double altR;
    double extFontSize;
    double planetW;
    double planetH;
}

- (id)initAtCenter:(CGPoint)cent altR:(double)anAltR extFontSize:(double)anExtFontSize planetW:(double)planetWi planetH:(double)planetHt;

@end

@interface EOAzimuthDialShuffleView : EOShuffleView {
    double azR;
    double extFontSize;
    double planetW;
    double planetH;
}

- (id)initAtCenter:(CGPoint)cent azR:(double)anAzR extFontSize:(double)anExtFontSize planetW:(double)planetWi planetH:(double)planetHt;

@end

@interface EOEclipseDialShuffleView : EOShuffleView {
    double eclipseR1;
    double eclipseR2;
}

- (id)initAtCenter:(CGPoint)cent eclipseR1:(double)anEclipseR1 eclipseR2:(double)anEclipseR2;

@end

@interface EOEOTDialShuffleView : EOShuffleView {
    double EOTR;
    double EOTFontSize;
}

- (id)initAtCenter:(CGPoint)cent EOTR:(double)anEOTR EOTFontSize:(double)anEOTFontSize;

@end

@interface EOEarthBackShuffleView : EOShuffleView {
    double mapWidth;
    double mapHeight;
}

- (id)initAtCenter:(CGPoint)cent mapWidth:(double)mapW mapHeight:(double)mapH;

@end


@interface EOSimpleImageShuffleView : EOShuffleView {
    UIImage *image;
}

- (id)initAtCenter:(CGPoint)cent srcImageName:(NSString *)srcImageName;

@end



