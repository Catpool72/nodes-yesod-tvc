# Nodes of Yesod – Videoton TVC 64K+ port (v12)

Z80 port of the ZX Spectrum game *Nodes of Yesod* to the Videoton TVC (64K+, 128 KB).
Native four-colour sprite engine with double buffering, incremental composition and
synchronised page flip. Ready-to-load tape image: `yesod.cas`.

- Run (Ep128web, "TVC 64k+ · BASIC 2.2"): `load "yesod"` then `run`; menu option 3 = cursor keys.
- Build: `SJASMPLUS=... ZX0=... python3 build_native.py`; tests: `python3 run_tests.py`.
- Details (Hungarian): `OLVASS_EL.txt`, `TESZTELES_v10.txt`.
- Third-party: `third_party/z80`, `licenses/`.

The game itself (code, graphics, music) belongs to its original authors; this repository contains only the porting work.
