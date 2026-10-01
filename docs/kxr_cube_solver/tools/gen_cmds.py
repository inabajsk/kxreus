import sys, json
sys.path.insert(0, '/home/inaba/kxr_cube_solver/scripts')
import robot as R
import kociemba
# a random-looking scramble applied to a solved cube, solved by kociemba
scramble = "R U F' L2 D B' R2 U' F L"
import random
# build cube string via pycuber-free approach: use kociemba's own solve of an inverse -> just solve a known state
state = "DRLUUBFBRBLURRLRUBLRDDFDLFUFUFFDBRDUBRUFLLFDDBFLUBLRBD"
sol = kociemba.solve(state)
ops = sol.split()
r = R.cubeSolver()
phases = []
def cap(name, fn):
    r.command = ""
    fn()
    phases.append((name, r.command))
cap("initDemo", r.initDemo)
cap("startDemo", r.startDemo)
for f in ('D','U','L','R','B','F'):
    cap("lookAt "+f, lambda f=f: r.lookAt(f))
cap("finishScan", r.finishScan)
for op in ops:
    cap("solve "+op, lambda op=op: r.solveOneStep(op))
cap("finishDemo", r.finishDemo)
json.dump({"state": state, "solution": ops, "phases": phases}, open("cmds.json","w"), indent=1)
print(state, sol, len(ops))
for n,c in phases[:12]: print(n, "|", c)
