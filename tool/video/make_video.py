# Builds the manager video from build/video/frames.json + frames/*.png  ->  build/video/IMPACGO_Buy_Flow.mp4
# Run after:  flutter test tool/video/buy_flow_frames.dart
import json, math, os, sys, textwrap
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
VID = os.path.join(ROOT, 'build', 'video')
FONTS = os.path.join(ROOT, 'assets', 'fonts')
W, H, PANEL = 1600, 900, 120
CW, CH = W, H + PANEL
FPS = 24

def font(w, size):
    return ImageFont.truetype(os.path.join(FONTS, 'Lato-%s.ttf' % w), size)

F_CAP, F_STEP, F_BIG, F_MID, F_SM = font(600, 27), font(800, 17), font(800, 64), font(500, 30), font(500, 24)
NAVY, BLUE, RED = (17, 24, 39), (59, 110, 245), (230, 40, 40)

frames = json.load(open(os.path.join(VID, 'frames.json'), encoding='utf-8'))
out_path = os.path.join(VID, 'IMPACGO_Buy_Flow.mp4')
vw = None
for codec in ('avc1', 'mp4v'):
    vw = cv2.VideoWriter(out_path, cv2.VideoWriter_fourcc(*codec), FPS, (CW, CH))
    if vw.isOpened():
        print('codec', codec)
        break
if not vw.isOpened():
    sys.exit('no video codec available')

def put(img):
    vw.write(cv2.cvtColor(np.array(img.convert('RGB')), cv2.COLOR_RGB2BGR))

def slide(lines, sub=None):
    im = Image.new('RGB', (CW, CH), NAVY)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 14, CH], fill=BLUE)
    y = 170
    for i, (txt, f, col) in enumerate(lines):
        d.text((120, y), txt, font=f, fill=col)
        y += f.size + 26
    return im

def wrap(draw, text, f, width):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines

def arrow(d, x, y):
    pts = [(x, y), (x, y + 30), (x + 8, y + 23), (x + 14, y + 36), (x + 20, y + 33), (x + 14, y + 21), (x + 24, y + 21)]
    d.polygon([(px + 2, py + 3) for px, py in pts], fill=(0, 0, 0, 90))
    d.polygon(pts, fill=(255, 255, 255, 255), outline=(0, 0, 0, 255))

def compose(base, fr, t, prev_ptr):
    im = base.copy().convert('RGBA')
    ov = Image.new('RGBA', im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    # highlight box
    if fr.get('box'):
        l, tp, r, b = fr['box']
        pad = 7
        a = int(255 * min(1, t / 0.4))
        pulse = 2 + int(2 * (1 + math.sin(t * 5)) / 2)
        d.rounded_rectangle([l - pad, tp - pad, r + pad, b + pad], radius=9, outline=RED + (a,), width=pulse + 1)
    # pointer, glides in from where it was
    if fr.get('pointer'):
        px, py = fr['pointer']
        k = min(1, t / 0.7)
        k = 1 - (1 - k) ** 3
        if prev_ptr:
            px = prev_ptr[0] + (px - prev_ptr[0]) * k
            py = prev_ptr[1] + (py - prev_ptr[1]) * k
        arrow(d, px, py)
    im = Image.alpha_composite(im, ov)
    # caption panel under the screen
    cv = Image.new('RGB', (CW, CH), NAVY)
    cv.paste(im.convert('RGB'), (0, 0))
    dd = ImageDraw.Draw(cv)
    dd.rectangle([0, H, CW, H + 3], fill=BLUE)
    dd.rounded_rectangle([34, H + 16, 34 + dd.textlength(fr['step'].upper(), font=F_STEP) + 28, H + 46], radius=8, fill=BLUE)
    dd.text((48, H + 22), fr['step'].upper(), font=F_STEP, fill='white')
    lines = wrap(dd, fr['caption'], F_CAP, CW - 90)[:2]
    for i, ln in enumerate(lines):
        dd.text((38, H + 54 + i * 34), ln, font=F_CAP, fill='white')
    return cv

# ---- title
steps = []
for f in frames:
    if f['step'] not in steps and f['step'] != 'Start':
        steps.append(f['step'])
title = slide([
    ('IMPACGO Chain', F_BIG, 'white'),
    ('Buy flow, from scratch', F_MID, (170, 190, 255)),
    ('Purchase Request  >  Approval  >  Purchase Order  >  Goods Receipt  >  Quality Check', F_SM, (200, 205, 215)),
    ('>  Bin Allocation  >  Purchase Invoice  >  Purchase Return', F_SM, (200, 205, 215)),
    ('Every step in this video was done on the real screens, with every form field explained.', F_SM, (140, 150, 170)),
])
for _ in range(int(4.5 * FPS)):
    put(title)

prev_img, prev_ptr = None, None
total = 0
for n, fr in enumerate(frames):
    img = Image.open(os.path.join(VID, 'frames', fr['file'])).convert('RGB')
    hold = max(fr.get('hold', 3.0), 1.6 + len(fr['caption']) / 17.0)
    nf = int(hold * FPS)
    for i in range(nf):
        t = i / FPS
        c = compose(img, fr, t, prev_ptr)
        # short cross-fade from the previous picture
        if prev_img is not None and t < 0.25:
            a = t / 0.25
            c = Image.blend(prev_img, c, a)
        put(c)
    prev_img = compose(img, fr, hold, prev_ptr)
    prev_ptr = fr.get('pointer') or prev_ptr
    total += nf

# ---- outro
outro = slide([
    ('What happened to the stock and money', F_MID, 'white'),
    ('100 helmets received  >  90 accepted at QC, 10 rejected', F_SM, (200, 205, 215)),
    ('90 stored in bins; 10 returned; debit note DBN-2026-0001 raised (Rs 3,776)', F_SM, (200, 205, 215)),
    ('Purchase invoice PI-2026-0001 (Rs 37,760) verified automatically, approved for payment', F_SM, (200, 205, 215)),
    ('Manual steps: submit, approve, create PO, receive, raise QC, record QC, bins, invoice, dispatch return', F_SM, (140, 150, 170)),
])
for _ in range(int(7 * FPS)):
    put(outro)
vw.release()
secs = (int(4.5 * FPS) + total + int(7 * FPS)) / FPS
print('written', out_path, 'seconds %.0f' % secs, 'MB %.1f' % (os.path.getsize(out_path) / 1e6))
