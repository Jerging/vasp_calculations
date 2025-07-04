#!/usr/bin/env python3
"""
coplanar_magnetic_planes.py
Identify coplanar planes for a user‑supplied subset of atoms in a POSCAR /
CONTCAR and assign ± magnetic signs in blocks of L planes.

Outputs
-------
• MAGMOM  – line suitable for VASP INCAR
• coplanar_planes.txt – detailed table of plane assignment
"""
import sys, numpy as np
from pathlib import Path

# ─────────────────────────────────── POSCAR reader ───────────────────────────
def read_poscar(fname):
    """Return (lattice 3×3 Å, fractional coords N×3, element list)"""
    txt = Path(fname).read_text().splitlines()
    scale   = float(txt[1])
    lattice = np.array([[float(x) for x in ln.split()] for ln in txt[2:5]]) * scale
    symbols = txt[5].split()
    counts  = list(map(int, txt[6].split()))
    natoms  = sum(counts)

    ptr = 7
    if txt[ptr][0].lower() == 's':   # Selective dynamics line
        ptr += 1
    cartesian = txt[ptr][0].lower() in ('c', 'k')
    ptr += 1                         # now at first coord line

    coords = np.array([[float(x) for x in txt[i].split()[:3]]
                       for i in range(ptr, ptr + natoms)])
    if cartesian:
        coords = coords @ np.linalg.inv(lattice)

    elements = np.repeat(symbols, counts)
    return lattice, coords, elements
# ─────────────────────────────────── helper -----------------------------------
def ask(prompt, default=None, cast=str):
    tail = f" [{default}]" if default is not None else ""
    val  = input(f"{prompt}{tail}: ").strip()
    return cast(val) if val else default
# ─────────────────────────────────── main -------------------------------------
def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)

    poscar = sys.argv[1]
    n_vec  = np.array(list(map(float, sys.argv[2].split())))
    lattice, frac, elems = read_poscar(poscar)
    natoms = len(elems)

    # ---- choose atoms --------------------------------------------------------
    print("\nElements present:", " ".join(sorted(set(elems))))
    sel = input("Atoms of interest (symbols OR indices; blank = all): ").split()
    if not sel:
        mask = np.ones(natoms, bool)
    elif sel[0].isdigit():
        idx  = [int(x)-1 for x in sel]
        mask = np.zeros(natoms, bool); mask[idx] = True
    else:
        keep = set(sel); mask = np.array([e in keep for e in elems])

    tol = float(ask("Coplanarity tolerance Å", 0.02, float))
    L   = int  (ask("Layers per ferromagnetic block L", 1, int))
    M   = float(ask("Magnetic‑moment magnitude M", 1, float))

    # ---- projections ---------------------------------------------------------
    n_cart = n_vec @ lattice if np.all(np.abs(n_vec) <= 1) else n_vec
    n_hat  = n_cart / np.linalg.norm(n_cart)
    cart   = frac @ lattice
    proj   = cart @ n_hat

    planes = {}                                # plane_id → [ref_proj, [atom_idx]]
    for i, p in enumerate(proj):
        if not mask[i]:
            continue
        pid = next((k for k,(ref,_) in planes.items() if abs(p-ref)<tol), None)
        if pid is None:
            pid = len(planes); planes[pid] = [p, []]
        planes[pid][1].append(i)

    ordered = sorted(planes.items(), key=lambda kv: kv[1][0])

    # ---- assign signs & build MAGMOM array -----------------------------------
    magmom_values = np.zeros(natoms)
    table_lines   = []
    for plane_id, (_, idx_list) in enumerate(a[1] for a in ordered):
        sign = +1 if (plane_id//L)%2 == 0 else -1
        for idx in idx_list:
            magmom_values[idx] = sign * M
            fc = " ".join(f"{x:.3f}" for x in frac[idx])
            table_lines.append(f"{idx+1:<10d} {elems[idx]:<7} {plane_id:<8d} {sign:+d}   {fc}")

    # ---- write MAGMOM file ---------------------------------------------------
    with open("MAGMOM", "w") as f:
        line = "MAGMOM = " + "  ".join(f"{v:+g}" for v in magmom_values)
        f.write(line + "\n")
    print(f"\n{GREEN}Created MAGMOM file with {natoms} entries.{RESET}")

    # ---- write detailed table ------------------------------------------------
    with open("coplanar_planes.txt", "w") as f:
        f.write("atom_index element plane_ID sign frac_coords\n")
        f.write("---------------------------------------------\n")
        f.write("\n".join(table_lines) + "\n")
    print(f"{GREEN}Wrote detailed plane assignment to coplanar_planes.txt{RESET}")

    # ---- also echo table to stdout ------------------------------------------
    print("\natom_index element plane_ID sign frac_coords")
    print("---------------------------------------------")
    print("\n".join(table_lines))
    print(f"\n{len(ordered)} planes found (tol={tol} Å). "
          f"Sign repeats every {L} plane(s).  M = {M}")

# ------------------------------------------------------------------------------
if __name__ == "__main__":
    # Simple color defs for final message
    GREEN = "\033[32m"; RESET = "\033[0m"
    main()

