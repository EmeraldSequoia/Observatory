//
//  EOSaturnRenderer.cpp
//  Emerald Observatory
//
//  See EOSaturnRenderer.hpp.
//
//  Geometry is in units of Saturn's equatorial radius, in a frame fixed to the ring plane:
//  z is Saturn's north pole, x points at the Earth's Saturnicentric longitude, y is 90 degrees
//  prograde from x.  The viewer looks along -e, e = (cos B, 0, sin B), with north up, so
//  screen right is +y and screen up is u = (-sin B, 0, cos B).
//
//  Shading uses I/F-style reflectances: a Minnaert law for the globe and a single-scattering
//  slab (Lommel-Seeliger) for the rings, lit face or (when the Sun and Earth are on opposite
//  sides of the ring plane) diffusely transmitted light from the unlit face.
//

#include "EOSaturnRenderer.hpp"

#include <math.h>
#include <string.h>

static const double kmPerRadius = 60268;               // equatorial radius (1 bar)
static const double polarRadius = 54364 / kmPerRadius;  // oblateness 0.098

const double EOSaturnRingOuterRadius = 136770 / kmPerRadius;  // outer edge of the A ring

// ---- colour helpers ------------------------------------------------------------------------

struct Rgb {
    double r, g, b;
};

static double srgbToLinear(double c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

static double linearToSrgb(double c) {
    if (c <= 0) {
        return 0;
    }
    if (c >= 1) {
        return 1;
    }
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055;
}

static Rgb linearFrom255(double r, double g, double b) {
    Rgb c = { srgbToLinear(r / 255), srgbToLinear(g / 255), srgbToLinear(b / 255) };
    return c;
}

// ---- rings -----------------------------------------------------------------------------------

// Normal optical depth and reflectance (sRGB 0-255) by radius in km.  Values between rows are
// interpolated linearly; repeated radii make sharp edges.  Radii from the Cassini-era ring
// boundaries (C ring inner edge to A ring outer edge); optical depths are representative of the
// Voyager and Cassini occultation profiles, smoothed to what a telescope can resolve.
struct RingRow {
    double km, tau, r, g, b;
};

static const RingRow ringTable[] = {
    {  74490, 0.00, 150, 146, 142 },
    {  74490, 0.06, 150, 146, 142 },  // C ring
    {  84000, 0.08, 155, 150, 145 },
    {  90000, 0.12, 165, 158, 150 },
    {  91980, 0.15, 170, 162, 152 },
    {  91980, 1.00, 215, 203, 178 },  // B ring: B1
    {  99000, 1.60, 230, 216, 188 },
    { 100000, 2.20, 240, 226, 196 },  // B2-B4: the brightest, most opaque part
    { 110000, 3.00, 245, 231, 201 },
    { 115000, 2.50, 240, 226, 197 },
    { 117500, 2.00, 235, 221, 193 },
    { 117500, 0.00, 150, 145, 140 },  // Huygens gap
    { 117930, 0.00, 150, 145, 140 },
    { 117930, 0.12, 150, 145, 140 },  // Cassini division
    { 121000, 0.12, 155, 150, 144 },
    { 122050, 0.20, 165, 158, 150 },
    { 122050, 0.50, 212, 202, 182 },  // A ring
    { 128000, 0.60, 216, 206, 186 },
    { 133423, 0.50, 212, 202, 182 },
    { 133423, 0.00, 212, 202, 182 },  // Encke gap
    { 133745, 0.00, 212, 202, 182 },
    { 133745, 0.45, 208, 198, 179 },
    { 136770, 0.40, 205, 195, 176 },
    { 136770, 0.00, 205, 195, 176 },
};
static const int ringRows = sizeof(ringTable) / sizeof(ringTable[0]);

// Returns the optical depth at radius rho (equatorial radii) and fills albedo (linear).
static double ringAt(double rho, Rgb *albedo) {
    double km = rho * kmPerRadius;
    if (km <= ringTable[0].km || km >= ringTable[ringRows - 1].km) {
        return 0;
    }
    for (int i = 1; i < ringRows; i++) {
        const RingRow &hi = ringTable[i];
        if (km < hi.km) {
            const RingRow &lo = ringTable[i - 1];
            double f = (km - lo.km) / (hi.km - lo.km);
            if (albedo) {
                *albedo = linearFrom255(lo.r + f * (hi.r - lo.r), lo.g + f * (hi.g - lo.g), lo.b + f * (hi.b - lo.b));
            }
            return lo.tau + f * (hi.tau - lo.tau);
        }
    }
    return 0;
}

// ---- globe -----------------------------------------------------------------------------------

// Reflectance by planetographic latitude (degrees, absolute): a cream equatorial zone, tan belts,
// paler temperate zones and grey-blue polar regions, as in Hubble's colour views.
struct BandRow {
    double lat, r, g, b;
};

static const BandRow bandTable[] = {
    {  0, 236, 216, 168 },
    {  7, 240, 221, 174 },
    { 13, 214, 182, 128 },
    { 19, 196, 156, 104 },
    { 25, 208, 172, 120 },
    { 31, 228, 204, 156 },
    { 38, 206, 178, 130 },
    { 45, 218, 196, 150 },
    { 55, 194, 174, 138 },
    { 65, 168, 162, 146 },
    { 78, 144, 148, 152 },
    { 90, 128, 134, 144 },
};
static const int bandRows = sizeof(bandTable) / sizeof(bandTable[0]);

static Rgb globeAlbedo(double latitudeDegrees) {
    double lat = fabs(latitudeDegrees);
    for (int i = 1; i < bandRows; i++) {
        if (lat <= bandTable[i].lat) {
            const BandRow &lo = bandTable[i - 1];
            const BandRow &hi = bandTable[i];
            double f = (lat - lo.lat) / (hi.lat - lo.lat);
            // Smoothstep so the bands blend as they do at telescope resolution
            f = f * f * (3 - 2 * f);
            return linearFrom255(lo.r + f * (hi.r - lo.r), lo.g + f * (hi.g - lo.g), lo.b + f * (hi.b - lo.b));
        }
    }
    const BandRow &last = bandTable[bandRows - 1];
    return linearFrom255(last.r, last.g, last.b);
}

static const double minnaertK = 0.9;

// Intersections of the line o + t d with the globe: tNear is the larger t, tFar the smaller.
// Returns false on a miss.
static bool hitGlobe(const double o[3], const double d[3], double *tNear, double *tFar) {
    double c2 = polarRadius * polarRadius;
    double a = d[0] * d[0] + d[1] * d[1] + d[2] * d[2] / c2;
    double b = 2 * (o[0] * d[0] + o[1] * d[1] + o[2] * d[2] / c2);
    double c = o[0] * o[0] + o[1] * o[1] + o[2] * o[2] / c2 - 1;
    double disc = b * b - 4 * a * c;
    if (disc <= 0) {
        return false;
    }
    double s = sqrt(disc);
    if (tNear) {
        *tNear = (-b + s) / (2 * a);
    }
    if (tFar) {
        *tFar = (-b - s) / (2 * a);
    }
    return true;
}

// ---- the renderer ----------------------------------------------------------------------------

struct Scene {
    double sinB, cosB;
    double e[3];  // toward the Earth
    double s[3];  // toward the Sun
    double mu;    // |sin B|
    double mu0;   // |sin B'|
    bool litFace;
};

// Fraction of sunlight reaching a point on the ring plane past the globe
static double ringSunlight(const Scene &sc, double x, double y) {
    double o[3] = { x, y, 0 };
    double tNear, tFar;
    if (hitGlobe(o, sc.s, &tNear, &tFar) && tNear > 0) {
        return 0;
    }
    return 1;
}

// Light leaving the ring toward the Earth (I/F), for optical depth tau and albedo
static Rgb ringRadiance(const Scene &sc, double tau, const Rgb &albedo, double sunlight) {
    Rgb out = { 0, 0, 0 };
    if (tau <= 0 || sc.mu0 < 1e-6 || sunlight <= 0) {
        return out;
    }
    double mu = sc.mu;
    double mu0 = sc.mu0;
    double shape;
    if (sc.litFace) {
        shape = 2 * mu0 / (mu + mu0) * (1 - exp(-tau * (1 / mu + 1 / mu0)));
    } else {
        // Diffuse transmission through the slab; ring particles scatter forward far less than
        // they scatter back, hence the 0.3
        if (fabs(mu0 - mu) < 1e-6) {
            shape = 2 * 0.3 * (tau / mu) * exp(-tau / mu);
        } else {
            shape = 2 * 0.3 * mu0 / (mu0 - mu) * (exp(-tau / mu0) - exp(-tau / mu));
        }
    }
    shape *= sunlight;
    out.r = albedo.r * shape;
    out.g = albedo.g * shape;
    out.b = albedo.b * shape;
    return out;
}

// Light leaving the globe at point p toward the Earth (I/F)
static Rgb globeRadiance(const Scene &sc, const double p[3]) {
    Rgb out = { 0, 0, 0 };
    double c2 = polarRadius * polarRadius;
    double n[3] = { p[0], p[1], p[2] / c2 };
    double len = sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
    n[0] /= len;
    n[1] /= len;
    n[2] /= len;
    double mu = n[0] * sc.e[0] + n[1] * sc.e[1] + n[2] * sc.e[2];
    double mu0 = n[0] * sc.s[0] + n[1] * sc.s[1] + n[2] * sc.s[2];
    if (mu0 <= 0 || mu <= 0) {
        return out;
    }
    // The rings' shadow: follow the ray toward the Sun to the ring plane
    double transmit = 1;
    if (fabs(sc.s[2]) > 1e-9) {
        double k = -p[2] / sc.s[2];
        if (k > 0) {
            double x = p[0] + k * sc.s[0];
            double y = p[1] + k * sc.s[1];
            double tau = ringAt(sqrt(x * x + y * y), NULL);
            if (tau > 0) {
                transmit = exp(-tau / sc.mu0);
            }
        }
    } else if (fabs(p[2]) < 1e-3) {
        transmit = 0;  // Sun exactly in the ring plane: the rings' edge shades the equator
    }
    double latitude = asin(n[2]) * 180 / M_PI;
    Rgb albedo = globeAlbedo(latitude);
    double law = pow(mu0, minnaertK) * pow(mu, minnaertK - 1) * transmit;
    out.r = albedo.r * law;
    out.g = albedo.g * law;
    out.b = albedo.b * law;
    return out;
}

// Premultiplied linear colour and alpha for one ray through screen point (X right, Y up)
static void shade(const Scene &sc, double X, double Y, double out[4]) {
    // The line of sight through screen point (X, Y): o + t e, where o is on the plane through
    // Saturn's centre facing the viewer and larger t is nearer the viewer
    double o[3] = { -Y * sc.sinB, X, Y * sc.cosB };

    double globeT = -INFINITY;
    double tNear, tFar;
    bool globe = hitGlobe(o, sc.e, &tNear, &tFar);
    if (globe) {
        globeT = tNear;
    }

    double ringT = -INFINITY;
    double ringX = 0, ringY = 0, tau = 0;
    Rgb albedo = { 0, 0, 0 };
    if (sc.mu > 1e-6) {
        ringT = -o[2] / sc.e[2];
        ringX = o[0] + ringT * sc.e[0];
        ringY = o[1] + ringT * sc.e[1];
        tau = ringAt(sqrt(ringX * ringX + ringY * ringY), &albedo);
    }

    double behind[4] = { 0, 0, 0, 0 };
    if (globe) {
        double p[3] = { o[0] + globeT * sc.e[0], o[1] + globeT * sc.e[1], o[2] + globeT * sc.e[2] };
        Rgb g = globeRadiance(sc, p);
        behind[0] = g.r;
        behind[1] = g.g;
        behind[2] = g.b;
        behind[3] = 1;
    }
    if (tau > 0 && ringT > globeT) {
        Rgb rr = ringRadiance(sc, tau, albedo, ringSunlight(sc, ringX, ringY));
        double t = exp(-tau / sc.mu);
        out[0] = rr.r + t * behind[0];
        out[1] = rr.g + t * behind[1];
        out[2] = rr.b + t * behind[2];
        out[3] = 1 - t * (1 - behind[3]);
    } else {
        memcpy(out, behind, sizeof(behind));
    }
}

void EOSaturnRender(double earthTilt, double sunTilt, double deltaU,
                    int width, int height, double pixelsPerEquatorialRadius,
                    uint8_t *rgba) {
    Scene sc;
    sc.sinB = sin(earthTilt);
    sc.cosB = cos(earthTilt);
    sc.e[0] = sc.cosB;
    sc.e[1] = 0;
    sc.e[2] = sc.sinB;
    sc.s[0] = cos(sunTilt) * cos(deltaU);
    sc.s[1] = cos(sunTilt) * sin(deltaU);
    sc.s[2] = sin(sunTilt);
    sc.mu = fabs(sc.sinB);
    sc.mu0 = fabs(sc.s[2]);
    sc.litFace = (sc.sinB >= 0) == (sc.s[2] >= 0);

    const int n = 4;  // n x n samples per pixel
    double cx = width / 2.0;
    double cy = height / 2.0;
    for (int py = 0; py < height; py++) {
        for (int px = 0; px < width; px++) {
            double acc[4] = { 0, 0, 0, 0 };
            for (int sy = 0; sy < n; sy++) {
                for (int sx = 0; sx < n; sx++) {
                    double X = (px + (sx + 0.5) / n - cx) / pixelsPerEquatorialRadius;
                    double Y = (cy - (py + (sy + 0.5) / n)) / pixelsPerEquatorialRadius;
                    double c[4];
                    shade(sc, X, Y, c);
                    acc[0] += c[0];
                    acc[1] += c[1];
                    acc[2] += c[2];
                    acc[3] += c[3];
                }
            }
            double a = acc[3] / (n * n);
            uint8_t *dst = rgba + 4 * (py * width + px);
            if (a <= 0) {
                dst[0] = dst[1] = dst[2] = dst[3] = 0;
                continue;
            }
            // Un-premultiply, encode, premultiply again in the encoded space CoreGraphics expects
            double inv = 1 / acc[3];
            dst[0] = (uint8_t)lround(255 * a * linearToSrgb(acc[0] * inv));
            dst[1] = (uint8_t)lround(255 * a * linearToSrgb(acc[1] * inv));
            dst[2] = (uint8_t)lround(255 * a * linearToSrgb(acc[2] * inv));
            dst[3] = (uint8_t)lround(255 * (a > 1 ? 1 : a));
        }
    }
}
