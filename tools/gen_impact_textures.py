"""Generates the card-impact FX textures (dust, spark, mote, ring, flash) procedurally.

Usage: python tools/gen_impact_textures.py   (needs Pillow + numpy; nothing external is used)
Output: assets/ui/fx/impact/*.png, true RGBA with transparent borders. Deterministic (fixed seeds).
"""
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "fx", "impact")
os.makedirs(OUT, exist_ok=True)


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def noise(rng, size, cells):
    """Smooth value noise in 0..1 (bicubic-upscaled random grid)."""
    g = (rng.random((cells, cells)) * 255).astype(np.uint8)
    img = Image.fromarray(g).resize((size, size), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def fbm(rng, size):
    n = 0.5 * noise(rng, size, 4) + 0.3 * noise(rng, size, 8) + 0.2 * noise(rng, size, 16)
    return n


def grid(size):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2.0
    return (x - c) / c, (y - c) / c


def save(name, rgb, alpha):
    a = np.clip(alpha, 0, 1)
    out = np.zeros(a.shape + (4,), dtype=np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = (a * 255).astype(np.uint8)
    out[a <= 0.0, :3] = out[..., :3][a > 0].mean(axis=0).astype(np.uint8) if (a > 0).any() else 0
    Image.fromarray(out, "RGBA").save(os.path.join(OUT, name))


def dust(seed, size=128):
    rng = np.random.default_rng(seed)
    x, y = grid(size)
    # A cloud = several overlapping soft lobes, eroded by noise, so no two read as a circle.
    field = np.zeros((size, size), np.float32)
    for _ in range(int(rng.integers(4, 7))):
        cx, cy = rng.uniform(-0.42, 0.42), rng.uniform(-0.28, 0.28)
        r = rng.uniform(0.4, 0.62)
        d = np.sqrt((x - cx) ** 2 + ((y - cy) * 1.15) ** 2) / r
        field = np.maximum(field, 1.0 - smooth(d, 0.25, 1.0))
    n = fbm(rng, size)
    field = np.clip(field * (0.55 + 0.9 * n) - 0.06 * (1 - n), 0, 1)
    img = Image.fromarray((field * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4.0))
    field = np.asarray(img, np.float32) / 255.0
    r = np.sqrt(x * x + y * y)
    field *= 1.0 - smooth(r, 0.78, 0.98)  # guaranteed transparent border
    alpha = np.clip(field * 1.3, 0, 1) ** 1.3 * 0.85
    shade = fbm(rng, size)
    base = np.array([238, 220, 190], np.float32)
    dark = np.array([178, 146, 108], np.float32)
    t = np.clip(0.2 + 0.9 * (shade - 0.35) + 0.25 * (y * 0.5 + 0.5), 0, 1)[..., None]
    rgb = base * (1 - t) + dark * t
    save("dust_%d.png" % seed, rgb, alpha)


def spark(size=64):
    x, y = grid(size)
    # Horizontal streak, bright core, tapered ends; rotated by the particle system.
    ax = np.abs(x)
    body = (1 - smooth(ax, 0.0, 0.98)) ** 1.6
    width = 0.07 + 0.05 * (1 - ax)
    core = np.exp(-(y / width) ** 2)
    a = body * core
    rgb = np.empty((size, size, 3), np.float32)
    k = np.clip(core * body * 1.4, 0, 1)[..., None]
    rgb[:] = np.array([255, 235, 150], np.float32) * (1 - k) + np.array([255, 255, 245], np.float32) * k
    # Vertical streak: the particles align their Y axis with the velocity.
    save("spark.png", rgb.transpose(1, 0, 2), a.T)


def mote(size=64):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    a = np.exp(-(r * 3.0) ** 2) * 0.9 + np.exp(-(r * 1.5) ** 2) * 0.25
    a *= 1 - smooth(r, 0.8, 0.98)
    rgb = np.empty((size, size, 3), np.float32)
    k = np.clip(np.exp(-(r * 4.0) ** 2), 0, 1)[..., None]
    rgb[:] = np.array([255, 240, 160], np.float32) * (1 - k) + np.array([255, 255, 255], np.float32) * k
    save("mote.png", rgb, a)


def glow(size=128):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    a = (np.exp(-(r * 1.9) ** 2) * 0.8 + np.exp(-(r * 3.5) ** 2) * 0.35) * (1 - smooth(r, 0.7, 0.99))
    rgb = np.full((size, size, 3), 255, np.float32)
    save("glow.png", rgb, a)


def rim(size=128):
    """Soft outline of a rounded square (half-extent 0.8 of the texture): glow that hugs a card edge."""
    x, y = grid(size)
    h, rad = 0.8, 0.14
    qx = np.abs(x) - (h - rad)
    qy = np.abs(y) - (h - rad)
    d = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - rad
    a = np.exp(-(d / 0.05) ** 2) * (1 - smooth(np.sqrt(x * x + y * y), 1.05, 1.4))
    rgb = np.full((size, size, 3), 255, np.float32)
    save("rim.png", rgb, a)


def ring(size=128):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    a = np.exp(-((r - 0.72) / 0.17) ** 2) * (1 - smooth(r, 0.88, 0.99)) * 0.8  # wide, feathered: no crisp line
    rng = np.random.default_rng(7)
    a *= 0.75 + 0.25 * fbm(rng, size)  # slightly uneven so it is not a perfect vector line
    rgb = np.empty((size, size, 3), np.float32)
    rgb[:] = np.array([200, 255, 170], np.float32)
    save("ring.png", rgb, a)


def flash(size=128):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    rays = 0.65 + 0.35 * np.cos(ang * 6.0 + 0.4) ** 2
    a = (np.exp(-(r * 2.6) ** 2) * 0.95 + np.exp(-(r * 1.4) ** 2) * 0.35 * rays) * (1 - smooth(r, 0.85, 0.99))
    rgb = np.empty((size, size, 3), np.float32)
    k = np.clip(np.exp(-(r * 3.2) ** 2), 0, 1)[..., None]
    rgb[:] = np.array([255, 244, 170], np.float32) * (1 - k) + np.array([255, 255, 255], np.float32) * k
    save("flash.png", rgb, a)


if __name__ == "__main__":
    for s in (1, 2, 3, 4):
        dust(s)
    spark()
    mote()
    ring()
    flash()
    glow()
    rim()
    print("impact textures written to", os.path.normpath(OUT))
