from pathlib import Path
import subprocess,sys,re,shutil,os
R=Path(__file__).resolve().parent
source=(R/'src/native.asm').read_text()
critical=source[source.index('; Sprite pipeline:'):source.index('stars_init:')]
assert not re.search(r'\b(?:ix|iy|ixh|ixl|iyh|iyl)\b','\n'.join(l.split(';')[0] for l in critical.splitlines()),re.I)
subprocess.run([sys.executable,str(R/'test_assets.py')],check=True)
cc=os.environ.get('CC') or shutil.which('cc') or shutil.which('gcc')
if not cc:raise SystemExit('A C compiler is required for the CPU tests (CC / gcc / cc).')
core=R/'third_party/z80';exe=R/'build/native_test'
subprocess.run([cc,'-O2','-I'+str(core),str(R/'test_native.c'),str(core/'z80.c'),'-o',str(exe)],check=True)
sy={a:int(b,16) for a,b in re.findall(r'(\S+): EQU 0x([\dA-Fa-f]+)',(R/'build/native.sym').read_text())}
env=os.environ.copy();env["COMPOSE_PC"]=f"{sy['compose']:x}";env["SYNC_ADDR"]=f"{sy['sync_available']:x}";env["STATE_LO"]=f"{sy['bss']:x}";env["STATE_HI"]=f"{sy['bss_end']:x}"
base=[str(exe),str(R/'Nodes_Yesod_TVC_native_v09.cas'),f"{sy['frame.done']:x}",f"{sy['frame']:x}"]
subprocess.run(base,check=True,cwd=R,env=env)
subprocess.run(base+['7'],check=True,cwd=R,env=env)
subprocess.run(base+[f"{sy[n]:x}" for n in ['compose','menu_wait','native_erosion']],check=True,cwd=R,env=env)

env["BENCHMARK"]="1"
subprocess.run(base+[f"{sy[n]:x}" for n in ['compose','menu_wait','native_erosion']],check=True,cwd=R,env=env)
