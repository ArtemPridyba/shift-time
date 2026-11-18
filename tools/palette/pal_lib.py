import sys, math
from scene_lib import *
def lin(c): c = c / 255; return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
def gam(c): c = max(0, min(1, c)); return round(255 * (12.92 * c if c <= .0031308 else 1.055 * c ** (1 / 2.4) - .055))
def to_lab(rgb):
    r, g, b = (lin(x) for x in rgb)
    l = (.4122214708*r + .5363325363*g + .0514459929*b) ** (1/3); m = (.2119034982*r + .6806995451*g + .1073969566*b) ** (1/3); s = (.0883024619*r + .2817188376*g + .6299787005*b) ** (1/3)
    return (.2104542553*l + .7936177850*m - .0040720468*s, 1.9779984951*l - 2.4285922050*m + .4505937099*s, .0259040371*l + .7827717662*m - .8086757660*s)
def to_rgb(L):
    l, a, b = L; l_ = (l + .3963377774*a + .2158037573*b) ** 3; m_ = (l - .1055613458*a - .0638541728*b) ** 3; s_ = (l - .0894841775*a - 1.2914855480*b) ** 3
    return tuple(gam(x) for x in (4.0767416621*l_ - 3.3077115913*m_ + .2309699292*s_, -1.2684380046*l_ + 2.6097574011*m_ - .3413193965*s_, -.0041960863*l_ - .7034186147*m_ + 1.7076147010*s_))
def ramp(dark, key, light, n=5):
    D, K, Lt = to_lab(h(dark)), to_lab(h(key)), to_lab(h(light)); out = []
    for i in range(n):
        t = i / (n - 1) * 2
        A, B, u = (D, K, t) if t <= 1 else (K, Lt, t - 1)
        out.append(to_rgb(tuple(A[j] + (B[j] - A[j]) * u for j in range(3))))
    return out

FAM_ALL = [('night', 'ночь, фон'), ('steel', 'сталь, бетон'), ('bronze', 'бронза, латунь'), ('rust', 'железо, ржавчина'), ('time', 'время (акцент)'), ('warm', 'свет, огонь (акцент)'), ('tech', 'новая техника')]
hx_ = lambda c: '%02x%02x%02x' % c
def roles(v):
    R = {k: ramp(*v[k]) for k, _ in FAM_ALL if k in v}
    n, st, br, ru, tm, wm = (R[k] for k in ('night', 'steel', 'bronze', 'rust', 'time', 'warm'))
    hat = {'rust': ru[3], 'cream': st[4], 'bronze': br[3]}[v['hat']]
    c = dict(far=n[0], wall=n[1], band=mix(n[1], n[0], .5), seam=n[0], up=st[1], beam=br[2], box=ru[2], box2=ru[1], lamp=br[2], lab=st[1], glass=n[0], cold=st[4],
             ctop=st[3], cfront=st[1], cdark=st[0], stop=st[4], sfront=st[2], haz=wm[2], hazd=n[0], bare=st[4], suit=st[3], suitd=st[2], hat=hat, skin=br[4],
             time=tm[2], water=mix(n[2], tm[0], .35), fire=wm[2], fire2=wm[3], wood=br[1], gear=br[2], gearhi=br[3], iron=ru[1])
    for i in range(5): c['br%d' % i] = br[i]; c['ir%d' % i] = ru[i]; c['st%d' % i] = st[i]
    c['ol'] = n[0]
    if 'tech' in R: c.update(cold=R['tech'][3], glass=R['tech'][0])
    return {k: hx_(x) for k, x in c.items()}, R
