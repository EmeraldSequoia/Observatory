//
//  EOSaturnRenderer.hpp
//  Emerald Observatory
//
//  Draws Saturn and its rings as a telescope shows them on a given date: a ray-traced oblate globe
//  and ring plane, with the ring opening and lit face taken from Meeus chapter 45 with the IAU pole (esastro's
//  saturnRingGeometry), the globe's shadow on the rings, and the rings' shadow on the globe.
//
//  The view is the sky view, not inverted: Saturn's north is up and the planet's prograde
//  direction of rotation is to the right.  Plain C++ so it can be tested away from the app.
//

#ifndef _EOSATURNRENDERER_HPP_
#define _EOSATURNRENDERER_HPP_

#include <stdint.h>

// Fills rgba (width * height * 4 bytes, rows top to bottom) with premultiplied sRGB colour and alpha;
// the sky is transparent.  pixelsPerEquatorialRadius sets the size; Saturn is centred.
// earthTilt (B), sunTilt (B') and deltaU are in radians, as esastro's saturnRingGeometry returns them.
void EOSaturnRender(double earthTilt, double sunTilt, double deltaU,
                    int width, int height, double pixelsPerEquatorialRadius,
                    uint8_t *rgba);

// Ring outer edge, in equatorial radii of the globe: the width the drawing needs is twice this.
extern const double EOSaturnRingOuterRadius;

#endif // _EOSATURNRENDERER_HPP_
