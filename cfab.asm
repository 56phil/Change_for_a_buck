.text
.global _main
;;  listing the ways to make change for a buck (cfab)

;;  written on a m1 mac for Apple Silicon processors

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "common.asm"
.align 8

_main:
    m_init 0

    bl      count_ways              ; get 'er done

    m_exit_pgm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

count_ways:
;; a for loop for each coin
;;
;;   x28     size of workarea
;;   x27     unused
;;   x26     top of literal pool
;;   x25     sum
;;   x24     cents
;;   x23     nickles
;;   x22     dimes
;;   x21     quarters
;;   x20     halves
;;   x19     count

    m_init 0

    mov     x19, xzr                ; init count
    mov     x20, xzr                ; init halves
    mov     x21, xzr                ; init quarters
    mov     x22, xzr                ; init dimes
    mov     x23, xzr                ; init nickles
    mov     x24, xzr                ; init cents

sum:
    add     x25, x20, x21           ; init sum with halves & quarters
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

    m_ret

hit:
    add     x19, x19, #1            ; bump count
    bl      print_line
    b       reset_cents             ; continue

lit_pool:   .ascii  "\nThere are ways to make change for a buck.\n"
.align 8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print_line:
;   x28     workarea size
;   x27     unused
;   x26     field size
;   x25     lit_pool address
;   x24     cents
;   x23     nickles
;   x22     dimes
;   x21     quarters
;   x20     halves
;   x19     count

    m_init 0

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
    bl      EOL                     ; end of line

 print_line_ret:
    m_ret

;;EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEOF

