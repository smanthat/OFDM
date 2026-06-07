import numpy as np
def dec_to_fixed_point(x,F,W):
    x = (2 ** F) * x
    x = np.round(x)
    lo = - (2 ** (W - 1))
    hi = (2 ** (W - 1)) - 1
    
    for i in range(len(x)):
        if x[i] > hi:
            x[i] = hi
        elif x[i] < lo:
            x[i] = lo
    
    return x.astype(int)