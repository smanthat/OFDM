import numpy as np

def demapper(signals,original_len,original_len_symbol):
    signals = np.array(signals)

    signals = signals[:original_len_symbol]
    signals = signals.flatten()

    demapped_signals = []
     
    for x in signals:
        real = x.real
        imag = x.imag

        # 00 -> 1 + 1j
        if real >= 0 and imag >= 0:
            demapped_signals.append(0)
            demapped_signals.append(0)

        # 01 -> -1 + 1j
        elif real < 0 and imag >= 0:
            demapped_signals.append(0)
            demapped_signals.append(1)

        # 11 -> -1 - 1j
        elif real < 0 and imag < 0:
            demapped_signals.append(1)
            demapped_signals.append(1)

        # 10 -> 1 - 1j
        elif real >= 0 and imag < 0:
            demapped_signals.append(1)
            demapped_signals.append(0)

    demapped_signals = np.array(demapped_signals)

    demapped_signals = demapped_signals[:original_len]

    return demapped_signals