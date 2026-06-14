import numpy as np
def dec_to_fixed_point(x,F,W):
    x = (2 ** F) * x
    x = np.round(x)
    lo = - (2 ** (W - 1))
    hi = (2 ** (W - 1)) - 1
    
    x = np.clip(x, lo, hi)
    
    return x.astype(int)

def fixed_point_to_dec(x_fixed, F, W):
    # Convert fixed-point to decimal
    x_dec = x_fixed / (2**F)
    return x_dec

def export_fixed_point(arr, filename, F, W):
    re = dec_to_fixed_point(arr.real.flatten(), F, W)
    im = dec_to_fixed_point(arr.imag.flatten(), F, W)
    with open(filename, "w") as f:
        for r, i in zip(re, im):
            f.write(f"{int(r) & 0xFFFF:04x} {int(i) & 0xFFFF:04x}\n")