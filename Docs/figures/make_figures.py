#!/usr/bin/env python3
"""Generates the SVG figures for Docs/CloudXRViewer-Foveated-Theory-and-Code.md.

Dependency-free: plain Python writes the SVG. The models are the textbook ones quoted in the
document (§1), with the parameters stated there; they illustrate orders of magnitude and are not
measurements of Apple Vision Pro or of CloudXR.

    python3 Docs/figures/make_figures.py        # writes Docs/figures/*.svg, prints the table
"""

from __future__ import annotations

import math
from pathlib import Path

HERE = Path(__file__).resolve().parent

# ---------------------------------------------------------------- models (see §1 of the document)

OMEGA0 = 1 / 60  # foveal minimum angle of resolution, degrees (about 1 arcminute)
# MAR slope m, degrees per degree of eccentricity. Guenter et al. fitted 1.32-1.65 arcmin/degree
# (0.022-0.0275); 0.011 is an illustrative, conservative half of the lower value.
SLOPES = [0.011, 0.022, 0.0275]


def mar(e: float, m: float) -> float:
    """Linear minimum-angle-of-resolution model ω(e) = m·e + ω0 (Guenter et al. 2012)."""
    return m * e + OMEGA0


def relative_acuity(e: float, m: float) -> float:
    return OMEGA0 / mar(e, m)


def cortical_magnification(e: float) -> float:
    """Horton & Hoyt (1991): M(e) = 17.3 / (e + 0.75) mm of V1 per degree."""
    return 17.3 / (e + 0.75)


def sample_fraction(radius: float, m: float, ppd: float = 1 / OMEGA0, steps: int = 20000) -> float:
    """Samples needed by an ideal foveated image, as a fraction of a uniform one.

    The uniform image has `ppd` samples per degree everywhere, so over a disc of `radius` degrees
    around the gaze its count is ∝ π r² ppd². The foveated one needs only min(1/ω(e), ppd) samples
    per degree at eccentricity e, so its count is ∝ ∫ 2π e min(1/ω(e), ppd)² de.
    """
    de = radius / steps
    foveated = 0.0
    for i in range(steps):
        e = (i + 0.5) * de
        foveated += 2 * math.pi * e * min(1 / mar(e, m), ppd) ** 2 * de
    return foveated / (math.pi * radius**2 * ppd**2)


# ---------------------------------------------------------------- SVG helpers

W, H = 640, 330
LEFT, RIGHT, TOP, BOTTOM = 62, 20, 24, 50
COLORS = ["#2a6fb0", "#c2571a", "#2f8a4a"]


def axes(xmax: float, ymax: float, xlabel: str, ylabel: str, xticks, yticks, yfmt) -> tuple[list[str], callable]:
    pw, ph = W - LEFT - RIGHT, H - TOP - BOTTOM

    def pt(x: float, y: float) -> tuple[float, float]:
        return LEFT + x / xmax * pw, TOP + ph - y / ymax * ph

    out = [f'<rect x="{LEFT}" y="{TOP}" width="{pw}" height="{ph}" fill="none" stroke="#999"/>']
    for x in xticks:
        px, _ = pt(x, 0)
        out.append(f'<line x1="{px:.1f}" y1="{TOP}" x2="{px:.1f}" y2="{TOP + ph}" stroke="#eee"/>')
        out.append(f'<text x="{px:.1f}" y="{TOP + ph + 16}" text-anchor="middle">{x:g}</text>')
    for y in yticks:
        _, py = pt(0, y)
        out.append(f'<line x1="{LEFT}" y1="{py:.1f}" x2="{LEFT + pw}" y2="{py:.1f}" stroke="#eee"/>')
        out.append(f'<text x="{LEFT - 6}" y="{py + 4:.1f}" text-anchor="end">{yfmt(y)}</text>')
    out.append(f'<text x="{LEFT + pw / 2}" y="{H - 10}" text-anchor="middle">{xlabel}</text>')
    out.append(f'<text transform="translate(16 {TOP + ph / 2}) rotate(-90)" text-anchor="middle">{ylabel}</text>')
    return out, pt


def polyline(points, color: str, dash: str = "") -> str:
    d = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    extra = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="2"{extra}/>'


def legend(items, x: float, y: float) -> list[str]:
    out = []
    for i, (label, color, dash) in enumerate(items):
        yy = y + i * 18
        extra = f' stroke-dasharray="{dash}"' if dash else ""
        out.append(f'<line x1="{x}" y1="{yy}" x2="{x + 26}" y2="{yy}" stroke="{color}" stroke-width="2"{extra}/>')
        out.append(f'<text x="{x + 32}" y="{yy + 4}">{label}</text>')
    return out


def svg(body: list[str]) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
            'font-family="Helvetica, Arial, sans-serif" font-size="12" fill="#222">\n'
            '<rect width="100%" height="100%" fill="white"/>\n' + "\n".join(body) + "\n</svg>\n")


# ---------------------------------------------------------------- figures


def acuity_figure() -> str:
    emax = 40
    body, pt = axes(emax, 1.0, "eccentricity from the gaze direction (degrees)", "relative to the fovea",
                    range(0, emax + 1, 5), [0, 0.25, 0.5, 0.75, 1.0], lambda y: f"{y:g}")
    items = []
    for m, color in zip(SLOPES, COLORS):
        pts = [pt(e / 10, relative_acuity(e / 10, m)) for e in range(emax * 10 + 1)]
        body.append(polyline(pts, color))
        items.append((f"acuity ω0/ω(e), m = {m}", color, ""))
    m0 = cortical_magnification(0)
    pts = [pt(e / 10, cortical_magnification(e / 10) / m0) for e in range(emax * 10 + 1)]
    body.append(polyline(pts, "#666", "6 4"))
    items.append(("cortical magnification M(e)/M(0)", "#666", "6 4"))
    body += legend(items, 380, 60)
    return svg(body)


def samples_figure() -> str:
    rmax = 60
    ymax = 0.3
    body, pt = axes(rmax, ymax, "radius of the field around the gaze (degrees)",
                    "foveated / uniform samples", range(0, rmax + 1, 10),
                    [0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3], lambda y: f"{y:.0%}")
    items = []
    for m, color in zip(SLOPES, COLORS):
        pts = [pt(r / 2, min(sample_fraction(r / 2, m, steps=2000), ymax)) for r in range(4, 2 * rmax + 1)]
        body.append(polyline(pts, color))
        items.append((f"m = {m}, 60 samples/degree", color, ""))
    pts = [pt(r / 2, min(sample_fraction(r / 2, 0.022, 30, 2000), ymax)) for r in range(4, 2 * rmax + 1)]
    body.append(polyline(pts, COLORS[1], "6 4"))
    items.append(("m = 0.022, display limited to 30 samples/degree", COLORS[1], "6 4"))
    body += legend(items, 300, 60)
    return svg(body)


def main() -> None:
    (HERE / "acuity.svg").write_text(acuity_figure(), encoding="utf-8")
    (HERE / "samples.svg").write_text(samples_figure(), encoding="utf-8")
    print("relative acuity ω0/ω(e) for m = 0.022:")
    for e in [0, 1, 2, 5, 10, 20, 30]:
        print(f"  e = {e:>2}°: {relative_acuity(e, 0.022):.3f}")
    print("foveated / uniform samples:")
    for r in [10, 20, 30, 50]:
        row = "  ".join(f"m={m}: {sample_fraction(r, m):.4f}" for m in SLOPES)
        print(f"  r = {r:>2}°: {row}  (30 ppd, m=0.022: {sample_fraction(r, 0.022, 30):.4f})")


if __name__ == "__main__":
    main()
