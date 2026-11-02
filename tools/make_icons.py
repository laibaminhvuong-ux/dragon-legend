#!/usr/bin/env python3
"""Draws the placeholder app icon (an orange orb with a red star) as web/icons/icon-{192,512}.png.
Pure Python (zlib), no image library needed. Replace with real art whenever we have it."""
import math, os, struct, zlib

def star_inside(x, y, cx, cy, r_out, r_in, points=5):
    # point-in-polygon for a 5-point star, pointing up
    verts = []
    for i in range(points * 2):
        a = -math.pi / 2 + i * math.pi / points
        r = r_out if i % 2 == 0 else r_in
        verts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    inside = False
    j = len(verts) - 1
    for i in range(len(verts)):
        xi, yi = verts[i]; xj, yj = verts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside

def draw(size):
    rows = []
    c = size / 2; R = size * 0.46
    for py in range(size):
        row = bytearray([0])
        for px in range(size):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in (0.25, 0.75):
                for sx in (0.25, 0.75):
                    x, y = px + sx, py + sy
                    d = math.hypot(x - c, y - c) / R
                    if d > 1:
                        continue
                    # orb shading: light from top-left
                    lx, ly = (x - c) / R + 0.35, (y - c) / R + 0.4
                    light = max(0.0, 1 - math.hypot(lx, ly) * 0.75)
                    r, g, b = 0.93 + 0.07 * light, 0.45 + 0.35 * light, 0.05 + 0.15 * light
                    if star_inside(x, y, c, c + size * 0.02, size * 0.17, size * 0.07):
                        r, g, b = 0.85, 0.12, 0.08
                    spec = max(0.0, 1 - math.hypot((x - c) / R + 0.4, (y - c) / R + 0.45) * 4)
                    r, g, b = [min(1.0, v + spec * 0.8) for v in (r, g, b)]
                    edge = min(1.0, (1 - d) * R / 1.5)
                    for k, v in enumerate((r, g, b, 1.0)):
                        acc[k] += v * edge
            a = acc[3] / 4
            if a > 0:
                row += bytes([int(acc[0] / acc[3] * 255), int(acc[1] / acc[3] * 255), int(acc[2] / acc[3] * 255), int(a * 255)])
            else:
                row += b"\0\0\0\0"
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")

out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "web", "icons")
os.makedirs(out, exist_ok=True)
for s in (192, 512):
    open(os.path.join(out, f"icon-{s}.png"), "wb").write(draw(s))
print("icons written to", out)
