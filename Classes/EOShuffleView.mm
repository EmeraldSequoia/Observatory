//
//  EOShuffleView.m
//  Emerald Observatory
//
//  Created by Steve Pucci on 3/30/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "EOShuffleView.h"
#import "Utilities.h"
#import "EOClock.h"
#import "EOScheduledView.h"
#import "MainViewController.h"

@implementation EOShuffleView

@synthesize masterScale, requestedFrame, zeroOffset;

-(CGContextRef)setupShuffleViewForDraw {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    [[UIColor whiteColor] setFill];
    [[UIColor whiteColor] setStroke];

    // transform to center in the middle of the screen with Y increasing UP
    setupContextForZeroOffsetAndScale(context, &zeroOffset, masterScale);

    return context;
}

-(void)tick:(bool)setMode {
    // All of these views are bg views with nothing to update
}

-(void)resetTarget {
}

-(void)zeroAngle {
    // do nothing
}

-(id)initWithFrame:(CGRect)frame {
    CGRect roundedFrame;
    CGPoint aZeroOffset;
    roundOutFrameToIntegralBoundaries(&frame, 1.0/*masterScale*/, &roundedFrame, &aZeroOffset);
    [super initWithFrame:roundedFrame];
    masterScale = 1.0;
    requestedFrame = frame;
    zeroOffset = aZeroOffset;
    return self;
}

-(void)setMasterScale:(double)aMasterScale {
    masterScale = aMasterScale;
}

@end

// A shuffle view is a view which shuffles from one spot to another during device orientation animation
@implementation EORingsAndPlanetsShuffleView

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
	      plR2:(double)aPlR2
	  orbitInc:(double)anOrbitInc
      mainFontSize:(double)aMainFontSize
   subdialFontSize:(double)aSubdialFontSize
    zodiacFontSize:(double)aZodiacFontSize
smallZodiacFontSize:(double)aSmallZodiacFontSize
	 noonOnTop:(BOOL)aNoonOnTop {
    [super initWithFrame:CGRectMake(cent.x - mainRa, cent.y - mainRa, mainRa*2+12, mainRa*2+12)];
    sunD = sunDi;
    zD = zDi;
    mainR = mainRa;
    subR = subRa;
    zR = zRa;
    tickHeight = aTickHeight;
    utcOffset = aUTCOffset;
    solarOffset = aSolarOffset;
    siderealOffset = aSiderealOffset;
    secLen = aSecLen;
    plR2 = aPlR2;
    orbitInc = anOrbitInc;
    mainFontSize = aMainFontSize;
    subdialFontSize = aSubdialFontSize;
    zodiacFontSize = aZodiacFontSize;
    smallZodiacFontSize = aSmallZodiacFontSize;
    self.opaque = false;
    noonOnTop = aNoonOnTop;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupShuffleViewForDraw];

    // zodiac symbols
    UIImage *zImg = [Utilities imageFromResource:@"zodiac.png"];
    assert(zImg);
    assert(zD == zImg.size.height);
    assert(zD == zImg.size.width);
    CGContextScaleCTM(context, 1, -1);
    [zImg drawAtPoint:CGPointMake(-zD/2-1, -zD/2+1) blendMode:kCGBlendModeNormal alpha:.5];
    CGContextScaleCTM(context, 1, -1);
    //  [EOClock drawDialNumbersDemiRadial:context x:0 y:0 text:@"♓,♒,♑,♐,♏,♎,♍,♌,♋,♊,♉,♈" font:[UIFont fontWithName:@"Arial" size:zodiacFontSize] color:[UIColor colorWithRed:.67 green:.67 blue:.67 alpha:.67] radius:zR-mainFontSize/2+2 radius2:zR-mainFontSize/2+2];
    
    // 12-hour markers
    [EOClock drawDialNumbersDemiRadial:context x:0 y:0 text:@"12,1,2,3,4,5,6,7,8,9,10,11" font:[UIFont fontWithName:@"Arial" size:mainFontSize/2] color:[UIColor colorWithRed:0xfa/256.0 green:0xb7/256.0 blue:0.0 alpha:1] radius:zR-2 radius2:zR];

    // central Sun
    UIImage *bgImg = [Utilities imageFromResource:@"sun.png"];
    assert(bgImg);
    assert(sunD == bgImg.size.height);
    assert(sunD == bgImg.size.width);
    CGContextScaleCTM(context, 1, -1);
    [bgImg drawAtPoint:CGPointMake(-sunD/2, -sunD/2) blendMode:kCGBlendModeNormal alpha:.75];
    CGContextScaleCTM(context, 1, -1);

    // background
    [[UIColor colorWithRed:1 green:1 blue:1 alpha:0.125] set];
    CGContextAddArc(context, 0, 0, mainR, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathFillStroke);

    // ticks
    [EOClock drawTicks:context x:0 y:0 n: 48 innerRadius:mainR-tickHeight	    outerRadius:mainR width:2 color:[UIColor lightGrayColor]];
    [EOClock drawTicks:context x:0 y:0 n:144 innerRadius:mainR-tickHeight*.75  outerRadius:mainR width:1 color:[UIColor lightGrayColor]];
    [EOClock drawTicks:context x:0 y:0 n:720 innerRadius:mainR-tickHeight*.37  outerRadius:mainR width:1 color:[UIColor lightGrayColor]];
    // erase the long ticks on the single digit numbers
    if (noonOnTop) {
	[EOClock drawTicks:context x:0 y:0 n: 24 innerRadius:mainR-tickHeight      outerRadius:mainR-tickHeight*.7 width:2 color:[UIColor blackColor] angle1:12.9*twoPi/24 angle2:21*twoPi/24];
    } else {
	[EOClock drawTicks:context x:0 y:0 n: 24 innerRadius:mainR-tickHeight      outerRadius:mainR-tickHeight*.7 width:2 color:[UIColor blackColor] angle1:0		   angle2: 9*twoPi/24];
    }

//  static NSString *numbers24With24OnTop = @"24,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23";
    static NSString *numbers24With12OnTop = @"12,13,14,15,16,17,18,19,20,21,22,23,24,1,2,3,4,5,6,7,8,9,10,11";
    static NSString *numbers24With0OnTop  = @"0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23";
    
    // numbers
    [EOClock drawDialNumbersDemiRadial:context
				  x:0
				  y:0 
			       text:noonOnTop ? numbers24With12OnTop : numbers24With0OnTop
			       font:[UIFont fontWithName:@"Times New Roman" size:mainFontSize]
			      color:[UIColor colorWithRed:1 green:1 blue:1 alpha:.8]
			     radius:mainR
			    radius2:mainR];

#ifdef  INNER_SUBDIALS
    static NSString *evenNumbers24With12OnTop = @"12,▪,14,▪,16,▪,18,▪,20,▪,22,▪,0,▪,2,▪,4,▪,6,▪,8,▪,10,▪";
    static NSString *evenNumbers24With0OnTop  = @"0,▪,2,▪,4,▪,6,▪,8,▪,10,▪,12,▪,14,▪,16,▪,18,▪,20,▪,22,▪";
//  static NSString *fourNumbers24With12OnTop = @"12,,.,,.,,18,,.,,.,,0,,.,,.,,6,,.,,.,";
    static NSString *fourNumbers24With0OnTop  = @"0,,▪,,▪,,6,,▪,,▪,,12,,▪,,▪,,18,,▪,,▪,";
    static NSString *extraDots                = @" ,▪, ,▪, ,▪, ,▪, ,▪, ,▪,  ,▪, ,▪, ,▪,  ,▪, ,▪, ,▪";
//  static NSString *constellations24With12OnTop = @",Vir,,Lib,,Sco,,Sag,,Cap,,Aqr,,Psc,,Ari,,Tau,,Gem,,Can,,Leo";
//  static NSString *constellations24With0OnTop  = @",Psc,,Ari,,Tau,,Gem,,Can,,Leo,,Vir,,Lib,,Sco,,Sag,,Cap,,Aqr";
    
    //////////// UTC subdial
    [[UIColor colorWithRed:1 green:1 blue:1 alpha:0.125] set];
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 1);
    CGContextSetLineWidth(context, 0.5);
    CGContextAddArc(context, utcOffset.x, utcOffset.y, subR, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
    CGContextAddArc(context, utcOffset.x, utcOffset.y, subR-5, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    [EOClock drawTicks:context x:utcOffset.x y:utcOffset.y n: 12 innerRadius:subR-5 outerRadius:subR width:1.5 color:[UIColor lightGrayColor]];
    [EOClock drawTicks:context x:utcOffset.x y:utcOffset.y n: 60 innerRadius:subR-3 outerRadius:subR width:1.0 color:[UIColor lightGrayColor]];
    [EOClock drawDialNumbersUpright:context x:utcOffset.x y:utcOffset.y text:noonOnTop ? evenNumbers24With12OnTop : evenNumbers24With0OnTop font:[UIFont fontWithName:@"Arial" size:subdialFontSize] color:[UIColor whiteColor] radius:subR-5];
    //    [EOClock drawText:@"UTC" inRect:CGRectMake(utcOffset.x-50, utcOffset.y+subR/2-subdialFontSize, 100, 12) withContext:context withFont:[UIFont fontWithName:@"Arial" size:subdialFontSize+2] color:[UIColor whiteColor]];
    [EOClock drawText:@"UTC" inRect:CGRectMake(utcOffset.x-50, utcOffset.y-subR/2+subdialFontSize, 100, 12) withContext:context withFont:[UIFont fontWithName:@"Arial" size:subdialFontSize+2] color:[UIColor whiteColor]];
    
    //////////// Solar subdial
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextSetLineWidth(context, 0.5);
    CGContextAddArc(context, solarOffset.x, solarOffset.y, subR, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
    CGContextAddArc(context, solarOffset.x, solarOffset.y, subR-5, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    [EOClock drawTicks:context x:solarOffset.x y:solarOffset.y n: 12 innerRadius:subR-5 outerRadius:subR width:1.5 color:[UIColor lightGrayColor]];
    [EOClock drawTicks:context x:solarOffset.x y:solarOffset.y n: 60 innerRadius:subR-3 outerRadius:subR width:1.0 color:[UIColor lightGrayColor]];
    [EOClock drawDialNumbersUpright:context x:solarOffset.x y:solarOffset.y text:@"12,1,2,3,4,5,6,7,8,9,10,11" font:[UIFont fontWithName:@"Arial" size:subdialFontSize] color:[UIColor whiteColor] radius:subR-5];
#ifndef CAPTUREDEFAULTS
    [EOClock drawText:NSLocalizedString(@"Solar", @"the label on a dial: a truncation of 'Solar time' or 'Sun time'") inRect:CGRectMake(solarOffset.x-50, solarOffset.y-subR/2+subdialFontSize/2, 100, 12) withContext:context withFont:[UIFont fontWithName:@"Arial" size:subdialFontSize+2] color:[UIColor whiteColor]];
#endif

    //////////// Sidereal subdial
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextSetLineWidth(context, 0.5);
    CGContextAddArc(context, siderealOffset.x, siderealOffset.y, subR, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
    CGContextAddArc(context, siderealOffset.x, siderealOffset.y, subR-5, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    [EOClock drawTicks:context x:siderealOffset.x y:siderealOffset.y n: 12 innerRadius:subR-5 outerRadius:subR width:1.5 color:[UIColor lightGrayColor]];
    [EOClock drawTicks:context x:siderealOffset.x y:siderealOffset.y n: 60 innerRadius:subR-3 outerRadius:subR width:1.0 color:[UIColor lightGrayColor]];
    //    [EOClock drawDialNumbersDemiRadial:context x:siderealOffset.x y:siderealOffset.y text:noonOnTop ? constellations24With12OnTop : constellations24With0OnTop font:[UIFont fontWithName:@"Helvetica" size:subdialFontSize] color:[UIColor whiteColor] radius:subR-5 radius2:subR-5];
    [EOClock drawDialNumbersUpright:context x:siderealOffset.x y:siderealOffset.y text:fourNumbers24With0OnTop font:[UIFont fontWithName:@"Arial" size:subdialFontSize] color:[UIColor whiteColor] radius:subR-subdialFontSize-5];
    [EOClock drawDialNumbersUpright:context x:siderealOffset.x y:siderealOffset.y text:extraDots font:[UIFont fontWithName:@"Arial" size:subdialFontSize-3] color:[UIColor whiteColor] radius:subR-subdialFontSize-7];
#ifndef CAPTUREDEFAULTS
    [EOClock drawText:NSLocalizedString(@"Sidereal", @"the label on a dial: a truncation of 'sidereal time' or 'star time'") inRect:CGRectMake(siderealOffset.x-50, siderealOffset.y-subR/2+subdialFontSize/2, 100, 12) withContext:context withFont:[UIFont fontWithName:@"Arial" size:subdialFontSize+2]  color:[UIColor whiteColor]];
#endif
    // constellation names
    UIImage *sImg = [Utilities imageFromResource:@"EO-Sidereal-constellation-names-0-at-top.png"];
    assert(sImg);
    assert(149 == sImg.size.height);
    assert(149 == sImg.size.width);
    CGContextScaleCTM(context, 1, -1);
    [sImg drawAtPoint:CGPointMake(siderealOffset.x-149/2, siderealOffset.y+149/2) blendMode:kCGBlendModeNormal alpha:1];
    CGContextScaleCTM(context, 1, -1);
#endif
    
    // zodiac constellation names
//  [EOClock drawZodiacDialDemiRadial:context x:0 y:0 font:[UIFont fontWithName:@"Arial" size:smallZodiacFontSize] color:[UIColor colorWithRed:.80 green:1.0 blue:1.0 alpha:.55] radius:mainR+smallZodiacFontSize+1 radius2:mainR+smallZodiacFontSize+1];
    // ecliptic longitude numbers
//  [EOClock drawDialNumbersDemiRadial:context x:0 y:0 text:@"00,345,330,,300,,270,,240,225,210,,180,165,150,135,120,,90,,60,45,30,15" font:[UIFont fontWithName:@"Arial" size:smallZodiacFontSize] color:[UIColor colorWithRed:.67 green:.67 blue:.67 alpha:.67] radius:mainR+smallZodiacFontSize+1 radius2:mainR+smallZodiacFontSize+1];

    [EOClock drawTicksNoFives:context x:0 y:0 n: 60  innerRadius:secLen-6 outerRadius:secLen width:1  color:[UIColor lightGrayColor]];
    [EOClock drawTicksNoFives:context x:0 y:0 n: 300 innerRadius:secLen-3 outerRadius:secLen width:.5 color:[UIColor lightGrayColor]];
    
    // planet orbits: what makes it an Orrery :-)
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 1);
    CGContextSetLineWidth(context, 0.18);
    CGContextAddArc(context, 0, 0, plR2, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    CGContextAddArc(context, 0, 0, plR2-orbitInc, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    CGContextAddArc(context, 0, 0, plR2-orbitInc*2, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    CGContextAddArc(context, 0, 0, plR2-orbitInc*3, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    CGContextAddArc(context, 0, 0, plR2-orbitInc*4, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    CGContextAddArc(context, 0, 0, plR2-orbitInc*5, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);

#if 0
    CGContextSetLineWidth(context, 1.0);
    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    //CGContextAddRect(context, CGRectMake(-0.5/masterScale, -0.5/masterScale, 1/masterScale, 1/masterScale));
    CGFloat xc = self.bounds.origin.x + self.bounds.size.width/2;
    CGFloat yc = self.bounds.origin.y + self.bounds.size.height/2;
    CGContextAddRect(context, CGRectMake(xc-1, yc-1, 2, 2));
    CGContextDrawPath(context, kCGPathFill);
#endif

    CGContextRestoreGState(context);
}

@end

@implementation EOLogoShuffleView

- (id)initAtCenter:(CGPoint)cent logoWidth:(double)logoW logoHeight:(double)logoH {
    [super initWithFrame:CGRectMake(cent.x - logoW/2, cent.y - logoH/2, logoW, logoH)];
    logoWidth = logoW;
    logoHeight = logoH;
    self.opaque = false;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupShuffleViewForDraw];

    // logo
    UIImage *logoImg = [Utilities imageFromResource:@"logo.png"];
    assert(logoImg);
    CGContextScaleCTM(context, 1, -1);
    [logoImg drawAtPoint:CGPointMake(-logoWidth/2-1, -logoHeight/2) blendMode:kCGBlendModeNormal alpha:1];
    CGContextScaleCTM(context, 1, -1);
}

@end

@implementation EOAltitudeDialShuffleView

- (id)initAtCenter:(CGPoint)cent altR:(double)anAltR extFontSize:(double)anExtFontSize planetW:(double)planetWi planetH:(double)planetHt {
    [super initWithFrame:CGRectMake(cent.x - anAltR, cent.y - anAltR, anAltR*2, anAltR*2)];
    altR = anAltR;
    extFontSize = anExtFontSize;
    planetW = planetWi;
    planetH = planetHt;
    self.opaque = false;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupShuffleViewForDraw];

    CGContextSetLineWidth(context, 0.3);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 1);
    CGContextSetRGBFillColor(context, 1, 1, 1, 0.15);
    CGContextAddArc(context, 0, 0, altR, halfPi, halfPi*3, 0);
    CGContextAddArc(context, 0, 0, altR-extFontSize-1, halfPi, halfPi*3, 0);
    CGContextDrawPath(context, kCGPathEOFillStroke);
    CGContextAddArc(context, 0, 0, extFontSize-1, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, 0-altR, 0);
    CGContextDrawPath(context, kCGPathStroke);
    [EOClock drawTicks:context x:0 y:0 n: 12 innerRadius:altR-extFontSize-1   outerRadius:altR width:1.0 color:[UIColor lightGrayColor] angle1:pi angle2:twoPi];
    [EOClock drawTicks:context x:0 y:0 n: 36 innerRadius:altR-extFontSize/2-1 outerRadius:altR width:1.0 color:[UIColor lightGrayColor] angle1:pi angle2:twoPi];
    [EOClock drawTicks:context x:0 y:0 n: 72 innerRadius:altR-extFontSize/4-1 outerRadius:altR width:1.0 color:[UIColor lightGrayColor] angle1:pi angle2:twoPi];
    [EOClock drawDialNumbersDemiRadial:context x:0 y:0 text:@"90,,,,,,-90,-60,-30,-,30,60" font:[UIFont fontWithName:@"Arial" size:extFontSize] color:[UIColor whiteColor] radius:altR-extFontSize radius2:altR-extFontSize+1];
#ifndef CAPTUREDEFAULTS
    [EOClock drawText:NSLocalizedString(@"Altitude",@"the label on a dial: the angle above the horizon") inRect:CGRectMake(0-planetW/2, 0-altR/2, planetW, planetH) withContext:context withFont:[UIFont fontWithName:@"Arial" size:extFontSize]  color:[UIColor whiteColor]];
#endif
    CGContextRestoreGState(context);
}

@end

@implementation EOAzimuthDialShuffleView

- (id)initAtCenter:(CGPoint)cent azR:(double)anAzR extFontSize:(double)anExtFontSize planetW:(double)planetWi planetH:(double)planetHt {
    [super initWithFrame:CGRectMake(cent.x - anAzR, cent.y - anAzR, anAzR*2, anAzR*2)];
    azR = anAzR;
    extFontSize = anExtFontSize;
    planetW = planetWi;
    planetH = planetHt;
    self.opaque = false;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupShuffleViewForDraw];

    //////////// azimuth subdial
    CGContextSetLineWidth(context, 0.3);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 1);
    CGContextSetRGBFillColor(context, 1, 1, 1, 0.15);
    CGContextAddArc(context, 0, 0, azR, 0, twoPi, 0);
    CGContextAddArc(context, 0, 0, azR-extFontSize-1, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathEOFillStroke);
    CGContextAddArc(context, 0, 0, extFontSize-1, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
    [EOClock drawTicks:context x:0 y:0 n:16 innerRadius:extFontSize-1     outerRadius:(azR-extFontSize)*.55 width:1 color:[UIColor colorWithRed:.9 green:.5   blue:.5 alpha:.3]];
    [EOClock drawTicks:context x:0 y:0 n: 8 innerRadius:extFontSize-1     outerRadius:(azR-extFontSize)*.75 width:1 color:[UIColor colorWithRed:.3  green:.3   blue:0.9 alpha:.35]];
    [EOClock drawTicks:context x:0 y:0 n: 4 innerRadius:extFontSize-1     outerRadius:(azR-extFontSize)*.75 width:1 color:[UIColor colorWithRed:.3  green:.3   blue:1.0 alpha:.45]];
#ifndef CAPTUREDEFAULTS
    [EOClock drawDialNumbersUpright:context x:0 y:0 text:NSLocalizedString(@"N,E,S,W",@"one character abbreviations for compass points: north, east, south, west") font:[UIFont fontWithName:@"Arial" size:extFontSize] color:[UIColor whiteColor] radius:azR-extFontSize];
#endif
    [EOClock drawTicks:context x:0 y:0 n: 4 innerRadius:azR-extFontSize   outerRadius:azR width:1.0 color:[UIColor lightGrayColor]];
    [EOClock drawTicks:context x:0 y:0 n:12 innerRadius:azR-extFontSize+2 outerRadius:azR width:1.0 color:[UIColor lightGrayColor]];
    [EOClock drawTicks:context x:0 y:0 n:36 innerRadius:azR-extFontSize+4 outerRadius:azR width:1.0 color:[UIColor lightGrayColor]];
    [EOClock drawTicks:context x:0 y:0 n:72 innerRadius:azR-extFontSize+7 outerRadius:azR width:1.0 color:[UIColor lightGrayColor]];
#ifndef CAPTUREDEFAULTS
    [EOClock drawText:NSLocalizedString(@"Azimuth",@"the label on a dial: the angle around the horizon") inRect:CGRectMake(0-planetW/2, 0-azR/2, planetW, planetH) withContext:context withFont:[UIFont fontWithName:@"Arial" size:extFontSize]  color:[UIColor whiteColor]];
#endif
    CGContextRestoreGState(context);
}

@end

@implementation EOEclipseDialShuffleView

- (id)initAtCenter:(CGPoint)cent eclipseR1:(double)anEclipseR1 eclipseR2:(double)anEclipseR2 {
    [super initWithFrame:CGRectMake(cent.x - anEclipseR1, cent.y - anEclipseR2, anEclipseR2*2, anEclipseR2*2)];
    eclipseR1 = anEclipseR1;
    eclipseR2 = anEclipseR2;
    self.opaque = false;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupShuffleViewForDraw];

	//////////// leap year subdial
    CGContextSetLineWidth(context, 0.3);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 1);
    CGContextSetRGBFillColor(context, 1, 1, 1, 0.15);
    CGContextAddArc(context, 0, 0, eclipseR2, 0, twoPi, 0);
    CGContextAddArc(context, 0, 0, eclipseR1, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathEOFill);
    CGContextAddArc(context, 0, 0, eclipseR2, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    CGContextAddArc(context, 0, 0, eclipseR1, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathStroke);
    //CGContextAddArc(context, 0, 0, extFontSize-1, pi/2, -pi/2, 0);
    //CGContextDrawPath(context, kCGPathStroke);
    //CGContextMoveToPoint(context, 0-yearR+extFontSize, 0);
    //CGContextAddLineToPoint(context, 0+yearR-extFontSize, 0);
    //CGContextMoveToPoint(context, 0, 0-yearR+extFontSize);
    //CGContextAddLineToPoint(context, 0, 0+yearR-extFontSize);
    //CGContextDrawPath(context, kCGPathStroke);
    //[EOClock drawDialNumbersDemiRadial:context x:0 y:0 text:@",,,,,,,,,,,,,,,100,,,,1,,2,,3" font:[UIFont fontWithName:@"Arial" size:extFontSize] color:[UIColor whiteColor] radius:yearR radius2:yearR+1];
    //[EOClock drawDialNumbersDemiRadial:context x:0 y:0 text:@",,,4,,,,,,400,,,,,,,,,,,,,," font:[UIFont fontWithName:@"Arial" size:extFontSize] color:[UIColor yellowColor] radius:yearR radius2:yearR+1];
    //CGContextSetRGBStrokeColor(context, 1, 1, 0, 1);
    //CGContextSetRGBFillColor(context, 1, 1, 0, 0.25);
    //CGContextAddArc(context, 0, 0, eclipseR2-eclipseR1, -pi/2, pi/2, 0);
    //CGContextDrawPath(context, kCGPathFillStroke);
    CGContextRestoreGState(context);
}

@end

@implementation EOEOTDialShuffleView

- (id)initAtCenter:(CGPoint)cent EOTR:(double)anEOTR EOTFontSize:(double)anEOTFontSize {
    [super initWithFrame:CGRectMake(cent.x - anEOTR, cent.y - anEOTR, anEOTR*2, anEOTR*2)];
    EOTR = anEOTR;
    EOTFontSize = anEOTFontSize;
    self.opaque = false;
    self.userInteractionEnabled = false;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupShuffleViewForDraw];

    CGContextSetLineWidth(context, 0.3);
    CGContextSetRGBStrokeColor(context, 1, 1, 1, 1);
    CGContextSetRGBFillColor(context, 1, 1, 1, 0.1);
    // outer dial
    double x = 2.0/15*pi/2; // start angle
    CGContextAddArc(context, 0, 0, EOTR-15, pi+x, -x, 1);
    CGContextAddLineToPoint(context, 0, 0);
    CGContextAddArc(context, 0, 0, EOTR, -x, pi+x, 0);
    CGContextAddLineToPoint(context, 0, 0);
    CGContextDrawPath(context, kCGPathEOFillStroke);
    // center
    CGContextAddArc(context, 0, 0, EOTFontSize+1, 0, twoPi, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
    // vertical line
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, 0, 0+EOTR);
    CGContextDrawPath(context, kCGPathStroke);
    // ticks and label
    [EOClock drawTicks:context x:0 y:0 n: 12 innerRadius:EOTR-5 outerRadius:EOTR width:1.5 color:[UIColor lightGrayColor] angle1:0 angle2:halfPi];
    [EOClock drawTicks:context x:0 y:0 n: 60 innerRadius:EOTR-3 outerRadius:EOTR width:1.0 color:[UIColor lightGrayColor] angle1:-x angle2:halfPi+x];
    [EOClock drawTicks:context x:0 y:0 n: 12 innerRadius:EOTR-5 outerRadius:EOTR width:1.5 color:[UIColor lightGrayColor] angle1:halfPi*3 angle2:twoPi];
    [EOClock drawTicks:context x:0 y:0 n: 60 innerRadius:EOTR-3 outerRadius:EOTR width:1.0 color:[UIColor lightGrayColor] angle1:halfPi*3-x angle2:twoPi];
    [EOClock drawDialNumbersUpright:context x:0 y:0 text:@"0,5,10,+ 15,,,,,,15 –,10,5" font:[UIFont fontWithName:@"Arial" size:EOTFontSize] color:[UIColor whiteColor] radius:EOTR-5];
#ifndef CAPTUREDEFAULTS
    [EOClock drawText:NSLocalizedString(@"Equation of Time",@"the label on a dial: Equation of Time") inRect:CGRectMake(0-50, 0-EOTR/2.5, 100, 12) withContext:context withFont:[UIFont fontWithName:@"Arial" size:10] color:[UIColor whiteColor]];

#endif
    CGContextRestoreGState(context);
}

@end

@implementation EOEarthBackShuffleView

- (id)initAtCenter:(CGPoint)cent mapWidth:(double)mapW mapHeight:(double)mapH {
    [super initWithFrame:CGRectMake(cent.x - mapW/2, cent.y - mapH/2, mapW, mapH)];
    mapWidth = mapW;
    mapHeight = mapH;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupShuffleViewForDraw];
    
    // map
    UIImage *mapImg = [Utilities imageFromResource:@"night.png"];
    assert(mapImg);
    assert(mapImg.size.height == mapHeight);
    assert(mapImg.size.width == mapWidth);
    CGContextScaleCTM(context, 1, -1);
    [mapImg drawAtPoint:CGPointMake(-mapWidth/2, -mapHeight/2)];
    CGContextScaleCTM(context, 1, -1);
    CGContextRestoreGState(context);
}

@end

@implementation EOSimpleImageShuffleView

- (id)initAtCenter:(CGPoint)cent srcImageName:(NSString *)srcImageName {
    image = [[Utilities imageFromResource:srcImageName] retain];
    assert(image);
    CGSize sz = image.size;
    [super initWithFrame:CGRectMake(cent.x - sz.width/2, cent.y - sz.height/2, sz.width, sz.height)];
    self.opaque = false;
    self.alpha = 0.25;
    self.userInteractionEnabled = false;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = [self setupShuffleViewForDraw];
    
    assert(image);
    CGSize sz = image.size;
    CGContextScaleCTM(context, 1, -1);
    [image drawAtPoint:CGPointMake(-sz.width/2, -sz.height/2)];
    CGContextScaleCTM(context, 1, -1);
    CGContextRestoreGState(context);
}

- (void)dealloc {
    [image release];
    [super dealloc];
}

@end
