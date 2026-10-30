import re,subprocess,os,bisect
S='/tmp/claude-0/-home-claude/596fb29f-5352-5518-a96d-6604d6e5601f/scratchpad'
R=S+'/yesod/Nodes_Yesod_TVC_native_v09'
subprocess.run(['gcc','-O2','-w','-I'+R+'/third_party/z80',S+'/test_prof.c',R+'/third_party/z80/z80.c','-o',S+'/test_prof'],check=True)
sy={a:int(b,16) for a,b in re.findall(r'(\S+): EQU 0x([\dA-Fa-f]+)',open(R+'/build/native.sym').read())}
env=os.environ.copy();env["COMPOSE_PC"]=f"{sy['compose']:x}";env["PROFGAME"]="1";env["PROFALL"]="1";env["STATE_LO"]=f"{sy['bss']:x}";env["STATE_HI"]=f"{sy['bss_end']:x}"
r=subprocess.run([S+'/test_prof',R+'/Nodes_Yesod_TVC_native_v09.cas',f"{sy['frame.done']:x}",f"{sy['frame']:x}"],cwd=R,env=env,capture_output=True,text=True)
print([l for l in r.stdout.splitlines() if 'checks=' in l or 'SHARE' in l])
labs=sorted((v,k) for k,v in sy.items()); vals=[v for v,k in labs]
agg={}
for l in open(R+'/prof.txt'):
    a,c=l.split();a=int(a,16);k=labs[bisect.bisect_right(vals,a)-1][1];agg[k]=agg.get(k,0)+int(c)
tot=sum(agg.values());print('total',tot)
for k,c in sorted(agg.items(),key=lambda x:-x[1])[:22]:print(f'{k:22s}{100*c/tot:6.1f}%')
