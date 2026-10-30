# Nodes of Yesod – Videoton TVC 64K+ port (v13)

Z80 port of the ZX Spectrum game *Nodes of Yesod* to the Videoton TVC (64K+, 128 KB).
Native four-colour sprite engine with double buffering, incremental composition and
synchronised page flip. Ready-to-load tape image: `yesod.cas`.

- **Requires TVC 64K+ (128 KB total). It does not run on a plain 64K machine** (the pre-converted graphics live in the extra video pages). For a plain 64K TVC use a port that converts the Spectrum data at run time.
- **Plain TVC 64K:** see [`tvc64k/`](tvc64k/) – a separate port by **Kis Károly** (https://www.facebook.com/groups/206386136109760/user/1357985679).
- Run (Ep128web, "TVC 64k+ · BASIC 2.2"): `load "yesod"` then `run`; menu option 3 = cursor keys.
- Build: `SJASMPLUS=... ZX0=... python3 build_native.py`; tests: `python3 run_tests.py`.
- Details (Hungarian): `OLVASS_EL.txt`, `TESZTELES_v10.txt`.
- Third-party: `third_party/z80`, `licenses/`.

The game itself (code, graphics, music) belongs to its original authors; this repository contains only the porting work.
