#!/usr/bin/env python3
#
# Builds Resources/blueMarble/NN-large.jpg and night-large.jpg, the 8192x4096 Earth maps used by the location picker.
# The magnifier shows the map at 3x, so on a large iPad these are about one pixel per screen pixel there.
#
# Source: NASA Blue Marble Next Generation (public domain), 21600x10800 "world" images, one per month of 2004:
#   https://eoimages.gsfc.nasa.gov/images/imagerecords/<id/1000>000/<id>/world.2004MM.3x21600x10800.jpg
#   ids for months 1-12: 73938 73967 73992 74017 74042 74067 74092 74117 74142 74167 74192 74218
# The June "world" image is no longer online, so June uses the topo.bathy variant (id 73726,
# world.topo.bathy.200406.3x21600x10800.jpg) with July's ocean mask.
#
# The night side shows night-large.jpg, from NASA's "Earth's City Lights" (public domain, id 55167):
#   https://eoimages.gsfc.nasa.gov/images/imagerecords/55000/55167/land_ocean_ice_lights_8192.tif
#
# The original small maps (NN.png) paint the ocean (2,5,70); the NASA images have (2,5,20) for deep ocean and
# nearly black for shallow seas, so recolor anything that dark.
#
# Usage: makeLargeBlueMarble.py <dir with MM.src.jpg, 06.topobathy.jpg and night-src.tif> <output dir>
# Requires Pillow and numpy.

import os
import sys

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None  # the sources are 21600x10800
SRC, OUT = sys.argv[1], sys.argv[2]
W, H = 8192, 4096
NAVY = np.array([2, 5, 70], np.float32)

def load(path):
    # Shrunk before any arithmetic:  as floats, a full-size source would take gigabytes
    return np.asarray(Image.open(path).convert('RGB').resize((W, H), Image.LANCZOS), np.float32)

def ocean_weight(a):
    # Deep ocean is (2,5,20) and shallow seas are nearly black; treat anything that dark as ocean,
    # fading out between channel maxima of 24 and 36 (JPEG noise at coastlines)
    m = a.max(axis=2)
    return np.clip((36 - m) / 12, 0, 1)[..., None]

july_mask = ocean_weight(load(f'{SRC}/07.src.jpg'))
for month in range(1, 13):
    if month == 6:
        land = load(f'{SRC}/06.topobathy.jpg')
        w = july_mask
    else:
        land = load(f'{SRC}/{month:02d}.src.jpg')
        w = ocean_weight(land)
    out = land * (1 - w) + NAVY * w
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    path = f'{OUT}/{month:02d}-large.jpg'
    img.save(path, quality=65, optimize=True)
    print(path, os.path.getsize(path))

night = Image.open(f'{SRC}/night-src.tif').convert('RGB')  # already 8192x4096
path = f'{OUT}/night-large.jpg'
night.save(path, quality=65, optimize=True)
print(path, os.path.getsize(path))
