#!/usr/bin/env python3
"""WCAG contrast audit for the Profile / Achievements color pairs."""
import math

def srgb_to_lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def lum(rgb):
    r, g, b = (srgb_to_lin(x) for x in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

night    = hexc('0B0A0E')
surface  = hexc('141419')
surfaceH = hexc('1E1D24')
ember    = hexc('2E2925')
bronze   = hexc('8A6E42')
gold     = hexc('D9B871')
goldSoft = hexc('F5E3B0')
goldDeep = hexc('6E5426')
silver   = hexc('C9C4B8')
textDim  = hexc('8F8A80')
success  = hexc('8FD09A')
danger   = hexc('D96A62')
ink      = hexc('241806')

# (label, foreground, background, context, font-size/weight, required ratio)
pairs = [
    # --- Profile screen ---
    ('coach name',            goldSoft, surface,  'profile identity header', '20 w900', 3.0),
    ('club name',             textDim, surface,   'profile identity header', '13 w600', 4.5),
    ('joined date',           textDim, surface,   'profile identity header', '11 w400', 4.5),
    ('stat value',            goldSoft, surface,  'profile stat tile',       '17 w900', 3.0),
    ('stat value accent',     success, surface,   'profile stat tile (wins)', '17 w900', 3.0),
    ('stat value accent dgr', danger,  surface,   'profile stat tile (losses)', '17 w900', 3.0),
    ('stat label',            textDim, surface,   'profile stat tile',        '10.5 w600', 4.5),
    ('silverware subtitle',   textDim, surface,   'profile silverware',      '11 w800', 4.5),
    ('division plate',        goldSoft, gold_blend := None or surface, 'on gold 10% tint over surface', '11 w800', 4.5),
    ('season row title',      goldSoft, surface,  'profile season history',  '13 w800', 4.5),
    ('season row position',   textDim, surface,   'profile season history',  '11 w400', 4.5),
    ('outcome promoted',      success, surface,   'profile season row',      '11 w800', 4.5),
    ('outcome relegated',     danger,  surface,   'profile season row',      '11 w800', 4.5),
    ('badge cell label',      goldSoft, surface,  'profile cabinet',         '9.5 w700', 4.5),
    ('badge cell progress',   textDim, surface,   'profile cabinet',         '9.5 w700', 4.5),
    ('title text',            goldSoft, surface,  'profile titles gallery',  '13 w800', 4.5),
    ('title source',          textDim, surface,   'profile titles gallery',  '10.5 w400', 4.5),
    # --- Achievements screen ---
    ('hub title',             goldSoft, surface,  'ach header',              '18 w900', 3.0),
    ('hub subtitle',          textDim, surface,   'ach header',              '12 w400', 4.5),
    ('ring %',                goldSoft, surface,  'ach completion ring',     '11 w900', 4.5),
    ('streak title',          hexc('FFFFFF'), surface, 'streak card', '15 w900', 4.5),
    ('streak claimed state',  textDim, surface,   'streak card resting',     '12 w800', 4.5),
    ('streak tomorrow pays',  goldSoft, surface,   'streak card resting',     '12 w800', 4.5),
    ('streak broken notice',  danger,  surface,   'streak card',             '11 w800', 4.5),
    ('streak weekly bonus',   textDim, surface,   'streak card footer',      '10.5 w700', 4.5),
    ('streak reset warning',  textDim, surface,   'streak card footer',      '10.5 w700', 4.5),
    ('pip day number',        gold,    surface,    'streak pip (today)',      '11 w900', 4.5),
    ('pip day dim',           textDim, surface,    'streak pip (future)',     '11 w900', 4.5),
    ('pip ink check',         ink,     gold,       'streak pip claimed',      'icon 16', 3.0),
    ('category subtitle',     textDim, surface,   'ach section header',      '11 w400', 4.5),
    ('ach title',             goldSoft, surface,   'ach card',                '14 w800', 4.5),
    ('ach description',       textDim, surface,   'ach card',                '11 w400', 4.5),
    ('progress readout',      textDim, surface,   'ach card progress',       '11 w700', 4.5),
    ('progress readout done', success, surface,   'ach card progress',       '11 w700', 4.5),
    ('claimed label',         success, surface,   'ach card right column',   '10 w800', 4.5),
    ('claimed rungs chip',    success, surface,   'ach card chip',           '10 w800', 4.5),
    # ink-on-gold pip icon (graphic) and other icon pairs: 3.0 (UI components)
]

# emulate the tinted plate: gold @10% alpha over surface
def over(fg, alpha, bg):
    return tuple(round(fg[i]*alpha + bg[i]*(1-alpha)) for i in range(3))

plate = over(gold, 0.10, surface)
pairs[8] = ('division plate', goldSoft, plate, 'on gold 10% tint over surface', '11 w800', 4.5)

print(f"{'pair':<24} {'ratio':>6}  {'need':>5}  verdict   context")
print('-' * 78)
fails = []
for label, fg, bg, ctx, size, need in pairs:
    r = contrast(fg, bg)
    ok = 'PASS' if r >= need else 'FAIL'
    if r < need:
        fails.append((label, r, need, ctx))
    print(f"{label:<24} {r:>6.2f}  {need:>5}  {ok}   {ctx} [{size}]")

print()
print('--- FAILURES ---')
for label, r, need, ctx in fails:
    print(f"{label}: {r:.2f} < {need}  ({ctx})")
print(f"\n{len(fails)} / {len(pairs)} pairs fail their required ratio")
