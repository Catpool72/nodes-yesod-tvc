"""Compare every native asset pixel with its build-time source; no emulator needed."""
from pathlib import Path
import json,struct
R=Path(__file__).resolve().parent
old=bytes(0x4000)+(R/'build/spectrum.bin').read_bytes().ljust(0xc000,b'\0')
banks=[b'']+[(R/f'build/assets{i}.bin').read_bytes() for i in range(1,3)]
native=(R/'build/native_memory.bin').read_bytes()
def asset(bank,addr):return native[addr:] if bank==255 else banks[bank][addr-0x8000:]
info=json.loads((R/'build/assets.json').read_text());cm=[0,1,2,1,2,1,2,3];count=0
def colour(v,x):return ((v>>(7-x))&1)|(((v>>(3-x))&1)<<1)
for sp in info['sprites']:
 p=int(sp['source'],16);w,h=sp['width'],sp['height'];stride=(w+7)//8;ns=(w+3)//4
 for mirror,kind in enumerate(['normal','mirror']):
  bank,addr=sp[kind];data=asset(bank,addr)
  for y in range(h):
   for x in range(ns*4):
    sx=w-1-x if mirror else x
    want=3 if 0<=sx<w and old[p+3+y*stride+sx//8]&(128>>(sx%8)) else 0
    assert colour(data[y*ns+x//4],x%4)==want,(hex(p),kind,x,y)
    count+=1
for base,bank,addr,stride,n in info['fonts']:
 data=asset(255 if bank==255 else bank//4,addr)
 for c in range(n):
  src=base+c*(9 if stride==17 else 8);at=old[src+8] if stride==17 else None
  for y in range(8):
   for x in range(8):
    bit=bool(old[src+y]&(128>>x));want=(cm[(at&7) if bit else ((at>>3)&7)] if at is not None else (3 if bit else 0))
    assert colour(data[c*stride+y*2+x//4],x%4)==want,(hex(base),c,x,y)
    count+=1
  if at is not None:assert data[c*stride+16]==at
# Old pixel slots are now intentionally reused by native RAM assets.
used=set(i for a,n in info['ram_assets'] for i in range(a,a+n))
for sp in info['sprites']:
 p=int(sp['source'],16);w,h=sp['width'],sp['height']
 assert not any(native[i] for i in range(p,p+3+((w+7)//8)*h) if i not in used)
for base,bank,addr,stride,n in info['fonts']:
 assert not any(native[i] for i in range(base,base+n*(9 if stride==17 else 8)) if i not in used)
assert all(v<16 for v in native[0xec00:0xef00])
print(f'Native asset pixels checked: {count}; mismatches: 0')
print(f'{len(info["sprites"])} sprites, both directions; {sum(f[4] for f in info["fonts"])} glyphs/tiles; retired pixel slots are zero or contain verified native RAM assets.')
