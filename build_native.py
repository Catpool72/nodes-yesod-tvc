from pathlib import Path
import subprocess,struct,re,os,shutil
R=Path(__file__).resolve().parent
(R/'build').mkdir(exist_ok=True)
ASM=os.environ.get('SJASMPLUS') or shutil.which('sjasmplus') or str(R.parent/'tooling/sjasmplus/sjasmplus')
ZX0=os.environ.get('ZX0') or shutil.which('zx0') or str(R.parent/'tooling/ZX0/zx0')
def asm(n):subprocess.run([ASM,'--raw='+str(R/'build'/(n+'.bin')),'--sym='+str(R/'build'/(n+'.sym')),str(R/'src'/(n+'.asm'))],check=True,cwd=R/'src')
asm('spectrum')
# converter reads our pristine source binary, never a previously patched build.
subprocess.run(['python3',str(R/'convert_assets.py')],check=True)
# The unsupported-machine picture is mostly zeros: store it run-length coded.
raw=(R/'src/needs_128k.tvc').read_bytes();rle=bytearray();i=0
while i<len(raw):
 if raw[i]==0:
  n=1
  while i+n<len(raw) and raw[i+n]==0 and n<255:n+=1
  rle+=bytes([0,n]);i+=n
 else:rle.append(raw[i]);i+=1
(R/'build/needs_128k.rle').write_bytes(rle)
asm('native')
sy={a:int(b,16) for a,b in re.findall(r'(\S+): EQU 0x([\dA-Fa-f]+)',(R/'build/native.sym').read_text())}
m=bytearray((R/'build/native_memory.bin').read_bytes())
def put(a,b):m[a:a+len(b)]=b
def word(a,v):put(a,struct.pack('<H',v))
def hook(a,name,op=0xc3):put(a,bytes([op])+struct.pack('<H',sy[name]))
addr=0
for l in (R/'src/spectrum.asm').read_text().splitlines():
 x=re.search(r'IF \$ != \$([\dA-Fa-f]+)',l)
 if x:addr=int(x[1],16)
 if l.strip()=='EI':put(addr,b'\xf3')
 if l.strip()=='HALT':put(addr,b'\0')
 if re.search(r'\bIN\s+A,\(C\)',l):put(addr,b'\x3e\xff')
put(0x7dad,b'\xed\x56')
for a,n,op in [(0xa491,'logic_pass1',0xc3),(0xa4d5,'logic_pass2',0xc3),(0x9cc7,'logic_counters',0xc3),(0x7dc3,'frame',0xcd),(0x7e48,'break_test',0xcd),(0x9a15,'read_joystick',0xc3),(0x861e,'menu_wait',0xc3),(0x99cc,'gameover_wait',0xc3),(0x85b4,'menu_clear',0xc3),(0x8666,'newgame_clear',0xc3),(0x89b7,'clear_work',0xc3),(0x89f8,'print_char',0xc3),(0x8a3b,'paint_tile',0xc3),(0x8888,'room_ready',0xc3),(0x88fe,'stars_init',0xc3),(0x8939,'stars_tick',0xc3),(0x8be3,'sky_clear',0xcd),(0x9ac5,'native_digit',0xc3),(0x9b2e,'native_bar',0xc3),(0x9c1f,'native_erosion',0xc3)]:hook(a,n,op)
# sky hook replaces LDIR+EXX; reproduce EXX after returning.
put(0x8be6,b'\xd9') # original LD C,(HL) at8be6 -> cannot overwrite; use relocated trampoline instead
# restore original bytes at8be6; sky wrapper performs LDIR and EXX itself.
put(0x8be6,(R/'build/spectrum.bin').read_bytes()[0x8be6-0x4000:0x8be9-0x4000])
# Original operation's metadata fill is done by sky_clear. It returns with EXX done.
put(0x8704,bytes(0x8787-0x8704))
for a in [0x8704,0x870d,0x91ae]:put(a,b'\xc9')
put(0x91a5,bytes.fromhex('ddcb008ec9')) # RES1,(IX); RET (no old renderer)
# Geometry now directly addresses material grid, no Spectrum attribute address.
put(0x940b,b'\xf9')
for a,v in [(0x8ff0,0),(0x9008,0xffe0),(0x9050,0),(0x909c,0xffff),(0x90d5,0),(0x9123,0xffe0),(0xa5f6,0)]:word(a,v)
put(0x8280,b'\x02');put(0xa0eb,b'\x03');put(0x9b61,b'\x03')
for i in range(5):word(0x62ac+4*i,i)
word(0x8605,5);word(0x8608,sy['font_id']);word(0x89eb,sy['font_id'])
hook(0x8379,'collection_pair',0xcd)
# Native status digit positions (x cell, y cell).
for a,v in [(0x9a8c,0x1c16),(0x9a9e,0x1916),(0x9ab0,0x1716),(0x9b69,0x1316)]:word(a,v)
word(0x8687,0x57a0);word(0x85d9,0xf700)
# Re-target material-colour feedback to native pair grid; original ROM pixels are gone.
for a in [0x8282,0x8286,0x8289,0xa0ed,0xa0f0,0xa0f3]:
 v=struct.unpack_from('<H',m,a)[0];word(a,v-0x300)
word(0x835c,0x57c6);word(0x9b4f,0x57d3)
# Native game-over panel background, without a Spectrum attribute fill.
hook(0x83ee,'clear_top',0xcd);put(0x83f1,bytes([0xc3])+struct.pack('<H',0x8408))
# Old erosion control bitstream is logic data, relocated away from font pixels.
word(0x9b86,0xef00);word(0x9b91,0xef00)
hook(0x9bd2,'native_column',0xcd);hook(0x9c12,'native_column',0xcd)
# Native linear addresses for destructible terrain rows.
orig=(R/'build/spectrum.bin').read_bytes()
for a in range(0x9d11,0x9d41,2):
 old=struct.unpack_from('<H',orig,a-0x4000)[0];y=((old>>8)&7)|((old>>2)&0x38)|((old>>5)&0xc0);x=old&31
 word(a,0x2000+y*64+x*2)
for a in [0x8311,0x8314,0x8654,0x8657,0xa65a,0xa65d,0xa7c6,0xa7c9,0xa843,0xa846]:put(a,bytes(3))
hook(0x7eda,'any_key');hook(0x9c7e,'native_tick_tail');put(0x9c81,bytes(0x9cb3-0x9c81))
# Clear unreachable Spectrum graphics implementations, keeping native entry jumps.
for a,b in [(0x85b7,0x85d3),(0x8669,0x8672),(0x888b,0x88b5),(0x8901,0x891b),(0x893c,0x895b),(0x89ba,0x89d9),(0x89fb,0x8a2b),(0x8a3e,0x8a87),(0x83f4,0x8408),(0x9ac8,0x9ae4),(0x9b31,0x9b41),(0x9c22,0x9c3c)]:put(a,bytes(b-a))
put(0x9c3c,b'\xc9')
# Clear all dead Spectrum display-address lookup data and sprite XOR bytecode.
put(0x5dfc,bytes(48));put(0x92eb,bytes(0x9397-0x92eb));put(0x940e,bytes(0x9907-0x940e));put(0xfe00,bytes(256))
# Original tune interpreter, with TVC DAC output and native key polling.
put(0x8704,orig[0x8704-0x4000:0x8787-0x4000])
hook(0x876e,'music_tone')
hook(0x8731,'music_key',0xcd)
(R/'build/game.bin').write_bytes(m[0x5b00:])
for n in ['game','assets1','assets2']:
 subprocess.run([ZX0,'-f','-b','-q',str(R/'build'/(n+'.bin')),str(R/'build'/(n+'.zx0'))],check=True)
(R/'src/native_symbols.inc').write_text('native_unsupported EQU $%04x\nnative_start EQU $%04x\n'%(sy['unsupported'],sy['start']))
asm('bootstrap')
blob=(R/'build/bootstrap.bin').read_bytes();basic=bytes.fromhex('0f0a00dd20555352963739333695ff00')
payload=basic+bytes(0x1f00-0x19ef-len(basic))+blob
h=bytearray(144);h[0]=0x11;n=len(payload)+144;struct.pack_into('<H',h,2,n//128);h[4]=n%128;h[129]=1;struct.pack_into('<H',h,130,len(payload));
(R/'Nodes_Yesod_TVC_native_v09.cas').write_bytes(h+payload)
print('Native CAS',len(h+payload),'native engine',len((R/'build/native.bin').read_bytes()))
