"""Draws the scene wheel textures into Media/ as 32 bit TGA files.

Run from the addon folder after changing a colour or size:
    python tools/make_textures.py

Pure Python, no image library needed. The ring has 8 segments with slot 1
centred at the top, matching L.Wheel.Pick.
"""
import math
import os
import struct

SIZE = 256
CENTRE = (SIZE - 1) / 2
OUTER = 126
INNER = 56
SLOTS = 8
HALF_SLOT = math.pi / SLOTS

FILL = (14, 13, 20, 200)
EDGE = (201, 162, 79, 255)
DIVIDER = (201, 162, 79, 140)
GLOW = (255, 210, 90, 120)


def coverage(distance, edge, soft=1.0):
    """1 inside the edge, 0 outside, with a soft pixel wide falloff."""
    return max(0.0, min(1.0, (edge - distance) / soft + 0.5))


def over(base, colour, amount):
    """Paints colour over base with the given strength, both RGBA tuples."""
    alpha = colour[3] / 255 * amount
    out_alpha = alpha + base[3] / 255 * (1 - alpha)
    if out_alpha == 0:
        return (0, 0, 0, 0)
    rgb = [
        (colour[i] * alpha + base[i] * base[3] / 255 * (1 - alpha)) / out_alpha
        for i in range(3)
    ]
    return (*[round(c) for c in rgb], round(out_alpha * 255))


def angle_from_top(x, y):
    """Clockwise angle from straight up, in radians, for a pixel."""
    return math.atan2(x - CENTRE, CENTRE - y) % (2 * math.pi)


def ring_pixel(x, y):
    d = math.hypot(x - CENTRE, y - CENTRE)
    inside = coverage(d, OUTER) * (1 - coverage(d, INNER))
    pixel = over((0, 0, 0, 0), FILL, inside)

    # Gold rims on the outer and inner edges.
    pixel = over(pixel, EDGE, max(0.0, 1 - abs(d - OUTER + 1.5) / 1.5))
    pixel = over(pixel, EDGE, max(0.0, 1 - abs(d - INNER - 1.5) / 1.5))

    # Dividers between slots, half a slot either side of each slot's centre.
    angle = angle_from_top(x, y) + HALF_SLOT
    step = 2 * math.pi / SLOTS
    off = abs((angle % step) - 0)
    off = min(off, step - off)
    gap = off * d
    pixel = over(pixel, DIVIDER, inside * max(0.0, 1 - gap / 1.2))
    return pixel


def wedge_pixel(x, y):
    """The highlight for slot 1; the addon rotates it to the others."""
    d = math.hypot(x - CENTRE, y - CENTRE)
    inside = coverage(d, OUTER - 2) * (1 - coverage(d, INNER + 2))
    angle = angle_from_top(x, y)
    angle = min(angle, 2 * math.pi - angle)
    across = coverage(angle * d, HALF_SLOT * d - 1.5, 2.0)
    return over((0, 0, 0, 0), GLOW, inside * across)


def write_tga(path, pixel):
    # Type 2 (uncompressed true colour), 32 bits, top left origin, 8 alpha bits.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    body = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = pixel(x, y)
            body += bytes((b, g, r, a))
    with open(path, "wb") as f:
        f.write(header + body)


if __name__ == "__main__":
    media = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Media")
    os.makedirs(media, exist_ok=True)
    write_tga(os.path.join(media, "wheel_ring.tga"), ring_pixel)
    write_tga(os.path.join(media, "wheel_glow.tga"), wedge_pixel)
    print("wrote", media)
