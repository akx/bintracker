(import scheme (chicken base) test schemta)

(define (run-src src)
  (map char->integer (assemble 'm6502 src)))

(test-group
 "Addressing Modes"

 (test "immediate" '(#x69 #xff) (run-src " adc #$ff"))
 (test "zeropage" '(#x65 #xff) (run-src " adc $ff"))
 (test "zeropage,x" '(#x75 #xff) (run-src " adc $ff,x"))
 (test "absolute" '(#x6d #xfe #xff) (run-src " adc $fffe"))
 (test "absolute,x" '(#x7d #xfe #xff) (run-src " adc $fffe,x"))
 (test "absolute,y" '(#x79 #xfe #xff) (run-src " adc $fffe,y"))
 (test "indirect,x" '(#x61 #xff) (run-src " adc ($ff,x)"))
 (test "indirect,y" '(#x71 #xff) (run-src " adc ($ff),y")))

(test-group
 "Instructions"

 (test "adc" '(#x69 #xff) (run-src " adc #$ff"))
 (test "ahx" '(#x93 #xff) (run-src " ahx ($ff),y"))
 (test "and" '(#x29 #xff) (run-src " and #$ff"))
 (test "anc" '(#x0b #xff) (run-src " anc #$ff"))
 (test "alr" '(#x4b #xff) (run-src " alr #$ff"))
 (test "arr" '(#x6b #xff) (run-src " arr #$ff"))
 (test "asl" '(#x0a) (run-src " asl a"))
 (test "aso" '(#x07 #xff) (run-src " aso $ff"))
 (test "axs" '(#xcb #xff) (run-src " axs #$ff"))
 (test "bit" '(#x24 #xff) (run-src " bit $ff"))
 (test "bcc" '(#x90 #x80) (run-src " bcc -128"))
 (test "bcs" '(#xb0 #x80) (run-src " bcs -128"))
 (test "beq" '(#xf0 #x80) (run-src " beq -128"))
 (test "bmi" '(#x30 #x80) (run-src " bmi -128"))
 (test "bne" '(#xd0 #x80) (run-src " bne -128"))
 (test "bpl" '(#x10 #x80) (run-src " bpl -128"))
 (test "bvc" '(#x50 #x80) (run-src " bvc -128"))
 (test "bvs" '(#x70 #x80) (run-src " bvs -128"))
 (test "brk" '(#x00) (run-src " brk"))
 (test "clc" '(#x18) (run-src " clc"))
 (test "cld" '(#xd8) (run-src " cld"))
 (test "cli" '(#x58) (run-src " cli"))
 (test "clv" '(#xb8) (run-src " clv"))
 (test "cmp" '(#xc9 #xff) (run-src " cmp #$ff"))
 (test "cpx" '(#xe0 #xff) (run-src " cpx #$ff"))
 (test "cpy" '(#xc0 #xff) (run-src " cpy #$ff"))
 (test "dcp" '(#xc7 #xff) (run-src " dcp $ff"))
 (test "dec" '(#xc6 #xff) (run-src " dec $ff"))
 (test "dex" '(#xca) (run-src " dex"))
 (test "dey" '(#x88) (run-src " dey"))
 (test "eor" '(#x49 #xff) (run-src " eor #$ff"))
 (test "hlt" '(#x02) (run-src " hlt"))
 (test "inc" '(#xe6 #xff) (run-src " inc $ff"))
 (test "inx" '(#xe8) (run-src " inx"))
 (test "iny" '(#xc8) (run-src " iny"))
 (test "isb" '(#xe7 #xff) (run-src " isb $ff"))
 (test "isc" '(#xe7 #xff) (run-src " isc $ff"))
 (test "jmp" '(#x4c #xfe #xff) (run-src " jmp $fffe"))
 (test "jsr" '(#x20 #xfe #xff) (run-src " jsr $fffe"))
 (test "lar" '(#xbb #xfe #xff) (run-src " lar $fffe,y"))
 (test "las" '(#xbb #xfe #xff) (run-src " las $fffe,y"))
 (test "lax" '(#xab #xff) (run-src " lax #$ff"))
 (test "lda" '(#xa9 #xff) (run-src " lda #$ff"))
 (test "ldx" '(#xb6 #xff) (run-src " ldx $ff,y"))
 (test "ldy" '(#xb4 #xff) (run-src " ldy $ff,x"))
 (test "lse" '(#x47 #xff) (run-src " lse $ff"))
 (test "lsr" '(#x4a) (run-src " lsr a"))
 (test "kil" '(#x02) (run-src " kil"))
 (test "nop" '(#xea) (run-src " nop"))
 (test "ora" '(#x09 #xff) (run-src " ora #$ff"))
 (test "rla" '(#x27 #xff) (run-src " rla $ff"))
 (test "rol" '(#x2a) (run-src " rol a"))
 (test "ror" '(#x6a) (run-src " ror a"))
 (test "rla" '(#x67 #xff) (run-src " rra $ff"))
 (test "rti" '(#x40) (run-src " rti"))
 (test "rts" '(#x60) (run-src " rts"))
 (test "pha" '(#x48) (run-src " pha"))
 (test "php" '(#x08) (run-src " php"))
 (test "pla" '(#x68) (run-src " pla"))
 (test "plp" '(#x28) (run-src " plp"))
 (test "sax" '(#x87 #xff) (run-src " sax $ff"))
 (test "sbc" '(#xe9 #xff) (run-src " sbc #$ff"))
 (test "sec" '(#x38) (run-src " sec"))
 (test "sed" '(#xf8) (run-src " sed"))
 (test "sei" '(#x78) (run-src " sei"))
 (test "shx" '(#x9e #xfe #xff) (run-src " shx $fffe,y"))
 (test "shy" '(#x9c #xfe #xff) (run-src " shy $fffe,x"))
 (test "slo" '(#x07 #xff) (run-src " slo $ff"))
 (test "sre" '(#x47 #xff) (run-src " sre $ff"))
 (test "sta" '(#x85 #xff) (run-src " sta $ff"))
 (test "stx" '(#x96 #xff) (run-src " stx $ff,y"))
 (test "sty" '(#x94 #xff) (run-src " sty $ff,x"))
 (test "tas" '(#x9b #xfe #xff) (run-src " tas $fffe,y"))
 (test "tax" '(#xaa) (run-src " tax"))
 (test "tay" '(#xa8) (run-src " tay"))
 (test "tsx" '(#xba) (run-src " tsx"))
 (test "txa" '(#x8a) (run-src " txa"))
 (test "txs" '(#x9a) (run-src " txs"))
 (test "tya" '(#x98) (run-src " tya"))
 (test "xaa" '(#x8b #xff) (run-src " xaa #$ff")))

(test-exit)
