.text
.align 8
.macro m_init was
    stp     fp, lr, [sp, #-16]!     ; preserve
    stp     x27, x28, [sp, #-16]!   ; preserve
    stp     x25, x26, [sp, #-16]!   ; preserve
    stp     x23, x24, [sp, #-16]!   ; preserve
    stp     x21, x22, [sp, #-16]!   ; preserve
    stp     x19, x20, [sp, #-16]!   ; preserve
    mov     x28, \was               ; workarea - number of 16 byte segments
    lsl     x28, x28, #4            ; segment count * 16
    sub     sp, sp, x28             ; move stack pointer down n * 16 to make workarea
    add     fp, sp, x28             ; account for work area size
    add     fp, fp, #96             ; finish setting up frame pointer by adding size of save area
.endm
 
 .macro m_exit_pgm
    add     sp, sp, x28             ; return workarea to stack frame
    ldp     x19, x20, [sp], #16     ; restore
    ldp     x21, x22, [sp], #16     ; restore
    ldp     x23, x24, [sp], #16     ; restore
    ldp     x25, x26, [sp], #16     ; restore
    ldp     x27, x28, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore
    mov     x0, xzr                 ; return code
    mov     x16, #1                 ; return control to supervisor
    svc     0xffff
.endm

.macro m_ret
    add     sp, sp, x28             ; return workarea to stack frame
    ldp     x19, x20, [sp], #16     ; restore
    ldp     x21, x22, [sp], #16     ; restore
    ldp     x23, x24, [sp], #16     ; restore
    ldp     x25, x26, [sp], #16     ; restore
    ldp     x27, x28, [sp], #16     ; restore
    ldp     fp, lr, [sp], #16       ; restore
    ret
.endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

atouint:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  converts an ASCII string to an unsigned int
;;
;;  register usage:
;;    x28 workarea size located at bottom of stack frame
;;    x27 misc. index
;;    x26 converted number
;;    x25 radix (10)
;;    x24 current factor
;;    x23 unused

    m_init 64

    sub     x27, x28, #8            ; initialize index
    mov     x23, xzr                ; to clear work area
clr_loop:                           ; ensure input area is all low values
    str     x23, [sp, x27]          ; set to low values
    subs    x27, x27, #8            ; set index for next quad
    b.ge    clr_loop                ; iterate

    add     x1, sp, #1              ; start of workarea
    sub     x2, x28, #1             ; size of workarea
    bl      readSTDIN
    cmp     x0, xzr                 ; check x0 (length)
    b.le    atouint_exit            ; negative length???
    mov     x25, #10                ; radix
    mov     x24, #1                 ; current factor
    mov     x26, xzr                ; set sum to zero
    mov     x27, x0                 ; index of lsd
acc_loop:
    ldrb    w23, [sp, x27]          ; load ascii digit
    cmp     w23, wzr                ; end of input string?
    b.le    acc_exit                ; yep, leave loop
    cmp     w23, #0x30              ; compare to "0"
    b.lt    acc_next                ; skip, too low
    cmp     w23, #0x39              ; compare to "9"
    b.gt    acc_next                ; skip, too high
    sub     w23, w23, #0x30         ; deasciify digit
    madd    x26, x23, x24, x26      ; multiply by power of 10
    mul     x24, x24, x25           ; next power of ten
acc_next:
    subs    x27, x27, #1            ; index of next char
    b.gt    acc_loop                ; continue
acc_exit:
    mov     x0, x26                 ; time to convert & print
    mov     x1, xzr                 ; no padding
    bl      printUInt               ; to STDOUT
    bl      EOL                     ; must be called (at least on a Mac) to terminate a line

atouint_exit:
    m_ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print:
    mov     x0, #1                  ; STDOUT
    mov     x16, #4                 ; write
    svc     #0xffff
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EOL:                                ; end of line routine
;;
;;  register usage:
;;    x28 workarea size located at bottom of stack frame
;;    x27 unused

    m_init 1

    mov     x1, #0xa                ; new line char
    strb    w1, [sp, #1]            ; first byte of output gets it
    add     x1, sp, #1              ; point to output area
    mov     x2, #1                  ; print just the new line
    bl      print

    m_ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

printUInt:
;;  Print value in x0 as an unisgned int to STDOUT
;;  When x1 == 0 do not pad. Otherwise, right justify in a x1 byte field padded with spaces
;;  x28 size of workarea
;;  x27 unused
;;  x26 misc. index
;;  x24 format indicator (size of field, or zero)
;;  x23 remainder
;;  x22 work register, quotient
;;  x21 work register, starts with subject for printing
;;  x20 digit string index
;;  x19 radix/divisor
;;
;;  inputs:
;;      x0 number to be printed
;;      x1 format indicator
;
    m_init 2

    mov     x24, x1                 ; keep format indicator
    cmp     x24, xzr                ; padding requested?
    b.eq    normal                  ; nope, regular processing
    b.lt    invalid_fi              ; format indicator out of range
    cmp     x24, x28                ; field size fits in workarea?
    b.gt    invalid_fi              ; nope, max padding
clr_wrk:
    mov     x26, x28                ; index (size of workarea)
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
    sub     x2, x24, #1             ; size of field
reverse_and_print:
    add     x1, sp, #1              ; point to output
    bl      reverse_field           ; undo algorithm
    bl      print

printUInt_exit:
    m_ret

invalid_fi:
    mov     x24, x28                ; max padding
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

readSTDIN:
;;  x0 returns string length
;;  x1 buffer
;;  x2 buffer size

    stp     fp, lr, [sp, #-16]!     ; preserve
    mov     x0, #0                  ; STDIN
    mov     x16, #3                 ; read
    svc     0xffff
    ldp     fp, lr, [sp], #16       ; restore
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

reverse_field:
;;  swaps bytes so that "54321" becomes "12345"
;;  x28 reserved for workarea size
;;  x24 index of last unswapped byte
;;  x27 index of next byte to swap
;;  x26, x25 work registers
;; inputs
;;  x2 size of field    const
;;  x1 start of field   const

    m_init 0

    mov     x27, xzr                ; index of first byte
    sub     x24, x2, #1             ; index of last byte

reverse_loop:
    ldrb    w25, [x1, x27]          ; first unswapped byte
    ldrb    w26, [x1, x24]          ; last unswapped byte
    strb    w26, [x1, x27]
    strb    w25, [x1, x24]
    add     x27, x27, #1            ; next byte
    sub     x24, x24, #1            ; previous byte
    cmp     x27, x24                ; done? is x28 <= x27
    b.lt    reverse_loop            ; no, repeat

    m_ret

;;EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEOF
