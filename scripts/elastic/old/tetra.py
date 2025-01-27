import numpy as np
import sys

def tetra_deform(eta, latvec):
    x = (1+eta)*latvec[0]
    y = (1+eta)*latvec[1]
    z = (1-2*eta)*latvec[2]
    return np.array([x,y,z])

if __name__ == "__main__":
    eta = float(sys.argv[1])
    latvec = np.array([float(i) for i in sys.argv[2:]])
    result = tetra_deform(eta, latvec)
    print(" ".join(map(str, result)))

