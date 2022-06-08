.text
.align 8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print:
    mov     x0, #1                  ; STDOUT
    mov     x16, 4                  ; write
    svc     #0xffff
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
clr_wrk:
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
    b       clr_wrk                 ; continue

nopad:
    mov     x2, x20                 ; string length
    b       reverse_and_print

printUInt_Zero:                     ; this is the exceptional case when x21 is 0 then we need to push this ourselves to the stack
    mov     x21, #0x30              ; move "0" to w21
    mov     x20, #1                 ; just one digit
    strb    w21, [sp, x20]          ; push digit so that it can be printed to the screen
    b       printUInt_print

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

reverse_field:
;;  swaps bytes so that "54321" becomes "12345" 
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

;;EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEOF

