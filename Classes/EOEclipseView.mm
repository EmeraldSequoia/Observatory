//
//  EOEclipseView.m
//  Emerald Orrery
//
//  Created by Steve Pucci on 28 Nov 2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "EOEclipseView.h"
#import "EOClock.h"
#import "Utilities.h"
#import "Constants.h"
#import "ESAstronomy.hpp"

@implementation EOEclipseView

- (EOEclipseView *)initWithMoonImageName:(NSString *)moonImageName
			    sunImageName:(NSString *)sunImageName
		    earthShadowImageName:(NSString *)earthShadowImageName
		     totalSolarImageName:(NSString *)totalSolarImageName
	       earthShadowRadiusFraction:(double)anEarthShadowRadiusFraction
		       sunRadiusFraction:(double)aSunRadiusFraction  // The fraction of the image width/height that is taken up by the Sun itself
				       x:(double)ax
				       y:(double)ay
			      viewRadius:(double)aViewRadius
		     moonRadiusAtPerigee:(double)aRadius
				  update:(double)aUpdate {
    [super initWithFrame:CGRectMake( ax + [EOClock clockCenter].x - aViewRadius,
				    -ay + [EOClock clockCenter].y - aViewRadius,
				     aViewRadius * 2,
				     aViewRadius * 2)
		    kind:EOEclipse
		  update:aUpdate
	     strokeColor:nil
	       fillColor:nil];
    sunImage = [[Utilities imageFromResource:sunImageName] retain];
    moonImage = [[Utilities imageFromResource:moonImageName] retain];
    totalSolarImage = [[Utilities imageFromResource:totalSolarImageName] retain];
    earthShadowImage = [[Utilities imageFromResource:earthShadowImageName] retain];
    sunRadiusFraction = aSunRadiusFraction;
    earthShadowRadiusFraction = anEarthShadowRadiusFraction;
    viewRadius = aViewRadius;
    moonRadiusAtPerigee = aRadius;
    update = aUpdate;
    return self;
}

- (void)setStatusLabel:(UILabel *)aStatusLabel horizonLabel:(UILabel *)aHorizonLabel {
    statusLabel = [aStatusLabel retain];
    horizonLabel = [aHorizonLabel retain];
}

- (void) dealloc {
    [sunImage release];
    [moonImage release];
    [totalSolarImage release];
    [earthShadowImage release];
    [statusLabel release];
    [horizonLabel release];
    [super dealloc];
}

- (void)drawRect:(CGRect)rect {
#ifndef CAPTUREDEFAULTS
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    astro->setupLocalEnvironmentForThreadFromActionButton(false, [[EOClock theClock] time]);

    // For the moon
    const double perigeeDistance = 355000.0;	    // km
    const double au = 149600000.0;		    // km; units of planetGeocentricDistance
    const double lunarRadius =   1737.10;	    // km
    const double solarRadius = 695500;              // km

    const double moonAngularRadiusAtPerigee = atan(lunarRadius/perigeeDistance);
    //EC_printAngle(moonAngularRadiusAtPerigee, "moonAngularRadiusAtPerigee");
    const double pixelsPerAngularRadian = moonRadiusAtPerigee / moonAngularRadiusAtPerigee;
    //printf("moonRad / moonAngularRad = %.2f / %.2f = %.2f\n", moonRadiusAtPerigee, moonAngularRadiusAtPerigee, pixelsPerAngularRadian);
    
    const double moonAngularRadiusNow = atan(lunarRadius/(astro->planetGeocentricDistance(ECPlanetMoon)*au));
    const double moonPixelRadiusNow = pixelsPerAngularRadian * moonAngularRadiusNow;
    //EC_printAngle(moonAngularRadiusNow, "moonAngularRadiusNow");
    //printf("Pixel radii now: sun=%.2f, moon=%.2f\n", sunPixelRadiusNow, moonPixelRadiusNow);

    double angularSeparation = astro->eclipseAngularSeparation();
    float w = self.bounds.size.width;
    float h = self.bounds.size.height;
    assert(w == h);

    if (angularSeparation < M_PI / 18) {  // 10 degrees -- if the separation is greater than this, there's nothing to do
	// We know the separation.  We need to maintain that in the drawn picture.  But we'd like at least an approximation of the
	// angle between the objects.  So we calculate Y/X for the alt/az

	//EC_printAngle(angularSeparation, "angularSeparation");

	ECEclipseKind eclipseKind = astro->eclipseKind();
	bool solarNotLunar = ESAstronomyManager::eclipseKindIsMoreSolarThanLunar(eclipseKind);

	const double sunAngularRadiusNow = atan(solarRadius/(astro->planetGeocentricDistance(ECPlanetSun)*au));
	const double sunPixelRadiusNow = pixelsPerAngularRadian * sunAngularRadiusNow;
	//EC_printAngle(sunAngularRadiusNow, "sunAngularRadiusNow");

	double moonAltitude = astro->planetAltitude(ECPlanetMoon);
	double moonAzimuth = EC_fmod(astro->planetAzimuth(ECPlanetMoon), M_PI * 2);
	//EC_printAngle(moonAltitude, "moonAltitude");
	//EC_printAngle(moonAzimuth, "moonAzimuth");

	// pixel coordinates referenced to center of view
	CGContextTranslateCTM(context, w/2, h/2);
	CGContextAddEllipseInRect(context, CGRectMake(-w/2, -h/2, w, h));
	CGContextClip(context);
	float horizonPixelY = 0;
	bool drawingSomething = false;
	if (solarNotLunar) {
	    double sunAltitude = astro->planetAltitude(ECPlanetSun);
	    //EC_printAngle(sunAltitude, "sunAltitude");
	    double sunAzimuth = EC_fmod(astro->planetAzimuth(ECPlanetSun), M_PI * 2);
	    //EC_printAngle(sunAzimuth, "sunAzimuth");

	    double azDelta = EC_fmod(moonAzimuth - sunAzimuth, M_PI * 2);
	    //EC_printAngle(azDelta, "azDelta");
	    double altDelta = moonAltitude - sunAltitude;
	    //EC_printAngle(altDelta, "altDelta");

	    if (azDelta > M_PI) {
		azDelta = azDelta - 2 * M_PI;
	    }
	    //EC_printAngle(azDelta, "azDelta (2)");
	    //double avgAz = EC_fmod(sunAzimuth + azDelta / 2, M_PI * 2);
	    double avgAlt = (moonAltitude + sunAltitude) / 2;
	    //EC_printAngle(avgAlt, "avgAlt");

	    double azFudgeForAlt = fabs(cos(avgAlt));
	    //printf("azFudgeForAlt = %.4f\n", azFudgeForAlt);
	    if (azFudgeForAlt < 0.01) {
		azFudgeForAlt = 0.01;
	    }
	    double angleBetweenObjects = atan2(altDelta, azDelta*azFudgeForAlt);
	    //EC_printAngle(angleBetweenObjects, "angleBetweenObjects");
	    
	    double cosTheta = cos(angleBetweenObjects);
	    double sinTheta = sin(angleBetweenObjects);
	    double moonPixelX = cosTheta * angularSeparation * pixelsPerAngularRadian / 2;
	    double sunPixelX = - moonPixelX;
	    double moonPixelY = -sinTheta * angularSeparation * pixelsPerAngularRadian / 2;  // change in sign from view coordinate system
	    double sunPixelY = - moonPixelY;
	    horizonPixelY = - avgAlt*pixelsPerAngularRadian;
	    //printf("setting horizonPixelY to %.2f based on avgAlt %.2f\n", horizonPixelY, avgAlt);

	    if (eclipseKind == ECEclipseTotalSolar) {
		// draw total eclipse image at moonPixelX, moonPixelY
		const double totalPixelRadiusNow = moonPixelRadiusNow / sunRadiusFraction;
		[totalSolarImage drawInRect:CGRectMake(moonPixelX - totalPixelRadiusNow, moonPixelY - totalPixelRadiusNow,
						       totalPixelRadiusNow * 2, totalPixelRadiusNow * 2)];
		drawingSomething = true;
	    } else {
		double distanceToMoonCenter = sqrt(moonPixelX * moonPixelX + moonPixelY * moonPixelY);
		double distanceToSunCenter = distanceToMoonCenter; // (they are opposites)
		drawingSomething = distanceToMoonCenter - moonPixelRadiusNow < w/2 || distanceToSunCenter - sunPixelRadiusNow < w/2;

		// Draw blue sky?  But beware of green below-horizon overlay, and there really isn't a black hole where the Moon is.
		//if (drawingSomething) {
		    //[[UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:1.0] setFill];
		    //CGContextFillRect(context, CGRectMake(-w/2, -h/2, w, h));
		//}

		// Draw sun image, then black it out with moon silhouette
		[sunImage drawInRect:CGRectMake(sunPixelX - sunPixelRadiusNow, sunPixelY - sunPixelRadiusNow,
						sunPixelRadiusNow * 2, sunPixelRadiusNow * 2)];
		//printf("Drawing sun at (%.2f, %.2f) in rect %.2f %.2f %.2f %.2f\n", sunPixelX, sunPixelY, sunPixelX - sunPixelRadiusNow, sunPixelY - sunPixelRadiusNow,
		//   sunPixelRadiusNow*2, sunPixelRadiusNow*2);
		[[UIColor colorWithRed:.08 green:.08 blue:.09 alpha:1.0] setFill];
		[[UIColor colorWithRed:1 green:1 blue:1 alpha:0.15] setStroke];
		CGContextAddEllipseInRect(context, CGRectMake(moonPixelX - moonPixelRadiusNow, moonPixelY - moonPixelRadiusNow,
							      moonPixelRadiusNow * 2, moonPixelRadiusNow * 2));
		CGContextDrawPath(context, kCGPathFillStroke);
		//printf("Filling moon at (%.2f, %.2f) in rect %.2f %.2f %.2f %.2f\n", moonPixelX, moonPixelY, moonPixelX - moonPixelRadiusNow, moonPixelY - moonPixelRadiusNow,
		//   moonPixelRadiusNow*2, moonPixelRadiusNow*2);
	    }
	} else {
	    double sunAltitude = astro->planetAltitude(ECPlanetSun);
	    //EC_printAngle(sunAltitude, "sunAltitude");
	    double sunAzimuth = astro->planetAzimuth(ECPlanetSun);
	    //EC_printAngle(sunAzimuth, "sunAzimuth");

	    double earthShadowAltitude = -sunAltitude;
	    double earthShadowAzimuth = EC_fmod(sunAzimuth + M_PI, M_PI * 2);
	    //EC_printAngle(earthShadowAltitude, "earthShadowAltitude");
	    //EC_printAngle(earthShadowAzimuth, "earthShadowAzimuth");

	    const double earthShadowAngularRadiusNow = astro->eclipseShadowAngularSize() / 2;
	    //EC_printAngle(earthShadowAngularRadiusNow, "earthShadowAngularRadiusNow");

	    // Center on midpoint between edge of shadow and center of moon -- transitions smoothly to eclipse case where we center on the moon
	    double azDelta = EC_fmod(earthShadowAzimuth - moonAzimuth, M_PI * 2);
	    //EC_printAngle(azDelta, "azDelta");
	    double altDelta = earthShadowAltitude - moonAltitude;
	    //EC_printAngle(altDelta, "altDelta");

	    if (azDelta > M_PI) {
		azDelta = azDelta - 2 * M_PI;
	    }
	    //EC_printAngle(azDelta, "azDelta (2)");
	    //double avgAz = EC_fmod(sunAzimuth + azDelta / 2, M_PI * 2);
	    double avgAlt = (earthShadowAltitude + moonAltitude) / 2;
	    //EC_printAngle(avgAlt, "avgAlt");
	    horizonPixelY = - avgAlt*pixelsPerAngularRadian;
	    //printf("setting horizonPixelY to %.2f based on avgAlt %.2f\n", horizonPixelY, avgAlt);

	    double moonPixelX;
	    double earthShadowPixelX;
	    double moonPixelY;
	    double earthShadowPixelY;
	    if (angularSeparation > earthShadowAngularRadiusNow) {
		double azFudgeForAlt = fabs(cos(avgAlt));
		if (azFudgeForAlt < 0.01) {
		    azFudgeForAlt = 0.01;
		}
		//printf("azFudgeForAlt = %.4f, azDelta*fudge = %.4f\n", azFudgeForAlt, azDelta*azFudgeForAlt);
		double angleBetweenObjects = atan2(altDelta, azDelta*azFudgeForAlt);
		//EC_printAngle(angleBetweenObjects, "angleBetweenObjects");
	    
		double cosTheta = cos(angleBetweenObjects);
		double sinTheta = sin(angleBetweenObjects);

		moonPixelX = -cosTheta * (angularSeparation - earthShadowAngularRadiusNow) * pixelsPerAngularRadian / 2;
		earthShadowPixelX = cosTheta * (angularSeparation + earthShadowAngularRadiusNow) * pixelsPerAngularRadian / 2;
		moonPixelY = sinTheta * (angularSeparation - earthShadowAngularRadiusNow) * pixelsPerAngularRadian / 2;         // change in sign from view coordinate system
		earthShadowPixelY = -sinTheta * (angularSeparation + earthShadowAngularRadiusNow) * pixelsPerAngularRadian / 2; // change in sign from view coordinate system

	    } else { // eclipse
		double azFudgeForAlt = fabs(cos(moonAltitude));
		if (azFudgeForAlt < 0.01) {
		    azFudgeForAlt = 0.01;
		}
		//printf("azFudgeForAlt = %.4f, azDelta*fudge = %.4f\n", azFudgeForAlt, azDelta*azFudgeForAlt);
		double angleBetweenObjects = atan2(altDelta, azDelta*azFudgeForAlt);
		//EC_printAngle(angleBetweenObjects, "angleBetweenObjects");
	    
		double cosTheta = cos(angleBetweenObjects);
		double sinTheta = sin(angleBetweenObjects);

		moonPixelX = 0;
		earthShadowPixelX = cosTheta * angularSeparation * pixelsPerAngularRadian;
		moonPixelY = 0;
		earthShadowPixelY = - sinTheta * angularSeparation * pixelsPerAngularRadian;  // The minus sign comes from the view coordinate system
	    }
	    
	    // Draw (and fill) Earth shadow outline first, so it will darken the logo and be obvious outside the boundary of the Moon
	    double earthShadowPixelRadiusNow = pixelsPerAngularRadian * earthShadowAngularRadiusNow;
	    [[UIColor colorWithRed:0 green:0 blue:0 alpha:0.8] setFill];
	    [[UIColor colorWithRed:1 green:1 blue:1 alpha:0.15] setStroke];
	    CGContextAddEllipseInRect(context, CGRectMake(earthShadowPixelX - earthShadowPixelRadiusNow, earthShadowPixelY - earthShadowPixelRadiusNow,
							  earthShadowPixelRadiusNow * 2, earthShadowPixelRadiusNow * 2));
	    CGContextDrawPath(context, kCGPathFillStroke);
	    //printf("Filling earthShadow in rect %.2f %.2f %.2f %.2f\n", earthShadowPixelX - earthShadowPixelRadiusNow, earthShadowPixelY - earthShadowPixelRadiusNow,
	    //   earthShadowPixelRadiusNow*2, earthShadowPixelRadiusNow*2);

	    // Now draw the Moon
	    // rotate to correct relative position vs the local horizon
	    // To draw in correct orientation, first translate to proper position, then rotate, then draw at 0,0
	    CGContextSaveGState(context);
	    CGContextTranslateCTM(context, moonPixelX, moonPixelY);
	    CGContextRotateCTM(context, astro->moonRelativeAngle());
	    [moonImage drawInRect:CGRectMake(-moonPixelRadiusNow,    -moonPixelRadiusNow,
					      moonPixelRadiusNow * 2, moonPixelRadiusNow * 2)];
	    //printf("Drawing moon in rect %.2f %.2f %.2f %.2f\n", moonPixelX - moonPixelRadiusNow, moonPixelY - moonPixelRadiusNow,
	    //   moonPixelRadiusNow*2, moonPixelRadiusNow*2);
	    CGContextRestoreGState(context);

	    // Then cover with the earthShadow image, but clipped to the Moon itself (to avoid oddity/bug in multiply blend mode when over black area)
	    CGContextSaveGState(context);
	    CGContextAddEllipseInRect(context, CGRectMake(moonPixelX - moonPixelRadiusNow, moonPixelY - moonPixelRadiusNow,
							  moonPixelRadiusNow * 2, moonPixelRadiusNow * 2));
	    CGContextClip(context);

	    earthShadowPixelRadiusNow = pixelsPerAngularRadian * earthShadowAngularRadiusNow / earthShadowRadiusFraction;
	    //printf("earthShadowPixelRadiusNow = %.2f\n", earthShadowPixelRadiusNow);
	    //CGContextSetBlendMode(context, kCGBlendModeMultiply);
	    [earthShadowImage drawInRect:CGRectMake(earthShadowPixelX - earthShadowPixelRadiusNow, earthShadowPixelY - earthShadowPixelRadiusNow,
						    earthShadowPixelRadiusNow * 2, earthShadowPixelRadiusNow * 2)
			       blendMode:kCGBlendModeMultiply
				   alpha:1.0];
	    //CGContextSetBlendMode(context, kCGBlendModeNormal);

	    double distanceToMoonCenter = sqrt(moonPixelX * moonPixelX + moonPixelY * moonPixelY);
	    double distanceToEarthShadowCenter = sqrt(earthShadowPixelX * earthShadowPixelX + earthShadowPixelY * earthShadowPixelY);
	    drawingSomething = distanceToMoonCenter - moonPixelRadiusNow < w/2 || distanceToEarthShadowCenter - earthShadowPixelRadiusNow < w/2;
	    CGContextRestoreGState(context);
	}
	if (drawingSomething && horizonPixelY > -h/2) {
	    if (horizonPixelY > h/2) {
		horizonPixelY = h/2;
	    }
	    //printf("w = %.2f, h = %.2f, hPY = %.2f\n", w, h, horizonPixelY);
	    [[UIColor colorWithRed:0 green:0.3 blue:0 alpha:0.5] setFill];
	    CGContextFillRect(context, CGRectMake(-w/2, -horizonPixelY, w, h));  // flipped signs come from the view coordinate system
	    if (horizonPixelY > 0) {
		[statusLabel setHidden:true];
		[horizonLabel setHidden:false];
	    } else {
		[statusLabel setHidden:false];
		[horizonLabel setHidden:true];
	    }
	} else {
	    [statusLabel setHidden:false];
	    [horizonLabel setHidden:true];
	}
    } else {  // We aren't drawing anything
	[statusLabel setHidden:false];
	[horizonLabel setHidden:true];
    }

    astro->cleanupLocalEnvironmentForThreadFromActionButton(false);
    CGContextRestoreGState(context);
#endif
}

@end
