.text
.global _main
;;  listing the ways to make change for a buck (cfab)

;;  written on a m1 mac for Apple Silicon processors

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
    mov     x0, #1                  ; STDOUT
    mov     x16, 4                  ; write
    svc     #0xffff
    ret

;;  Print value in x0 as an unisgned int to STDOUT
;;  When x1 == 0 do not pad. Otherwise, right justify in a x1 byte field padded with spaces
;;  x26 misc. index
;;  x25 size of workarea
;;  x24 format indicator (size of field, or zero)
;;  x23 remainder
;;  x22 work register, quotient
;;  x21 work register, starts with subject for printing
;;  x20 digit string index
;;  x19 radix/divisor
;;
;;  inputs
;;      x0 number to be printed
;;      x1 format indicator

printUInt:
    stp     fp, lr, [sp, #-16]!     ; preserve
    stp     x25, x26, [sp, #-16]!   ; preserve
    stp     x23, x24, [sp, #-16]!   ; preserve
    stp     x21, x22, [sp, #-16]!   ; preserve
    stp     x19, x20, [sp, #-16]!   ; preserve
    mov     x25, #32                ; size of workarea keep it a multiple of 16
    sub     sp, sp, x25             ; move stack pointer down n * 16 bytes, space for digit string
    add     fp, sp, x25             ; account for work area
    add     fp, fp, #80             ; finish defining frame
;
    mov     x24, x1                 ; keep format indicator
    cmp     x24, xzr                ; padding requested?
    b.eq    normal                  ; nope, regular processing
    b.lt    invalid_fi              ; format indicator out of range
    cmp     x24, x25                ; field size fits in workarea?
    b.gt    invalid_fi              ; nope, max padding
max_pad:
    mov     x26, x25                ; index (size of workarea)
    mov     x22, #0x20              ; put a " " in lsb
init_loop:                          ; fill workarea with blanks
    strb    w22, [sp, x26]          ; insert another blank
    subs    x26, x26, #1            ; move over another byte
    b.gt    init_loop
normal:
    mov     x19, #10                ; x19 will contain the divisor (10) used in udiv and msub
    mov     x20, xzr                ; x20 counts the number of digits stored on stack

    cmp     x0, xzr                 ; if x0 is zero then the division algorith will not work
    b.eq    printUInt_Zero          ; we set the value on the stack to 0
    mov     x21, x0                 ; move input parameter to work register

printUInt_Count:
    udiv    x22, x21, x19           ; divide x21 by 10, x22 gets quotient
    msub    x23, x22, x19, x21      ; obtain the remainder (x23) and the Quotient (x22)
    add     w23, w23, #0x30         ; add 48 to the number, turning it into an ASCII char 0-9
    add     x20, x20, #1            ; increment the digit counter/index (x20)
    strb    w23, [sp, x20]          ; build string on the stack one digit at a time
    mov     x21, x22                ; copy the Quotient (x22) into x21 which is the new value to divide by 10
    cmp     x21, xzr                ; done?
    b.gt    printUInt_Count         ; if x21 is not yet zero than there's more digits to extract

;; Using the stack guarantees that the digits are printed start with the most significant digit
printUInt_print:
    cmp     x24, xzr                ; pad?
    b.eq    nopad                   ; nope
    mov     x2, x24                 ; size of field
reverse_and_print:
    add     x1, sp, #1              ; point to output
    bl      reverse_field           ; undo algorithm
    bl      print

printUInt_exit:
    add     sp, sp, x25             ; return string work area
    ldp     x19, x20, [sp], #16     ; restore
    ldp     x21, x22, [sp], #16     ; restore
    ldp     x23, x24, [sp], #16     ; restore
    ldp     x25, x26, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore
    ret                             ; return

invalid_fi:
    mov     x24, x25                ; max padding
    b       max_pad                 ; continue with no formating

nopad:
    mov     x2, x20                 ; string length
    b       reverse_and_print

printUInt_Zero:                     ; this is the exceptional case when x21 is 0 then we need to push this ourselves to the stack
    mov     x21, #0x30              ; move "0" to w21
    mov     x20, #1                 ; just one digit
    strb    w21, [sp, x20]          ; push digit so that it can be printed to the screen
    b       printUInt_print
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


count_ways:
;   x26     top of workarea
;   x25     sum
;   x24     cents
;   x23     nickles
;   x22     dimes
;   x21     quarters
;   x20     halves
;   x19     count

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
    add     x25, x20, x21           ; init sum with halves
    add     x25, x25, x22           ; add dimes
    add     x25, x25, x23           ; add nickles
    add     x25, x25, x24           ; add cents
    cmp     x25, #100               ; a hit?
    b.gt    reset_cents             ; no, too high
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

    adr     x26, lit_pool           ; address of literals
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
;   x26     field size
;   x25     line end address
;   x24     cents
;   x23     nickles
;   x22     dimes
;   x21     quarters
;   x20     halves
;   x19     count

    stp     fp, lr, [sp, #-16]!     ; preserve
    stp     x25, x26, [sp, #-16]!   ; preserve
    stp     x23, x24, [sp, #-16]!   ; preserve
    stp     x21, x22, [sp, #-16]!   ; preserve
    stp     x19, x20, [sp, #-16]!   ; preserve
    add     fp, sp, #80             ; define stack frame

    adr     x25, lit_pool           ; first byte is \n
    mov     x26, #6                 ; field size

    mov     x0, x19                 ; line number
    mov     x1, x26                 ; request padding
    bl      printUInt

    mov     x0, #50
    udiv    x0, x20, x0
    mov     x1, x26                 ; request padding
    bl      printUInt               ; print number of halves

    mov     x0, #25
    udiv    x0, x21, x0
    mov     x1, x26                 ; request padding
    bl      printUInt               ; print number of quarters

    mov     x0, #10
    udiv    x0, x22, x0
    mov     x1, x26                 ; request padding
    bl      printUInt               ; print number of dimes

    mov     x0, #5
    udiv    x0, x23, x0
    mov     x1, x26                 ; request padding
    bl      printUInt               ; print number of nickles

    mov     x0, x24                 ; penny count
    mov     x1, x26                 ; request padding
    bl      printUInt               ; print number of halves

    mov     x1, x25                 ; new line address
    mov     x2, #1
    bl      print

 print_line_ret:
    ldp     x19, x20, [sp], #16     ; restore
    ldp     x21, x22, [sp], #16     ; restore
    ldp     x23, x24, [sp], #16     ; restore
    ldp     x25, x26, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore
    ret


reverse_field:
;;  x28 index of last unswapped byte
;;  x27 index of next byte to swap
;;  x26, x25 work registers
;; inputs
;;  x1 size of field    const
;;  x0 start of field   const

    cmp     x2, #1                  ; anything to swap?
    b.le    get_out                 ; no, get out
    stp     fp, lr, [sp, #-16]!     ; preserve
    stp     x27, x28, [sp, #-16]!   ; preserve
    stp     x25, x26, [sp, #-16]!   ; preserve
    add     fp, sp, #48             ; setup frame

    mov     x27, xzr                ; index of first byte
    sub     x28, x2, #1             ; index of last byte

reverse_loop:
    ldrb    w25, [x1, x27]          ; first unswapped byte
    ldrb    w26, [x1, x28]          ; last unswapped byte
    strb    w26, [x1, x27]
    strb    w25, [x1, x28]
    add     x27, x27, #1            ; next byte
    sub     x28, x28, #1            ; previous byte
    cmp     x27, x28                ; done? is x28 <= x27
    b.lt    reverse_loop            ; no, repeat

reverse_exit:
    ldp     x25, x26, [sp], #16     ; restore
    ldp     x27, x28, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore

get_out:
    ret

