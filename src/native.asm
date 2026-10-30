; Nodes of Yesod: TVC64K+ native four-colour graphics engine.
; Game logic retains material codes; every bitmap is TVC interleaved planes.
    ORG $0800
unsupported:
    di
    xor a
    out (0),a
    ld a,1
    out (6),a
    xor a
    out (12),a
    out ($60),a
    ld a,$55
    out ($63),a
    ld a,$90
    out (2),a
    ld hl,$8000
    ld de,$8001
    ld bc,$3fff
    ld (hl),0
    ldir
    ld hl,needs_rle
    ld de,$2000
.dec:
    ld a,(hl)
    inc hl
    or a
    jr nz,.lit
    ld c,(hl)
    inc hl
.run:
    ld (de),a
    inc de
    dec c
    jr nz,.run
    jr .chk
.lit:
    ld (de),a
    inc de
.chk:
    ld a,d
    cp $26
    jr c,.dec
    ld hl,$2000
    ld de,$9a08
    ld a,32
.loop:
    ld bc,48
    ldir
    ex de,hl
    ld bc,16
    add hl,bc
    ex de,hl
    dec a
    jr nz,.loop
.stop:
    jr .stop
start:
    di
    ld sp,$07f0
    xor a
    out (0),a
    out (5),a
    call select_page
    ld a,1
    out (6),a
    xor a
    out ($60),a
    ld a,$51
    out ($61),a
    ld a,$54
    out ($62),a
    ld a,$55
    out ($63),a
    call clear_native
    call initialise_sync
    jp $7da5

; Main RAM background $2000..$4fff (64 bytes *192 native scanlines).
; $5000..$54ff native sprite shift cache; $5500..$57ff TVC colour pairs.
; $5800..$583f previous native sprite rectangles. No Spectrum screen exists.
clear_top:
    push af
    ld a,$29
    ld (clear_native.vc+2),a
    ld a,$86
    ld (clear_native.vs+2),a
    ld a,$29
    ld (clear_native.bgc+2),a
    xor a
    ld (clear_native.tm+1),a
    jr clear_native.go
clear_native:
    push af
    ld a,$3f
    ld (.vc+2),a
    ld a,$80
    ld (.vs+2),a
    ld a,$2f
    ld (.bgc+2),a
    ld a,1
    ld (.tm+1),a
.go:
    push bc
    push de
    push hl
    xor a
    ld (LIVE_VALID),a
    ld (display_page),a
    ld a,12
    ld (back_page),a
    ld hl,$2000
    ld de,$2001
.bgc: ld bc,$2fff
    ld (hl),0
    ldir
    ld hl,bss
    ld de,bss+1
    ld bc,bss_end-bss-1
    ld (hl),0
    ldir
    ld hl,$5800
    ld de,$5801
    ld bc,63
    ld (hl),0
    ldir
    ld hl,$5900
    ld de,$5901
    ld bc,63
    ld (hl),0
    ldir
.tm: ld a,1
    or a
    jr z,.notxt
    ld hl,$5840
    ld de,$5841
    ld bc,95
    ld (hl),$ff
    ldir
    ld hl,$58a0
    ld de,$58a1
    ld bc,95
    ld (hl),0
    ldir
.notxt:
    ld a,$90
    out (2),a
    xor a
    call select_page
    call .clear_page
    ld a,12
    call select_page
    call .clear_page
    ld a,$b0
    out (2),a
    pop hl
    pop de
    pop bc
    pop af
    ret
.clear_page:
.vs: ld hl,$8000
    ld d,h
    ld e,l
    inc de
.vc: ld bc,$3fff
    ld (hl),0
    ldir
    ret

menu_clear:
    call clear_native
    push hl
    push de
    push bc
    ld hl,$ec00
    ld de,$5500
    ld bc,768
    ldir
    pop bc
    pop de
    pop hl
    jp $85d3
newgame_clear:
    call clear_native
    jp $8672

; A=character index, native record pointer = base+A*stride.
font_fetch:
    ld (glyph_index),a
    call font_lookup
    ld (asset_page),a
    ld a,(glyph_index)
    ld b,a
    or a
    jr z,.ready
    push hl
    ld e,c
    ld d,0
    ld h,d
    ld l,d
    ld a,b
    ld b,8
.mul:
    add hl,hl
    rlca
    jr nc,.nomul
    add hl,de
.nomul:
    djnz .mul
    pop de
    add hl,de
.ready:
    ld a,(asset_page)
    call map_asset
    ld de,$5000
    ld b,0
    ldir
    ld a,(back_page)
    call select_page
    ld a,$b0
    out (2),a
    ret
; DE=8x8 cell coordinate -> native background address HL and pair index BC.
cell_address:
    ld l,e
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld b,h
    ld c,l
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld a,h
    add a,$20
    ld h,a
    ld a,d
    add a,a
    add a,l
    ld l,a
    ld a,c
    add a,d
    ld c,a
    ret
; Native background tile, already coloured in its asset bank.
paint_tile:
    ex af,af'
    ld a,d
    cp 32
    ret nc
    ld a,e
    cp 21
    ret nc
    push hl
    push bc
    push de
    ex af,af'
    ld (tile_flags),a
    and 127
    call font_fetch
    pop de
    push de
    call cell_address
    ld de,$5000
    ld b,8
.row:
    ld a,(tile_flags)
    bit 7,a
    jr z,.normal
    push hl
    ld a,(de)
    ld c,a
    inc de
    ld a,(de)
    inc de
    call reverse_native
    ld (hl),a
    inc hl
    ld a,c
    call reverse_native
    ld (hl),a
    pop hl
    jr .next
.normal:
    ld a,(de)
    ld (hl),a
    inc hl
    inc de
    ld a,(de)
    ld (hl),a
    dec hl
    inc de
.next:
    push de
    ld de,64
    add hl,de
    pop de
    djnz .row
    pop de
    push de
    call cell_address
    ld h,b
    ld l,c
    ld bc,$f900
    add hl,bc
    ld a,($5010)
    ld (hl),a
    pop de
    pop bc
    pop hl
    ret
reverse_native:
    push hl
    push bc
    ld l,a
    ld h,HIGH reverse_table
    ld a,(hl)
    pop bc
    pop hl
    ret

; Native character masks are 16 bytes, already in TVC pixel order.
print_char:
    ex af,af'
    ld a,d
    cp 32
    ret nc
    ld a,e
    cp 24
    ret nc
    cp 21
    jr c,.draw
    ; HUD cell: skip the redraw when glyph and colour are already shown.
    push hl
    push bc
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld c,d
    ld b,0
    add hl,bc
    ld bc,$5500
    add hl,bc               ; $5500 + cell index
    ld b,(hl)               ; colour
    inc h
    ld a,(hl)               ; colour already drawn
    dec h
    cp b
    jr nz,.nohit
    ex af,af'
    ld c,a                  ; glyph
    ex af,af'
    ld a,l
    add a,$a0
    ld l,a
    ld a,h
    adc a,0
    ld h,a
    ld a,(hl)               ; glyph already drawn
    cp c
    jr nz,.nohit
    pop bc
    pop hl
    ret
.nohit:
    pop bc
    pop hl
.draw:
    push hl
    push bc
    push de
    ex af,af'
    call font_fetch
    pop de
    push de
    call cell_address
    push hl
    ld h,b
    ld l,c
    ld bc,$5500
    add hl,bc
    ld a,(hl)
    push af
    ld a,h
    cp $57
    jr c,.no_hud
    ld a,l
    cp $a0
    jr c,.no_hud
    push hl
    ld de,$00a0
    add hl,de
    ld a,(glyph_index)
    ld (hl),a
    pop hl
    push hl
    inc h
    ld a,(hl)
    pop hl
    ld a,(hl)
    push hl
    inc h
    ld (hl),a
    pop hl
.no_hud:
    pop af
    and 15
    ld l,a
    ld h,HIGH native_pairs
    ld a,(hl)
    ld (ink_byte),a
    ld a,l
    rrca
    rrca
    and 3
    ld l,a
    ld a,(hl)
    ld (paper_byte),a
    pop hl
    ld de,$5000
    ld a,(paper_byte)
    ld (.pp1+1),a
    ld (.pp2+1),a
    ld c,a
    ld a,(ink_byte)
    xor c                   ; dest = paper ^ ((ink ^ paper) & glyph)
    ld (.px1+1),a
    ld (.px2+1),a
    ld b,8
.row:
    ld a,(de)
.px1:
    and 0
.pp1:
    xor 0
    ld (hl),a
    inc hl
    inc de
    ld a,(de)
.px2:
    and 0
.pp2:
    xor 0
    ld (hl),a
    inc de
    ld a,l
    add a,63
    ld l,a
    jr nc,.rowc
    inc h
.rowc:
    djnz .row
    pop de
    push de
    call cell_address
    ld b,8
    ld c,2
    call copy_dual_rect
    pop de
    pop bc
    pop hl
    ret
; ORG page contains four plane masks repeated for all 16 native colour pairs.

clear_work:
    push hl
    push de
    push bc
    push af
    ld hl,$f900
    ld de,$f901
    ld bc,$29f
    ld (hl),a
    ldir
    ld hl,$2000
    ld de,$2001
    ld bc,$29ff
    ld a,($5b04)
    cp 16
    ld a,0
    jr nc,.fill
    ld a,$f0
.fill:
    ld hl,$2000
    ld (hl),a
    ld de,$2001
    ldir
    pop af
    pop bc
    pop de
    pop hl
    ret
room_ready:
    call stars_init
    push hl
    push de
    push bc
    ld hl,$2000
    ld b,168
    ld c,64
    call copy_dual_rect
    ld hl,$5800
    ld de,$5801
    ld bc,63
    ld (hl),0
    ldir
    ld hl,$5900
    ld de,$5901
    ld bc,63
    ld (hl),0
    ldir
    pop bc
    pop de
    pop hl
    jp $88b5

; Sprite pipeline: regular HL/DE/BC addressing throughout.
; The game entity and old-rectangle pointers are saved once per sprite.
compose:
    ; The kernels below use the shadow registers (loop counters, shift carry),
    ; so preserve the game's own shadow set around the whole composition.
    exx
    push bc
    push de
    push hl
    exx
    ex af,af'
    push af
    ex af,af'
    ; Incremental composition: only sprites whose image changed on this back
    ; page, or that touch a changed region, are erased and drawn again.
    call sig_scan
    cp 16
    jr z,.erase_all
    or a
    jr nz,.closure
    ; Nothing changed: still honour pending external writes to this page.
    ld a,(back_page)
    or a
    ld a,(ext_n)
    jr z,.pending
    ld a,(ext_n+1)
.pending:
    or a
    jr z,.flip
.closure:
    call closure
.erase_all:
    ld a,$90
    out (2),a
    ld a,(back_page)
    call select_page
    call old_rectangles
    ld de,dirty
    ld b,16
.erase:
    ld a,(de)
    or a
    jr z,.erase_next
    inc hl
    inc hl
    ld a,(hl)
    dec hl
    dec hl
    or a
    jr z,.erase_next
    push bc
    push de
    push hl
    call restore_rect
    pop hl
    pop de
    pop bc
.erase_next:
    inc de
    inc hl
    inc hl
    inc hl
    inc hl
    djnz .erase
    ld a,$b0
    out (2),a
    call old_rectangles
    ex de,hl
    ld hl,$fc00
    ld bc,dirty
.draw:
    ld a,(bc)
    or a
    jr z,.draw_next
    push bc
    push de
    push hl
    inc de
    inc de
    xor a
    ld (de),a
    dec de
    dec de
    ld (rect_ptr),de
    ld (entity_ptr),hl
    bit 0,(hl)
    call nz,draw_entity
    pop hl
    pop de
    pop bc
.draw_next:
    inc bc
    inc de
    inc de
    inc de
    inc de
    ld a,l
    add a,32
    ld l,a
    jr nc,.draw_more
    inc h
.draw_more:
    ld a,c
    cp 16
    jr nz,.draw
    ; This page's pending external writes have now been honoured.
    ld a,(back_page)
    or a
    ld hl,ext_n
    jr z,.consumed
    inc hl
.consumed:
    ld (hl),0
.flip:
    call flip_buffers
    ex af,af'
    pop af
    ex af,af'
    exx
    pop hl
    pop de
    pop bc
    exx
    ret

old_sigs:
    ld hl,sig0
    ld a,(back_page)
    or a
    ret z
    ld hl,sig1
    ret

; Compare every entity with the image signature last drawn on this page and
; set dirty[i]. Returns A = number of changed entities. A changed entity's
; stored signature is rewritten on the spot, so there is no commit pass.
; Signature (8 bytes): flags&$81, x, y, height, ink, pointer (2), flip&$80.
; An inactive entity has the all-zero signature. Entities sit on 32-byte and
; signatures on 8-byte boundaries, which the update path relies on.
sig_scan:
    call old_sigs
    ex de,hl
    ld hl,$fc00
    exx
    ld hl,dirty
    ld c,0
    exx
    ld b,16
.scan:
    res 1,(hl)
    bit 0,(hl)
    jr z,.inactive
    ld a,(de)
    xor (hl)
    and $81
    jr nz,.update
    inc hl
    inc de
    ld a,(de)
    cp (hl)
    jr nz,.update
    inc hl
    inc de
    ld a,(de)
    cp (hl)
    jr nz,.update
    inc hl
    inc hl
    inc de
    ld a,(de)
    cp (hl)
    jr nz,.update
    inc hl
    inc de
    ld a,(de)
    cp (hl)
    jr nz,.update
    inc hl
    inc hl
    inc de
    ld a,(de)
    cp (hl)
    jr nz,.update
    inc hl
    inc de
    ld a,(de)
    cp (hl)
    jr nz,.update
    inc de
    ld a,l
    add a,22
    ld l,a
    ld a,(de)
    xor (hl)
    and $80
    jr nz,.update
    jr .flag                ; A = 0: unchanged
.update:
    ld a,l
    and $e0
    ld l,a
    ld a,e
    and $f8
    ld e,a
    ld a,(hl)
    and $81
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    inc hl
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    inc hl
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    inc de
    ld a,l
    add a,22
    ld l,a
    ld a,(hl)
    and $80
    ld (de),a
    ld a,1
    jr .flag
.inactive:
    ld a,(de)
    or a
    jr z,.idle
    xor a
    ld (de),a
    inc de
    ld (de),a
    inc de
    ld (de),a
    inc de
    ld (de),a
    inc de
    ld (de),a
    inc de
    ld (de),a
    inc de
    ld (de),a
    inc de
    ld (de),a
    ld a,l
    add a,30
    ld l,a
    ld a,1
    jr .flag
.idle:
    ld a,l
    add a,30
    ld l,a
    ld a,e
    add a,7
    ld e,a
    xor a
.flag:
    exx
    ld (hl),a
    inc hl
    add a,c
    ld c,a
    exx
    inc hl
    inc hl
    inc de
    dec b
    jp nz,.scan
    exx
    ld a,c
    exx
    ret

; Grow the dirty set until no clean sprite overlaps a region that will be
; erased or redrawn. Regions are (x0,y0,x1,y1) in native bytes / scanlines:
; this page's pending external writes plus the old and new rectangle of every
; dirty entity. Old rectangle tables are 256-aligned and 4 bytes per entity,
; so E = 4*i also indexes the probe table.
closure:
    xor a
    ld (reg_n),a
    ld hl,ext_n
    ld de,ext0
    ld a,(back_page)
    or a
    jr z,.page
    inc hl
    ld de,ext1
.page:
    ld a,(hl)
    cp 255
    jp z,.all
    or a
    jr z,.gather_init
    ld (reg_n),a
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    ld b,h
    ld c,l
    ex de,hl
    ld de,regs
    ldir
.gather_init:
    call old_rectangles
    ex de,hl
    ld hl,$fc00
    ld bc,dirty
.gather:
    ld a,(bc)
    or a
    jr z,.gather_next
    push bc
    push de
    push hl
    ex de,hl
    call region_add
    pop hl
    pop de
    push de
    push hl
    bit 0,(hl)
    jr z,.gather_pop
    ld (entity_ptr),hl
    ld a,e
    add a,newr&255
    ld l,a
    ld h,HIGH newr
    ld (rect_ptr),hl
    inc hl
    inc hl
    ld (hl),0
    ld hl,(entity_ptr)
    call entity_clip
    jr c,.gather_pop
    ld hl,(rect_ptr)
    call region_add
.gather_pop:
    pop hl
    pop de
    pop bc
.gather_next:
    inc bc
    inc de
    inc de
    inc de
    inc de
    ld a,l
    add a,32
    ld l,a
    jr nc,.gather_more
    inc h
.gather_more:
    ld a,c
    cp 16
    jr nz,.gather
    ld a,(reg_n)
    or a
    ret z
.propagate:
    xor a
    ld (changed_flag),a
    call old_rectangles
    ld bc,dirty
.prop:
    ld a,(bc)
    or a
    jr nz,.prop_next
    inc hl
    inc hl
    ld a,(hl)
    dec hl
    dec hl
    or a
    jr z,.prop_next
    push bc
    push hl
    call rect_to_tmp
    ld a,(reg_n)
    ld b,a
    ld de,regs
.test:
    ld hl,tmp_reg
    call rect_hit
    jr c,.hit
    inc de
    inc de
    inc de
    inc de
    djnz .test
    pop hl
    pop bc
    jr .prop_next
.hit:
    call region_push
    pop hl
    pop bc
    ld a,1
    ld (bc),a
    ld (changed_flag),a
.prop_next:
    inc bc
    inc hl
    inc hl
    inc hl
    inc hl
    ld a,c
    cp 16
    jr nz,.prop
    ld a,(changed_flag)
    or a
    jr nz,.propagate
    ret
.all:
    call old_rectangles
    ld de,dirty
    ld b,16
.all_loop:
    inc hl
    inc hl
    ld a,(hl)
    dec hl
    dec hl
    or a
    jr z,.all_next
    ld a,1
    ld (de),a
.all_next:
    inc de
    inc hl
    inc hl
    inc hl
    inc hl
    djnz .all_loop
    ret

; HL -> (x,y,w,h). tmp_reg := (x,y,x+w,y+h).
rect_to_tmp:
    ld de,tmp_reg
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld c,a
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld b,a
    ld a,(hl)
    add a,c
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    add a,b
    ld (de),a
    ret
; Append tmp_reg to the region list.
region_push:
    ld a,(reg_n)
    ld e,a
    ld d,0
    ld hl,regs
    ex de,hl
    add hl,hl
    add hl,hl
    add hl,de
    ex de,hl
    ld hl,tmp_reg
    ldi
    ldi
    ldi
    ldi
    ld hl,reg_n
    inc (hl)
    ret
; HL -> (x,y,w,h); add it as a region unless it is empty.
region_add:
    inc hl
    inc hl
    ld a,(hl)
    dec hl
    dec hl
    or a
    ret z
    call rect_to_tmp
    jp region_push
; HL -> region A, DE -> region B (x0,y0,x1,y1). CF = they overlap.
; HL and DE are preserved.
rect_hit:
    push hl
    push de
    inc de
    inc de
    ld a,(de)
    dec de
    dec de
    ld c,a
    ld a,(hl)
    cp c
    jr nc,.no
    inc hl
    inc hl
    ld a,(hl)
    dec hl
    dec hl
    ld c,a
    ld a,(de)
    cp c
    jr nc,.no
    inc hl
    inc de
    inc de
    inc de
    ld a,(de)
    dec de
    dec de
    ld c,a
    ld a,(hl)
    cp c
    jr nc,.no
    ld a,(de)
    inc hl
    inc hl
    ld c,(hl)
    cp c
    jr nc,.no
    pop de
    pop hl
    scf
    ret
.no:
    pop de
    pop hl
    or a
    ret

; HL = four-byte old rectangle (x, y, width, height).
; Rows are copied by an unrolled LDI chain entered at the row width; the row
; counter lives in B' so no memory counter or push/pop per row is needed.
restore_rect:
    ld e,(hl)
    inc hl
    ld c,(hl)
    inc hl
    ld b,(hl)
    inc hl
    ld a,(hl)
    exx
    ld b,a
    exx
    ld a,64
    sub b
    ld (restore_skip+1),a
    ld a,16
    sub b
    add a,a
    push de
    ld e,a
    ld d,0
    ld hl,restore_chain
    add hl,de
    ld (restore_first+1),hl
    ld (restore_next+1),hl
    pop de
    ld l,c
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld d,$20
    add hl,de
    ld a,h
    add a,$66
    ld d,a
    ld e,l
restore_first:
    jp 0
restore_chain:
    DUP 16
    ldi
    EDUP
restore_skip:
    ld bc,0
    add hl,bc
    ex de,hl
    add hl,bc
    ex de,hl
    exx
    dec b
    exx
restore_next:
    jp nz,0
    ret

; HL = entity. Decodes the sprite, clips it, commits the visible rectangle to
; (rect_ptr) and returns HL = first visible source scanline. CF = nothing to draw.
entity_clip:
    ; Read each gameplay field once, without indexed operands.
    ld a,(hl)
    ld (entity_flags),a
    inc hl
    ld a,(hl)
    ld (entity_x),a
    inc hl
    ld a,(hl)
    ld (entity_y),a
    inc hl
    inc hl
    ld a,(hl)
    ld (entity_height),a
    inc hl
    ld a,(hl)
    ld (ink_byte),a
    inc hl
    inc hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld hl,(entity_ptr)
    ld bc,30
    add hl,bc
    ld a,(hl)
    ld (entity_flip),a
    ex de,hl
    ld a,h
    cp $e4
    ret c
    cp $ea
    jr c,.in_range
    scf
    ret
.in_range:
    ld a,(entity_flip)
    bit 7,a
    jr z,.normal
    inc hl
    inc hl
    inc hl
.normal:
    ld a,(hl)
    ld (asset_page),a
    inc hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ld a,(entity_flip)
    bit 7,a
    jr nz,.stride
    inc hl
    inc hl
    inc hl
.stride:
    ld a,(hl)
    or a
    jr nz,.has_stride
    scf
    ret
.has_stride:
    ld (sprite_stride),a
    ; A sprite whose x is a multiple of four needs no shift and no spare
    ; column; every other phase gains one trailing column.
    ld c,a
    ld a,(entity_x)
    and 3
    ld (shift_count),a
    jr z,.whole
    inc c
.whole:
    ld a,c
    ld (cache_stride),a
    ex de,hl
    push hl
    call clip_entity
    pop hl
    ret c
    ; Skip hidden source scanlines before generating any cache bytes.
    ld a,(clip_top)
    or a
    jr z,.source_ready
    ld b,a
    ld a,(sprite_stride)
    ld e,a
    ld d,0
.skip_source:
    add hl,de
    djnz .skip_source
.source_ready:
    or a
    ret

draw_entity:
    call entity_clip
    ret c
    push hl
    call prepare_paint
    pop hl
    ld a,(asset_page)
    call map_asset
    call cache_build
    ld a,(back_page)
    call select_page
    ld a,$b0
    out (2),a
    ; DE = source cache, HL = native destination.
    ld a,(clip_left)
    ld e,a
    ld d,$50
    push de
    ld a,(rect_y)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld a,(rect_x)
    ld e,a
    ld d,$86
    add hl,de
    pop de
    ld a,$90
    out (2),a
    call paint_run
    ld a,$b0
    out (2),a
    ret

; HL = first visible source scanline (in the mapped asset window).
; Builds the mask cache at $5000, one row per visible scanline, rows packed
; back to back. An unshifted sprite is copied by an LDI chain; a shifted one
; goes through the single-table nibble shifter. Row counts live in B'.
cache_build:
    ld a,(shift_count)
    or a
    jr nz,cache_shifted
    ld de,$5000
    ld a,(rect_height)
    exx
    ld b,a
    exx
copy_first:
    jp 0
cache_shifted:
    ld b,h
    ld c,l
    ld hl,$5000
    add a,$ef
    ld d,a
    ld a,(rect_height)
    exx
    ld b,a
    exx
    xor a
    ex af,af'
shift_first:
    jp 0

copy_chain:
    DUP 16
    ldi
    EDUP
    exx
    dec b
    exx
copy_next:
    jp nz,0
    ret

; Output nibble k of a row shifted right by s pixels is
;   ((prev_nibble<<4 | cur_nibble) >> s) & 15,
; and mask bytes are nibble pairs, so w=(prev&$f0)|(cur&$0f) indexes one
; 256-byte table per shift. A' carries the previous source byte.
shift_chain:
    DUP 16
    ld a,(bc)
    inc bc
    ld e,a
    ex af,af'
    xor e
    and $f0
    xor e
    ld e,a
    ld a,(de)
    ld (hl),a
    inc hl
    EDUP
    ex af,af'
    and $f0
    ld e,a
    ld a,(de)
    ld (hl),a
    inc hl
    xor a
    ex af,af'
    exx
    dec b
    exx
shift_next:
    jp nz,0
    ret

; DE = cache, HL = destination, rows in the cache are packed back to back.
paint_run:
    ld a,(rect_height)
    exx
    ld b,a
    exx
    ld a,(ink_byte)
    ld b,a
paint_first:
    jp 0

; Per-sprite patching: pick the kernel for the ink, enter its unrolled chain
; at the row width, and set the row advance constants.
prepare_paint:
    ld a,(rect_width)
    ld c,a
    ld a,16
    sub c
    ld b,a                  ; B = 16 - width = skipped stages
    ld a,64
    sub c
    ld (paint_vskip_a+1),a
    ld (paint_vskip_b+1),a
    ld a,(cache_stride)
    sub c
    ld (paint_sskip+1),a
    ld hl,paint_rowend_a
    jr z,.rowend
    ld hl,paint_rowend_b
.rowend:
    ld (paint_white_end+1),hl
    ld (paint_black_end+1),hl
    ld (paint_colour_end+1),hl
    ld a,(ink_byte)
    or a
    jr z,.black
    inc a
    jr z,.white
    ld a,b                  ; colour stage: 9 bytes
    add a,a
    add a,a
    add a,a
    add a,b
    ld hl,paint_colour_chain
    jr .entry
.white:
    ld a,b                  ; white stage: 5 bytes
    add a,a
    add a,a
    add a,b
    ld hl,paint_white_chain
    jr .entry
.black:
    ld a,b                  ; black stage: 6 bytes
    add a,a
    ld c,a
    add a,a
    add a,c
    ld hl,paint_black_chain
.entry:
    ld e,a
    ld d,0
    add hl,de
    ld (paint_first+1),hl
    ld (paint_next_a+1),hl
    ld (paint_next_b+1),hl
    ; Copy / shift chains are entered at the source row width.
    ld a,(sprite_stride)
    ld c,a
    ld a,16
    sub c
    ld c,a
    ld b,0
    ld a,(shift_count)
    or a
    jr nz,.shift_entry
    ld hl,copy_chain        ; LDI is two bytes
    add hl,bc
    add hl,bc
    ld (copy_first+1),hl
    ld (copy_next+1),hl
    ret
.shift_entry:
    ld h,b                  ; stage is 12 bytes: n*12 = n*8 + n*4
    ld l,c
    add hl,hl
    add hl,hl
    ld d,h
    ld e,l
    add hl,hl
    add hl,de
    ld de,shift_chain
    add hl,de
    ld (shift_first+1),hl
    ld (shift_next+1),hl
    ret

paint_white_chain:
    DUP 16
    ld a,(de)
    or (hl)
    ld (hl),a
    inc de
    inc hl
    EDUP
paint_white_end:
    jp 0
paint_black_chain:
    DUP 16
    ld a,(de)
    cpl
    and (hl)
    ld (hl),a
    inc de
    inc hl
    EDUP
paint_black_end:
    jp 0
; dest = dest ^ ((dest ^ ink) & mask); ink stays in B.
paint_colour_chain:
    DUP 16
    ld a,(de)
    ld c,a
    ld a,(hl)
    xor b
    and c
    xor (hl)
    ld (hl),a
    inc de
    inc hl
    EDUP
paint_colour_end:
    jp 0
paint_rowend_a:
    ld a,l
paint_vskip_a:
    add a,0
    ld l,a
    adc a,h
    sub l
    ld h,a
    exx
    dec b
    exx
paint_next_a:
    jp nz,0
    ret
paint_rowend_b:
    ld a,l
paint_vskip_b:
    add a,0
    ld l,a
    adc a,h
    sub l
    ld h,a
    ld a,e
paint_sskip:
    add a,0
    ld e,a
    adc a,d
    sub e
    ld d,a
    exx
    dec b
    exx
paint_next_b:
    jp nz,0
    ret

; Returns carry when clipped away. Only commit a visible rectangle.
clip_entity:
    ld a,(entity_x)
    rrca
    rrca
    and 63
    ld b,a
    ld a,(cache_stride)
    ld c,a
    xor a
    ld (clip_left),a
    ld a,(entity_flags)
    bit 7,a
    jr z,.right
    ld a,b
    sub 64
    neg
    ld (clip_left),a
    ld b,a
    ld a,c
    sub b
    jr z,.hidden
    jr c,.hidden
    ld c,a
    ld b,0
.right:
    ld a,b
    add a,c
    cp 65
    jr c,.width
    ld a,64
    sub b
    ld c,a
.width:
    ld a,b
    ld (rect_x),a
    ld a,c
    ld (rect_width),a
    ld a,(entity_y)
    ld b,a
    ld a,(entity_height)
    ld c,a
    xor a
    ld (clip_top),a
    ld a,b
    cp 192
    jr c,.bottom
    neg
    ld (clip_top),a
    ld b,a
    ld a,c
    sub b
    jr c,.hidden
    jr z,.hidden
    ld c,a
    ld b,0
.bottom:
    ld a,b
    cp 168
    jr nc,.hidden
    add a,c
    cp 169
    jr c,.height
    ld a,168
    sub b
    ld c,a
.height:
    ld a,b
    ld (rect_y),a
    ld a,c
    ld (rect_height),a
    ld hl,(rect_ptr)
    ld a,(rect_x)
    ld (hl),a
    inc hl
    ld a,(rect_y)
    ld (hl),a
    inc hl
    ld a,(rect_width)
    ld (hl),a
    inc hl
    ld a,(rect_height)
    ld (hl),a
    or a
    ret
.hidden:
    scf
    ret

stars_init:
    ld a,($5b04)
    cp 16
    ret nc
    ld hl,$5d59
    ld b,16
.loop:
    push bc
    push hl
    ld a,(hl)
    ld c,a
    and 31
    add a,a
    inc a
    ld e,a
    ld a,c
    and $e0
    rrca
    rrca
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld d,$20
    add hl,de
    ld a,(hl)
    and $77
    or $88
    ld (hl),a
    pop hl
    inc hl
    pop bc
    djnz .loop
    ret
stars_tick:
    ld a,($5b0a)
    bit 5,a
    ret nz
    ld a,($5b04)
    cp 16
    ret nc
    ld a,r
    and 15
    ld l,a
    ld h,0
    ld de,$5d59
    add hl,de
    ld c,(hl)
    ld a,c
    and 31
    add a,a
    inc a
    ld e,a
    ld a,c
    and $e0
    rrca
    rrca
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld d,$20
    add hl,de
    ld a,r
    and 3
    ld d,a
    xor a
    bit 0,d
    jr z,.c2
    or $80
.c2:
    bit 1,d
    jr z,.put
    or 8
.put:
    ld e,a
    ld a,(hl)
    and $77
    or e
    ld (hl),a
    ld b,1
    ld c,1
    call copy_dual_rect
    ret

sky_clear:
    ldir
    push hl
    push de
    push bc
    ld hl,$2000
    ld de,$2001
    ld bc,$bff
    ld (hl),0
    ldir
    pop bc
    pop de
    pop hl
    exx
    ret
native_digit:
    push bc
    push hl
    push de
    and 15
    add a,42
    ld hl,(font_id)
    push hl
    ld hl,4
    ld (font_id),hl
    call print_char
    pop hl
    ld (font_id),hl
    pop de
    inc d
    pop hl
    pop bc
    ret
native_bar:
    ld a,(bar_key+4)
    or a
    jr z,.draw
    ld a,(bar_key+2)
    cp b
    jr nz,.draw
    ld a,(bar_key+3)
    cp c
    jr nz,.draw
    ld a,(bar_key)
    cp l
    jr nz,.draw
    ld a,(bar_key+1)
    cp h
    jp z,$9b41              ; same bar already on screen
.draw:
    ld (bar_key),hl
    ld a,b
    ld (bar_key+2),a
    ld a,c
    ld (bar_key+3),a
    ld a,1
    ld (bar_key+4),a
    push ix
    ld de,$a2e7
    add hl,de
    add hl,hl
    ld de,$f600
    add hl,de
    ld a,b
    call expand_keep
    ld (bar_masks),de
    ld a,c
    call expand_keep
    ld (bar_masks+2),de
    ld de,$4c22
    ld b,8
.row:
    push bc
    ld ix,bar_masks
    ld b,4
.byte:
    ld a,(hl)
    inc hl
    and (ix+0)
    and $0f
    ld (de),a
    inc de
    inc ix
    djnz .byte
    push hl
    ld hl,60
    add hl,de
    ex de,hl
    pop hl
    pop bc
    djnz .row
    ld hl,$4c22
    ld b,8
    ld c,4
    call copy_dual_rect
    pop ix
    jp $9b41
; Expand a logical eight-cell keep bitfield into two native plane masks.
expand_keep:
    push bc
    ld b,a
    and 15
    ld c,a
    rlca
    rlca
    rlca
    rlca
    or c
    ld d,a
    ld a,b
    and $f0
    ld c,a
    rrca
    rrca
    rrca
    rrca
    or c
    ld e,a
    pop bc
    ret
native_column:
    add a,a
    add a,e
    ld e,a
    ld a,b
    ret
native_erosion:
    push de
    call expand_keep
    ld (bar_masks),de
    pop hl
    push hl
    ld b,2
.row:
    push hl
    ld a,(bar_masks)
    and (hl)
    ld (hl),a
    inc hl
    ld a,(bar_masks+1)
    and (hl)
    ld (hl),a
    pop hl
    ld de,64
    add hl,de
    djnz .row
    pop hl
    ld b,2
    ld c,2
    call copy_dual_rect
    pop de
    pop hl
    ret
bar_masks: defs 4,0

collection_pair:
    push hl
    push bc
    ld l,a
    ld h,HIGH material_colours
    ld a,(hl)
    ld (de),a
    pop bc
    pop hl
    ret
refresh_hud:
    ld a,(hud_dirty)
    or a
    jr nz,.go
    ld a,(hud_tick)         ; no flagged change: still rescan every 4th frame
    inc a                   ; (direct attribute writers that do not set the flag)
    ld (hud_tick),a
    and 3
    ret nz
.go:
    xor a
    ld (hud_dirty),a
    ld hl,(font_id)
    push hl
    ld hl,4
    ld (font_id),hl
    ld hl,$57a0             ; shown text ($57a0+i) vs drawn text ($58a0+i)
    ld b,96
.scan:
    ld a,(hl)
    inc h
    cp (hl)
    ld h,$57                ; LD leaves the compare flags intact
    jr nz,.diff
.next:
    inc l
    djnz .scan
    pop hl
    ld (font_id),hl
    ret
.diff:
    push hl
    ld a,l
    add a,$a0               ; new text lives at $5840+i = $57a0+i+$a0
    ld l,a
    ld a,h
    adc a,0
    ld h,a
    ld a,(hl)
    pop hl
    cp $ff
    jr z,.next
    push bc
    push hl
    ld c,a
    ld a,96
    sub b
    ld d,a
    and 31
    ld l,a
    ld a,d
    rrca
    rrca
    rrca
    rrca
    rrca
    and 3
    add a,21
    ld e,a
    ld d,l
    ld a,c
    call print_char
    pop hl
    pop bc
    jr .next
font_id: dw 4

native_tick_tail:
    call stars_tick
    call sound_tick
    jp $9cb3
frame:
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    call $9c77
    call refresh_hud
    call compose
.done:
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ld a,($5b0c)
    ret
menu_wait:
.wait:
    call $8704
    jr z,.wait
    xor a
    ld (key_latch),a
    ld a,1
    out (6),a
    ld a,$81
    ld ($5b0b),a
    jp $863a
gameover_wait:
.wait:
    call $870d
    jr z,.wait
    xor a
    ld (key_latch),a
    ld a,1
    out (6),a
    jp $7da5
break_test:
    scf
    ret
; All scan routines preserve the original Kempston gameplay interface.
read_joystick:
    call scan_controls
    push bc
    ld b,a
    ld a,(key_latch)
    or b
    and $1f
    ld (hl),a
    ld b,a
    xor a
    ld (key_latch),a
    ld a,b
    and $1f
    pop bc
    ret

scan_controls:
    push bc
    ld a,8
    out (3),a
    in a,($58)
    ld b,a
    ld c,0
    bit 5,b
    jr nz,.left
    set 0,c
.left:
    bit 6,b
    jr nz,.down
    set 1,c
.down:
    bit 2,b
    jr nz,.up
    set 2,c
.up:
    bit 1,b
    jr nz,.fire
    set 3,c
.fire:
    bit 3,b
    jr nz,.space
    set 4,c
.space:
    ld a,7
    out (3),a
    in a,($58)
    bit 5,a
    jr nz,.qa
    set 4,c
.qa:
    ld a,2
    out (3),a
    in a,($58)
    bit 6,a                ; Q: up / mole
    jr nz,.tab
    set 3,c
.tab:
    bit 3,a                ; native TVC Tab
    jr nz,.a
    set 4,c
.a:
    ld a,4
    out (3),a
    in a,($58)
    bit 6,a                ; A: down
    jr nz,.op
    set 2,c
.op:
    ld a,3
    out (3),a
    in a,($58)
    bit 2,a                ; O: left
    jr nz,.p
    set 1,c
.p:
    bit 6,a                ; P: right
    jr nz,.enter
    set 0,c
.enter:
    ld a,5
    out (3),a
    in a,($58)
    bit 4,a
    jr nz,.done
    set 4,c
.done:
    ld a,c
    pop bc
    ret

poll_controls:
    call scan_controls
    push bc
    ld b,a
    ld a,(key_latch)
    or b
    ld (key_latch),a
    pop bc
    ret

; Menu: any physical key, including 1..4, Space, Enter and joystick.
any_key:
    push bc
    ld b,9
    ld c,0
.loop:
    ld a,b
    dec a
    out (3),a
    in a,($58)
    cpl
    or c
    ld c,a
    djnz .loop
    ld a,c
    or a
    pop bc
    ret


 ; TVC CRTC cursor output is wired to the frame interrupt latch (59h bit 4).
; Put its single scanline at the final character of visible scanline 239.
; Poll the latch with interrupts disabled; audio interrupt generation is off.
initialise_sync:
    ld hl,sync_registers
    ld b,4
.setup:
    ld a,(hl)
    inc hl
    out ($70),a
    ld a,(hl)
    inc hl
    out ($71),a
    djnz .setup
    xor a
    ld (sync_available),a
    out (7),a
    call wait_frame_latch
    ret nz
    ld a,1
    ld (sync_available),a
    ret
synchronise_frame:
    ld a,(sync_available)
    or a
    ret z
    xor a
    out (7),a
    call wait_frame_latch
    ret
wait_frame_latch:
    ld bc,$2000
.wait:
    in a,($59)
    and $10
    ret z
    dec bc
    ld a,b
    or c
    jr nz,.wait
    ; A missing latch must never hang keyboard input or rendering.
    or 1
    ret
sync_registers: db 10,3,11,3,14,$0e,15,$ff
sync_available: db 0

select_page:
    push hl
    ld hl,display_page
    or (hl)
    out (12),a
    pop hl
    ret
map_asset:
    cp $ff
    jr z,.ram
    call select_page
    ld a,$90
    out (2),a
    ret
.ram:
    ld a,$b0
    out (2),a
    ret
old_rectangles:
    ld hl,$5800
    ld a,(back_page)
    or a
    ret z
    ld hl,$5900
    ret
flip_buffers:
    call synchronise_frame
    ld a,(back_page)
    add a,a
    add a,a
    ld (display_page),a
    ld a,(back_page)
    xor 12
    ld (back_page),a
    call select_page
    ret
; Remember a background->page write so a clean sprite under it gets redrawn.
; Both video pages receive the write, so both pending lists record it. The
; status area below the sprite field (y >= 168) is never covered by a sprite.
ext_note:
    ld hl,(copy_src)
    ld a,l
    and 63
    ld c,a
    ld a,l
    rlca
    rlca
    and 3
    ld b,a
    ld a,h
    sub $20
    add a,a
    add a,a
    or b
    cp 168
    ret nc
    ld b,a
    ld (en_rect+1),a
    ld a,c
    ld (en_rect),a
    ld a,(copy_width)
    add a,c
    ld (en_rect+2),a
    ld a,(copy_height)
    add a,b
    ld (en_rect+3),a
    ld a,(ext_n)
    ld hl,ext0
    call ext_add
    ld (ext_n),a
    ld a,(ext_n+1)
    ld hl,ext1
    call ext_add
    ld (ext_n+1),a
    ret
; A = count (255 = overflow, everything is dirty), HL = list. Returns new count.
ext_add:
    cp 8
    jr nc,.full
    push af
    ld e,a
    ld d,0
    ex de,hl
    add hl,hl
    add hl,hl
    add hl,de
    ex de,hl
    ld hl,en_rect
    ldi
    ldi
    ldi
    ldi
    pop af
    inc a
    ret
.full:
    ld a,255
    ret
; HL=linear background, B=height, C=width. Preserve every caller register.
copy_dual_rect:
    push af
    push bc
    push de
    push hl
    ld (copy_src),hl
    ld a,b
    ld (copy_height),a
    ld a,c
    ld (copy_width),a
    ld (.wi+1),a
    ld a,64
    sub c
    ld (.di+1),a
    call ext_note
    ld a,$90
    out (2),a
    xor a
    call select_page
    call .page
    ld a,12
    call select_page
    call .page
    ld a,(back_page)
    call select_page
    ld a,$b0
    out (2),a
    pop hl
    pop de
    pop bc
    pop af
    ret
.page:
    ld hl,(copy_src)
    ld de,$6600
    add hl,de
    ex de,hl
    ld hl,(copy_src)
    ld a,(copy_height)
.line:
.wi:
    ld c,0                  ; row width, patched per call
    ld b,0
    ldir
.di:
    ld bc,0                 ; 64 - width, patched per call
    add hl,bc
    ex de,hl
    add hl,bc
    ex de,hl
    dec a
    jr nz,.line
    ret
copy_src: dw 0
copy_height: db 0
copy_width: db 0
display_page: db 0
back_page: db 12

glyph_index: db 0
asset_page: db 0
tile_flags: db 0
ink_byte: db 0
paper_byte: db 0
pixel_temp: db 0
sprite_stride: db 0
cache_stride: db 0
shift_count: db 0
shift_carry: db 0
rows_left: db 0
bytes_left: db 0
clip_left: db 0
clip_top: db 0
key_latch: db 0
    ALIGN 256
native_pairs:
    db 0,$f0,$0f,$ff,0,$f0,$0f,$ff,0,$f0,$0f,$ff,0,$f0,$0f,$ff

; ---------------------------------------------------------------------------
; Game-logic fast paths (bit-exact replacements for original Spectrum loops).
; MovingObjects: 94 records of 8 bytes; byte 7 bit 7 = object exists.
MOVING_OBJECTS EQU $AAED
; Live-object list: the "exists" bit (byte 7, bit 7) only changes when the
; original room-change code ($AA25..$AA6D) recomputes it, so the indices of the
; existing objects are collected once, right after that loop ($AA6D hook), and
; both per-frame passes walk only those entries.
LIVE_VALID EQU $9800            ; list built since the last recompute
LIVE_END   EQU $9801            ; low byte of the end of the list
LIVE_P2    EQU $9808            ; pass 2 cursor (low byte)
LIVE_LIST  EQU $9810            ; ascending object indices
logic_rebuild_exit:
    call live_build
    exx
    ex af,af'
    ret
live_build:
    ld hl,MOVING_OBJECTS+7
    ld de,LIVE_LIST
    ld bc,$5e00
.s:
    bit 7,(hl)
    jr z,.n
    ld a,c
    ld (de),a
    inc e
.n:
    ld a,8
    add a,l
    ld l,a
    adc a,h
    sub l
    ld h,a
    inc c
    djnz .s
    ld a,e
    ld (LIVE_END),a
    ld a,1
    ld (LIVE_VALID),a
    ret
; Pass 1 of the per-frame object update (original $A491..$A4BA).
logic_pass1:
    ld a,(LIVE_VALID)
    or a
    call z,live_build
    ld hl,LIVE_LIST
.loop:
    ld a,(LIVE_END)
    cp l
    jr z,.end
    ld a,(hl)
    inc l
    push hl
    ld e,a
    ld d,0
    ld hl,$e180
    add hl,de               ; HL = $E180 + index
    ex de,hl                ; DE = timer, HL = index
    add hl,hl
    add hl,hl
    add hl,hl
    ld bc,MOVING_OBJECTS
    add hl,bc
    push hl
    pop iy                  ; IY = object record
    ex de,hl
    res 7,(iy+1)
    bit 7,(hl)
    jr z,.skip
    set 7,(iy+1)
    call $a8ac
.skip:
    pop hl
    jr .loop
.end:
    ld iy,MOVING_OBJECTS+$5e*8
    jp $a4bb
; Pass 2 loop head (original $A4D5): jump straight to the next existing object
; and continue at the original body ($A4E3). B = 94 - index on entry of the
; first call, DE = 8.
logic_pass2:
    ld a,b
    cp $5e
    jr nz,.next
    ld a,LOW LIVE_LIST
    ld (LIVE_P2),a
.next:
    ld a,(LIVE_P2)
    ld l,a
    ld h,HIGH LIVE_LIST
    ld a,(LIVE_END)
    cp l
    jp z,$a594
    ld c,(hl)
    inc l
    ld a,l
    ld (LIVE_P2),a
    ld a,$5e
    sub c
    ld b,a                  ; B = 94 - index
    ld l,c
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld de,MOVING_OBJECTS
    add hl,de
    push hl
    pop iy
    ld de,8
    ld a,b
    inc a
    ld ($5b12),a
    push bc
    push de
    jp $a4e3
; Interrupt-tick countdown of the $E180 timer table (original $9CC7).
logic_counters:
    ld hl,$e180
    ld b,64
.row:
    DUP 2
    ld a,(hl)
    or a
    jp m,$+5
    dec a
    ld (hl),a
    inc l
    EDUP
    djnz .row
    jp $9cd4                ; the original continues with the $FC0B timers
    ALIGN 256
material_colours:
    db 0,1,2,1,2,1,2,3

; ---------------------------------------------------------------------------
; Menu / game-over tune: replaces the loop of the original two-channel beeper
; routine (entered at $876E). The original loop costs 77 T-states per step on a
; 3.5 MHz Spectrum (22.0 us); on the TVC (3.125 MHz) the step must be ~68.75 T.
; The level is written to the volume DAC only at edges; the base step is padded
; to 67 T so that the average step with edge cost stays near 22 us.
; Inputs are the original self-modified bytes: $8773/$877A channel masks,
; $8775/$877C reload values; B, C = channel counters, HL = duration.
music_tone:
    ld a,($8773)
    or a
    jr z,.m1
    ld a,$3c
.m1:
    ld (.x1+1),a
    ld a,($877a)
    or a
    jr z,.m2
    ld a,$3c
.m2:
    ld (.x2+1),a
    ld a,($8775)
    ld (.r1+1),a
    ld a,($877c)
    ld (.r2+1),a
    ld a,1
    out (6),a
.l:
    dec b
    jr nz,.c
.r1:
    ld b,0
.x1:
    xor 0
    out (6),a
.c:
    dec c
    jr nz,.t
.r2:
    ld c,0
.x2:
    xor 0
    out (6),a
.t:
    jr $+2                  ; timing pad (12 T)
    ld e,(hl)               ; timing pad (7 T)
    dec l
    jr nz,.l
    push af                 ; every 256 steps: remember a pressed key
    call any_key
    push hl
    ld hl,key_latch
    or (hl)
    ld (hl),a
    pop hl
    pop af
    inc h
    dec h
    jr z,.end
    dec h
    jr .l
.end:
    ld a,1
    out (6),a
    ret
; Native glyph/tile asset lookup. Original font identifier is only an ID.
; OUT: HL=bank address, A=CPU bank register, C=native record length.
font_lookup:
    ld hl,$eb00
    ld de,(font_id)
.loop:
    ld a,(hl)
    inc hl
    cp e
    jr nz,.skiplo
    ld a,(hl)
    cp d
    jr z,.found
.skiplo:
    ld bc,6
    add hl,bc
    jr .loop
.found:
    inc hl
    ld a,(hl)
    inc hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ld c,(hl)
    ex de,hl
    ret
; Replaces "LD A,(HL) / XOR 3 / LD (HL),A" at $9B5F: the original flips a HUD
; attribute directly, so tell refresh_hud to rescan.
hud_flip:
    ld a,(hl)
    xor 3
    ld (hl),a
    ld a,1
    ld (hud_dirty),a
    ret
    ALIGN 256
reverse_table:
    DUP 256, V
    db ((V & $88)>>3)|((V & $44)>>1)|((V & $22)<<1)|((V & $11)<<3)
    EDUP
entity_ptr: dw 0
rect_ptr: dw 0
entity_flags: db 0
entity_x: db 0
entity_y: db 0
entity_height: db 0
entity_flip: db 0
rect_x: db 0
rect_y: db 0
rect_width: db 0
rect_height: db 0
music_key:
    call any_key
    push hl
    ld hl,key_latch
    or (hl)
    pop hl
    ret z
    ld a,1
    ret
; Gameplay retains the original event flags. Hardware tone costs no busy loop.
sound_tick:
    ld a,($9c82)
    or a
    jr z,.short
    add a,8
    ld ($9c82),a
    ld l,a
    ld h,15
    jr .play
.short:
    ld a,($9ca5)
    or a
    jr z,.stop
    ld l,a
    ld h,14
    xor a
    ld ($9ca5),a
.play:
    ld a,l
    out (4),a
    ld a,h
    or $10
    out (5),a
    ld a,$29
    out (6),a
    ret
.stop:
    xor a
    out (5),a
    ld a,1
    out (6),a
    ret

needs_rle:
    INCBIN "../build/needs_128k.rle"
; Run-time state, not part of the loaded image: cleared by clear_native.
; Page aligned so that per-entity tables can be walked with 8-bit arithmetic.
bss EQU ($+255)&$ff00
sig0 EQU bss                    ; 16 x 8 image signatures per video page
sig1 EQU bss+128
dirty EQU bss+256               ; 16 flags, low byte 0..15
newr EQU bss+320                ; 16 x (x,y,w,h) probe rectangles
regs EQU bss+384                ; up to 56 regions of (x0,y0,x1,y1)
ext0 EQU bss+608                ; pending external writes per page
ext1 EQU bss+640
ext_n EQU bss+672               ; counts (255 = overflow)
reg_n EQU bss+674
changed_flag EQU bss+675
tmp_reg EQU bss+676
en_rect EQU bss+680
bar_key EQU bss+684               ; HL,B,C of the last drawn bar + valid flag
hud_dirty EQU bss+689
hud_tick EQU bss+690
bss_end EQU bss+691
    ASSERT bss_end <= $1f00
