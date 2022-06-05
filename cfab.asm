.text
.global _main
.align 8


_main:
    stp     fp, lr, [sp, #-16]!     ; preserve
    stp     x27, x28, [sp, #-16]!   ; preserve
    stp     x25, x26, [sp, #-16]!   ; preserve
    stp     x23, x24, [sp, #-16]!   ; preserve
    stp     x21, x22, [sp, #-16]!   ; preserve
    stp     x19, x20, [sp, #-16]!   ; preserve
    add     fp, sp, #96             ; update stack frame pointer

    bl      count_ways              ; get 'er done

 exit_cfab:
    ldp     x19, x20, [sp], #16     ; restore
    ldp     x21, x22, [sp], #16     ; restore
    ldp     x23, x24, [sp], #16     ; restore
    ldp     x25, x26, [sp], #16     ; restore
    ldp     x27, x28, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore
    mov     x0, xzr                 ; return code
    mov     x16, #1                 ; return control to supervisor
    svc     0xffff


print:
    mov     x0, #1
    mov     x16, 4
    svc     #0xffff
    ret

;; Print value in x0 as an unisgned int to STDOUT
;; When x1 == 1 right justify in a 5 byte field padded with 0x20
;; x19 radix/divisor
;; x20 digit string index
;; x21 work register, starts with subject for printing
;; x22 work register, quotient
;; x23 remainder
;; x24 copy of sp
;; x25 workarea base

.align 8
printUInt:
    stp     fp, lr, [sp, #-16]!     ; preserve
    stp     x25, x26, [sp, #-16]!   ; preserve
    stp     x23, x24, [sp, #-16]!   ; preserve
    stp     x21, x22, [sp, #-16]!   ; preserve
    stp     x19, x20, [sp, #-16]!   ; preserve
    sub     sp, sp, #128            ; move stack pointer down 128 bytes, space for digit string
    add     fp, sp, #208            ; define frame

    mov     x25, xzr                ; use as a flag 0 == normal, otherwise right justify
    cmp     x1, #1                  ; padding requested?
    b.ne    normal                  ; nope, regular processing
    add     x25, sp, #80            ; point to top of workarea
    mov     x26, #15                ; size of spaces
    mov     x22, #32                ; put a blank in lsb
init_loop:
    strb    w22, [x25, x26]         ; another blank
    subs    x26, x26, #1            ; move left a byte
    b.ge    init_loop
normal:
    mov     x19, #10                ; x19 will contain the divisor (10) used in udiv and msub
    mov     x20, xzr                ; x20 counts the number of digits stored on stack
    mov     x21, x0                 ; move input parameter to work register
    mov     x24, sp                 ; copy stack pointer for writing string

    cmp     x0, xzr                 ; if x0 is zero then the division algorith will not work
    b.eq    printUInt_Zero          ; we set the value on the stack to 0

printUInt_Count:
    add     x20, x20, #1            ; increment the digit counter/index (x20)
    udiv    x22, x21, x19           ; divide x21 by 10, x22 gets quotient
    msub    x23, x22, x19, x21      ; obtain the remainder (x23) and the Quotient (x22)
    add     w23, w23, #0x30         ; add 48 to the number, turning it into an ASCII char 0-9
    strb    w23, [x24, x20]         ; build string on the stack one byte at a time
    cmp     x22, xzr                ; done?
    b.eq    printUInt_print         ; yessir
    mov     x21, x22                ; copy the Quotient (x22) into x21 which is the new value to divide by 10
    b       printUInt_Count         ; if x21 is not yet zero than there's more digits to extract

;; Using the stack guarantees that the digits are printed start with the most significant digit
printUInt_print:
    cmp     x25, xzr                ; pad?
    b.gt    pad                     ; yep
    add     x20, x20, #1            ; increment the digit counter/index (x20)
    add     x1, sp, x20             ; sp + string length
printUInt_print_loop:
    cmp     x20, #1                 ; done?
    b.eq    printUInt_exit          ; all done
    sub     x20, x20, #1            ; decrement index
    add     x1, sp, x20             ; digit index + sp = address
    mov     x2, #1                  ; string length
    bl      print                   ; digit to STDOUT
    b       printUInt_print_loop    ; once more to the breach

printUInt_exit:
    add     sp, sp, #128            ; return string work area
    ldp     x19, x20, [sp], #16     ; restore
    ldp     x21, x22, [sp], #16     ; restore
    ldp     x23, x24, [sp], #16     ; restore
    ldp     x25, x26, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore
    ret                             ; return

pad:
;; move ascii number to bottom half of spaces
    add     x26, x25, #15           ; last byte of spaces
    sub     x26, x26, x20           ; first byte of number
pad_loop:
    ldrb    w21, [sp, x20]
    strb    w21, [x26]              ; move to workarea for printing
    add     x26, x26, #1
    subs    x20, x20, #1            ; decrement index
    b.gt    pad_loop                ; keep on truckn
    add     x1, x25, #10            ; output area
    mov     x2, #5                  ; string size
    bl      print
    b       printUInt_exit          ; get out

printUInt_Zero:                     ; this is the exceptional case when x21 is 0 then we need to push this ourselves to the stack
    mov     w21, #0x030             ; move "0" to w21
    add     x20, x20, #1            ; increment the digit counter/index (x20)
    strb    w21, [sp, x20]          ; push digit so that it can be printed to the screen
    b       printUInt_print
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


count_ways:
;   x19     count
;   x20     halves
;   x21     quarters
;   x22     dimes
;   x23     nickles
;   x24     cents
;   x25     sum
;   x26     top of workarea

    stp     fp, lr, [sp, #-16]!     ; preserve
    stp     x25, x26, [sp, #-16]!   ; preserve
    stp     x23, x24, [sp, #-16]!   ; preserve
    stp     x21, x22, [sp, #-16]!   ; preserve
    stp     x19, x20, [sp, #-16]!   ; preserve
    add     fp, sp, #80             ; update stack frame pointer

    mov     x19, xzr                ; init count
    mov     x20, xzr                ; init halves
    mov     x21, xzr                ; init quarters
    mov     x22, xzr                ; init dimes
    mov     x23, xzr                ; init nickles
    mov     x24, xzr                ; init cents

sum:
    mov     x25, x20                ; init sum with halves
    add     x25, x25, x21           ; add quarters
    add     x25, x25, x22           ; add dimes
    add     x25, x25, x23           ; add nickles
    add     x25, x25, x24           ; add cents
    cmp     x25, #100               ; a hit?
    b.gt    reset_cents             ; next!
    b.eq    hit                     ; bingo
    add     x24, x24, #5            ; bump cents
    cmp     x24, #100               ; there yet?
    b.le    sum                     ; nope
reset_cents:
    mov     x24, xzr                ; reset cents
    add     x23, x23, #5            ; bump nickles
    cmp     x23, #100               ; there yet?
    b.le    sum                     ; nope
    mov     x23, xzr                ; reset nickles
    add     x22, x22, #10           ; bump dimes
    cmp     x22, #100               ; there yet?
    b.le    sum                     ; nope
    mov     x22, xzr                ; reset dimes
    add     x21, x21, #25           ; bump quarters
    cmp     x21, #100               ; there yet?
    b.le    sum                     ; nope
    mov     x21, xzr                ; reset quarters
    add     x20, x20, #50           ; bump halves
    cmp     x20, #100               ; done?
    b.le    sum                     ; nope

    adr     x26, lit_pool       ; address of literals
    mov     x1, x26                 ; for write
    mov     x2, #11                 ; of this many bytes
    bl      print

    mov     x0, x19                 ; setup count for print
    mov     x1, xzr                 ; no padding
    bl      printUInt               ; print count

    add     x1, x26, #10            ; end of string
    mov     x2, #35                 ; string size
    bl      print

    ldp     x19, x20, [sp], #16     ; restore
    ldp     x21, x22, [sp], #16     ; restore
    ldp     x23, x24, [sp], #16     ; restore
    ldp     x25, x26, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore
    ret

lit_pool:   .ascii  "\nThere are ways to make change for a buck.\n"

.align 8
hit:
    add     x19, x19, #1            ; bump count
    bl      print_line
    b       reset_cents             ; continue


print_line:
;   x19     count
;   x20     halves
;   x21     quarters
;   x22     dimes
;   x23     nickles
;   x24     cents
    stp     fp, lr, [sp, #-16]!     ; preserve
    stp     x27, x28, [sp, #-16]!   ; preserve
    stp     x25, x26, [sp, #-16]!   ; preserve
    stp     x23, x24, [sp, #-16]!   ; preserve
    stp     x21, x22, [sp, #-16]!   ; preserve
    stp     x19, x20, [sp, #-16]!   ; preserve
    add     fp, sp, #96             ; define stack frame

    adr     x25, lit_pool
    add     x25, x25, #42           ; new line address

    mov     x0, x19                 ; line number
    mov     x1, #1                  ; request padding
    bl      printUInt

    mov     x0, #50
    udiv    x0, x20, x0
    mov     x1, #1                  ; request padding
    bl      printUInt               ; print number of halves

    mov     x0, #25
    udiv    x0, x21, x0
    mov     x1, #1                  ; request padding
    bl      printUInt               ; print number of quarters

    mov     x0, #10
    udiv    x0, x22, x0
    mov     x1, #1                  ; request padding
    bl      printUInt               ; print number of dimes

    mov     x0, #5
    udiv    x0, x23, x0
    mov     x1, #1                  ; request padding
    bl      printUInt               ; print number of nickles

    mov     x0, x24                 ; penny count
    mov     x1, #1                  ; request padding
    bl      printUInt               ; print number of halves

    mov     x1, x25                 ; new line address
    mov     x2, #1
    bl      print

 print_line_ret:
    ldp     x19, x20, [sp], #16     ; restore
    ldp     x21, x22, [sp], #16     ; restore
    ldp     x23, x24, [sp], #16     ; restore
    ldp     x25, x26, [sp], #16     ; restore
    ldp     x27, x28, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore
    ret
