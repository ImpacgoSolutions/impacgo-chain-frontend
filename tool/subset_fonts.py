"""Makes the bundled Lato fonts small: only the characters the app shows (Latin, punctuation, ₹ and other
currency signs, arrows and symbols). The full fonts stay in tool/fonts_full; run this again after replacing them.
Characters outside this set (e.g. Telugu typed into a field) are still drawn: Flutter fetches a fallback font."""
import glob, os
from fontTools import subset

UNICODES = '0000-017F,02C6-02DD,2000-206F,20A0-20CF,2100-2122,2190-21FF,2212,2215,2219,221E,2248,2260,2264,2265,25A0-25FF,2713,2714,2717'
here = os.path.dirname(os.path.abspath(__file__))
for src in sorted(glob.glob(os.path.join(here, 'fonts_full', 'Lato-*.ttf'))):
    out = os.path.join(here, '..', 'assets', 'fonts', os.path.basename(src))
    opts = subset.Options()
    opts.layout_features = ['kern', 'liga', 'tnum', 'lnum']
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    opts.hinting = False  # hinting data is most of the file; Flutter draws without it
    font = subset.load_font(src, opts)
    s = subset.Subsetter(opts)
    s.populate(unicodes=subset.parse_unicodes(UNICODES))
    s.subset(font)
    subset.save_font(font, out, opts)
    print(os.path.basename(src), os.path.getsize(src) // 1024, 'KB ->', os.path.getsize(out) // 1024, 'KB')
