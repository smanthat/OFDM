import numpy as np

def demapper(signals,orignal_len,original_len_symbol):
    signals = np.array(signals)
    signals = signals[:original_len_symbol]
    demapped_signals = []
     
    for x in signals:
        real = x.real
        imag = x.imag
        if real >= 0 and imag >= 0:
            demapped_signals.append(0)
            demapped_signals.append(0)
        elif real < 0 and imag > 0:
            demapped_signals.append(0)
            demapped_signals.append(1)
        elif real < 0 and imag < 0:
            demapped_signals.append(1)
            demapped_signals.append(1)
        elif real < 0 and imag > 0:
            demapped_signals.append(1)
            demapped_signals.append(0)