from pathlib import Path
import struct,json
R=Path(__file__).resolve().parent
m=bytearray(65536);m[0x4000:]=(R/'build/spectrum.bin').read_bytes().ljust(0xc000,b'\0')
erosion=bytes(m[0x7666:0x7766])
bar=bytes(m[0x5d19:0x5d59])
banks=[bytearray() for _ in range(2)]
ram_regions=[]
ram_assets=[]
def store(b):
 for i,p in enumerate(banks):
  if len(p)+len(b)<=16384:
   a=0x8000+len(p);p.extend(b);return i+1,a
 for lo,hi,pos in ram_regions:
  if pos+len(b)<=hi:
   ram_assets.append((pos,bytes(b)))
   for item in ram_regions:
    if item[0]==lo:item[2]+=len(b);break
   return 255,pos
 raise ValueError('Native assets exceed two VRAM pages and reclaimed RAM')
def page_tag(bank):return 255 if bank==255 else bank*4
cm=[0,1,2,1,2,1,2,3]
def pix4(p):return sum(((v&1)<<(7-i))|((v>>1)<<(3-i)) for i,v in enumerate(p))
def packed(bits):return bytes(pix4(bits[i:i+4]) for i in range(0,len(bits),4))
def maskrow(b,w):return [3 if b[x//8]&(128>>(x%8)) else 0 for x in range(w)]+[0]*(-w%4)
# Original loader fills these five collectible-object slots at runtime.
m[0xc7c4:0xc7ce]=m[0x5b54:0x5b5e]
ptrs=sorted(set(struct.unpack_from('<42H',m,0xb700)+struct.unpack_from('<112H',m,0xc700))-{0})
font_specs=[(0x635d,105,1),(0x67aa,107,1),(0x6bf7,84,1),(0x6f85,114,1),(0x73e6,104,0),(0x781d,177,0)]
regions=[(q,q+3+((m[q]+7)//8)*m[q+1]) for q in ptrs]
regions += [(base,base+n*(9 if attr else 8)) for base,n,attr in font_specs]
for lo,hi in sorted(regions):
 if ram_regions and ram_regions[-1][1]==lo:ram_regions[-1][1]=hi
 else:ram_regions.append([lo,hi,lo])
fonts=[]
for base,n,hasattr in font_specs:
 data=bytearray()
 for c in range(n):
  p=base+c*(9 if hasattr else 8);col=m[p+8] if hasattr else 7
  ink,paper=cm[col&7],cm[(col>>3)&7]
  for y in range(8):
   vals=[(ink if m[p+y]&(128>>x) else paper) if hasattr else (3 if m[p+y]&(128>>x) else 0) for x in range(8)]
   data.extend(packed(vals))
  if hasattr:data.append(col) # gameplay material / collision descriptor only
 a=store(data);fonts.append((base,page_tag(a[0]),a[1],17 if hasattr else 16,n))
 m[base:base+n*(9 if hasattr else 8)]=bytes(n*(9 if hasattr else 8))
dir=bytearray();manifest=[];sprite_ids={p:0xe400+10*i for i,p in enumerate(ptrs)}
for p in ptrs:
 w,h,col=m[p:p+3];stride=(w+7)//8
 if w>64 or h>64:raise ValueError((hex(p),w,h))
 rows=[maskrow(m[p+3+y*stride:p+3+(y+1)*stride],w) for y in range(h)]
 na=b''.join(packed(v) for v in rows);nb=b''.join(packed(list(reversed(v[:w]))+[0]*(-w%4)) for v in rows)
 # The native shift/paint kernels rely on every mask byte being a nibble pair.
 if any((x>>4)!=(x&15) for x in na+nb):raise ValueError('sprite mask byte is not a nibble pair at %s'%hex(p))
 a=store(na);b=store(nb)
 ink=[0,0xf0,0x0f,0xff][cm[col&7]]
 dir.extend(bytes([w,h,ink])+struct.pack('<BHBHB',page_tag(a[0]),a[1],page_tag(b[0]),b[1],(w+3)//4))
 manifest.append({'source':hex(p),'width':w,'height':h,'normal':a,'mirror':b})
 # Replace old headers and pixels with native descriptors and banked pixels.
 m[p:p+3+h*stride]=bytes(3+h*stride)
for table,n in [(0xb700,42),(0xc700,112)]:
 for i in range(n):
  q=struct.unpack_from('<H',m,table+2*i)[0]
  struct.pack_into('<H',m,table+2*i,sprite_ids[q] if q else 0)
for i,p in enumerate([0x601c,0x603f,0x6062,0x6085,0x5ff9]):struct.pack_into('<H',m,0x5b54+2*i,sprite_ids[p])
dir.extend(b'\0\0')
# Directory lies in the retired Spectrum workspace, never used for pixels again.
m[0xe400:0xf900]=bytes(0x1500)
m[0xe400:0xe400+len(dir)]=dir
fontids={0x6f85:0,0x635d:1,0x67aa:2,0x6bf7:3,0x73e6:4,0x781d:5}
fd=b''.join(struct.pack('<HBHBB',fontids[f[0]],*f[1:]) for f in fonts)+bytes(2)
m[0xeb00:0xeb00+len(fd)]=fd
# Native TVC ink/paper pair grids. Two bits each, no FLASH/BRIGHT flags.
def pair(a):return cm[a&7]|(cm[(a>>3)&7]<<2)
colours=bytearray();p=0x610f
while len(colours)<768:
 v=m[p];p+=1
 if not v:break
 count=m[p];p+=1;colours.extend([pair(v)]*count)
m[0x610f:p]=bytes(p-0x610f)
colours=colours[:768].ljust(768,b'\x03')
m[0xec00:0xef00]=colours
# Original menu text, converted with the same native font as the title artwork.
m[0xf700:0xf75a]=m[0x60b5:0x610f]
m[0xef00:0xf000]=erosion
m[0xf600:0xf680]=b''.join(packed(maskrow(bytes([v]),8)) for v in bar)
m[0x5d19:0x5d59]=bytes(64)
# Sprite masks are always nibble pairs (n*0x11). A shifted output nibble is
# therefore a function of two neighbouring nibbles: w=(prev_hi<<4)|cur_lo, and
# one 256-byte table per shift (1..3 pixels) replaces the old A/B table pairs.
for shift in range(1,4):
 for w in range(256):
  m[0xf000+(shift-1)*256+w]=0x11*((w>>shift)&15)
m[0x60b5:0x610f]=bytes(0x610f-0x60b5)
# Original music score retained for TVC DAC playback.
m[0x5d99:0x5df9]=bytes(pair(v) for v in m[0x5d99:0x5df9])
for address,data in ram_assets:m[address:address+len(data)]=data
for i,p in enumerate(banks):
 (R/f'build/assets{i+1}.bin').write_bytes(p.ljust(16384,b'\0'))
(R/'build/native_memory.bin').write_bytes(m)
(R/'build/assets.json').write_text(json.dumps({'sprites':manifest,'fonts':fonts,'bank_bytes':[len(p) for p in banks],'ram_assets':[[a,len(b)] for a,b in ram_assets]},indent=2))
print('sprites',len(ptrs),'directory',len(dir),'bank bytes',[len(p) for p in banks])
