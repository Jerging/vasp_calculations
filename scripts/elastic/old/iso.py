import numpy as np
import sys

def iso_deform(eta, latvec):
    return (1+eta)*latvec

if __name__ == "__main__":
    eta = float(sys.argv[1])
    latvec = np.array([float(i) for i in sys.argv[2:]])
    result = iso_deform(eta, latvec)
    print(" ".join(map(str, result)))

