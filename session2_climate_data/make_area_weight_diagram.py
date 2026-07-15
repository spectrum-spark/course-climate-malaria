#!/usr/bin/env python3
"""
Regenerate the second globe diagram in Session 2, Part 3, inside the callout
"Technical note: Why cos of latitude is the exact area weight" (the one showing a
grid cell bounded by two meridians and two circles of latitude).

That SVG is point-sampled from an orthographic projection of a tilted globe, so it is
NOT meant to be hand-edited. To change it, edit the parameters below, re-run, and paste
the printed <svg>...</svg> back into session2_climate_data.qmd (replacing the existing
one inside the ```{=html} block).

    python3 make_area_weight_diagram.py
        -> writes area_weight_diagram.svg next to this script; open that file and copy
           the <svg>...</svg> into session2_climate_data.qmd (replacing the existing one).

The first diagram in that callout (the R cos theta cross-section) is small and
hand-written directly in the .qmd, so it is not produced here.

Requires: numpy.
"""
import os
import numpy as np

# --- geometry / layout (SVG user units) --------------------------------------
R, CX, CY = 105, 205, 158        # sphere radius and centre
TILT      = np.deg2rad(25)       # globe tilt towards the viewer
TH1, TH2  = 15, 48               # cell latitudes, degrees (theta_1, theta_2)
LAM_W     = 32                   # half the cell's longitude span, degrees (Delta lambda / 2)

# colours
C_OUTLINE, C_EQUATOR, C_LAT, C_MERID, C_CELL, C_ACCENT = (
    "#274b6d", "#9bb0c4", "#6b8cae", "#274b6d", "#f6cccc", "#b2182b")


def proj(th_deg, lam_deg):
    """Orthographic projection of (latitude, longitude) -> (x, y, is_front)."""
    th, lam = np.deg2rad(th_deg), np.deg2rad(lam_deg)
    x = np.cos(th) * np.sin(lam)
    y = np.sin(th)
    z = np.cos(th) * np.cos(lam)
    yp = y * np.cos(TILT) - z * np.sin(TILT)
    zp = y * np.sin(TILT) + z * np.cos(TILT)   # >0 on the near (visible) face
    return CX + R * x, CY - R * yp, zp > 0


def curve(points, col, w):
    """Draw a projected curve, solid on the near face and dashed on the far face."""
    segs, cur, front = [], [], None
    for x, y, f in points:
        if front is None:
            front = f
        if f != front:
            segs.append((front, cur)); cur = [(x, y, f)]; front = f
        else:
            cur.append((x, y, f))
    segs.append((front, cur))
    s = ""
    for fr, seg in segs:
        if len(seg) < 2:
            continue
        d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y, _ in seg)
        dash = "" if fr else ' stroke-dasharray="2 3" opacity="0.5"'
        s += f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}"{dash}/>'
    return s


def latitude_circle(th, col, w):
    return curve([proj(th, lam) for lam in np.linspace(0, 360, 145)], col, w)


def meridian(lam, col, w):
    return curve([proj(th, lam) for th in np.linspace(-90, 90, 121)], col, w)


svg = []
svg.append(
    '<svg viewBox="0 0 430 320" width="100%" '
    'style="max-width:430px;height:auto;display:block;margin:0.6rem auto" '
    'xmlns="http://www.w3.org/2000/svg" role="img" '
    'aria-label="A globe with two meridians running pole to pole that bound a '
    'highlighted grid cell between latitudes theta-one and theta-two spanning '
    'delta-lambda in longitude.">')
svg.append(f'<circle cx="{CX}" cy="{CY}" r="{R}" fill="#eaf2fb" '
           f'stroke="{C_OUTLINE}" stroke-width="1.5"/>')
svg.append(latitude_circle(0,   C_EQUATOR, 1))     # equator
svg.append(latitude_circle(TH1, C_LAT, 1.2))
svg.append(latitude_circle(TH2, C_LAT, 1.2))
svg.append(meridian(-LAM_W, C_MERID, 1.4))
svg.append(meridian( LAM_W, C_MERID, 1.4))

# cell fill: the near-face patch bounded by the two latitudes and two meridians
bnd  = [proj(TH1, lam) for lam in np.linspace(-LAM_W, LAM_W, 30)]
bnd += [proj(th, LAM_W) for th in np.linspace(TH1, TH2, 20)]
bnd += [proj(TH2, lam) for lam in np.linspace(LAM_W, -LAM_W, 30)]
bnd += [proj(th, -LAM_W) for th in np.linspace(TH2, TH1, 20)]
d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y, _ in bnd) + " Z"
svg.append(f'<path d="{d}" fill="{C_CELL}" fill-opacity="0.8" '
           f'stroke="{C_ACCENT}" stroke-width="1.8"/>')

# pole marker + label
px, py, _ = proj(90, 0)
svg.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="2.4" fill="{C_OUTLINE}"/>')
svg.append(f'<text x="{px:.1f}" y="{py-10:.1f}" text-anchor="middle" '
           f'font-size="11" fill="{C_OUTLINE}">pole</text>')

# theta_1, theta_2 labels (to the left of each latitude circle)
lx1, ly1, _ = proj(TH1, -90); lx2, ly2, _ = proj(TH2, -90)
svg.append(f'<text x="{lx1-6:.1f}" y="{ly1+4:.1f}" text-anchor="end" font-size="12" '
           f'fill="{C_OUTLINE}" font-style="italic">&#952;&#8321;</text>')
svg.append(f'<text x="{lx2-6:.1f}" y="{ly2+4:.1f}" text-anchor="end" font-size="12" '
           f'fill="{C_OUTLINE}" font-style="italic">&#952;&#8322;</text>')

# Delta lambda span across the top of the cell
tx1, ty1, _ = proj(TH2, -LAM_W); tx2, ty2, _ = proj(TH2, LAM_W)
my = min(ty1, ty2) - 8
svg.append(f'<line x1="{tx1:.1f}" y1="{my:.1f}" x2="{tx2:.1f}" y2="{my:.1f}" '
           f'stroke="{C_ACCENT}" stroke-width="1.2"/>')
svg.append(f'<text x="{(tx1+tx2)/2:.1f}" y="{my-4:.1f}" text-anchor="middle" '
           f'font-size="12" fill="{C_ACCENT}">&#916;&#955;</text>')

# area A label
ax, ay, _ = proj((TH1 + TH2) / 2, 0)
svg.append(f'<text x="{ax:.1f}" y="{ay+4:.1f}" text-anchor="middle" '
           f'font-size="12" fill="{C_ACCENT}">area A</text>')
svg.append('</svg>')

svg_text = "\n".join(svg)
out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "area_weight_diagram.svg")
with open(out_path, "w") as fh:
    fh.write(svg_text + "\n")
print("Wrote", out_path)
print("Copy the <svg>...</svg> from that file into the 'Why cos of latitude is the "
      "exact area weight' callout in session2_climate_data.qmd (the second diagram).")
