    INCLUDE "native_symbols.inc"
    ORG $1f00
boot:
    di
    ld sp,$07f0
    ld a,$b0
    out (2),a
    ld hl,adapter
    ld de,$0800
    ld bc,adapter_end-adapter
    ldir
    ; Verify that the extra video pages do not alias.
    ld a,$90
    out (2),a
    ld a,4
    out (12),a
    ld a,$55
    ld ($8000),a
    ld a,8
    out (12),a
    ld a,$aa
    ld ($8000),a
    ld a,4
    out (12),a
    ld a,($8000)
    cp $55
    jp nz,native_unsupported
    ld a,$b0
    out (2),a
    ld hl,assets1
    ld bc,assets1_end-assets1
    ld a,4
    call unpack_asset
    ld hl,assets2
    ld bc,assets2_end-assets2
    ld a,8
    call unpack_asset
    xor a
    out (12),a
    ld hl,game
    ld de,$2000
    ld bc,game_end-game
    ldir
    ld hl,$2000+game_end-game-1
    ld de,$ffff
    call dzx0_standard_back
    jp native_start
unpack_asset:
    push af
    ld de,$e000
    ldir
    ex de,hl
    dec hl
    pop af
    out (12),a
    ld a,$90
    out (2),a
    ld de,$bfff
    call dzx0_standard_back
    ld a,$b0
    out (2),a
    ret
    INCLUDE "dzx0_standard_back.asm"
adapter:
    INCBIN "../build/native.bin"
adapter_end:
assets1:
    INCBIN "../build/assets1.zx0"
assets1_end:
assets2:
    INCBIN "../build/assets2.zx0"
assets2_end:
game:
    INCBIN "../build/game.zx0"
game_end:
    ASSERT assets1_end-assets1 < $2000
    ASSERT assets2_end-assets2 < $2000
    ASSERT game_end < $c000
