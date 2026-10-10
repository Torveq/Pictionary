; ------------------------------------------------------------------------------
;           String Manipulation Library
;           Provides routines for parsing and comparing strings.
; ------------------------------------------------------------------------------

; Constants
STR_ASCII_SPACE      EQU    ' '

; --- Subroutine: str_skip_ws ---
; Arguments: s0 = Current pointer to string
; Returns:   s0 = Pointer to first non-space character
; Side effects: Overwrites t0, t1. Updates s0.
; Description: Advances the pointer s0 until it points to a non-space character.
str_skip_ws
                lbu     t0, 0[s0]
                li      t1, STR_ASCII_SPACE
                bne     t0, t1, str_skip_ws_exit
                addi    s0, s0, 1
                j       str_skip_ws
str_skip_ws_exit
                ret

; --- Subroutine: str_parse_int ---
; Arguments: s0 = Current pointer to string
; Returns:   a0 = integer value, s0 = updated pointer
; Side effects: Overwrites a0, t0, t1, t2. Updates s0.
; Description: Parses decimal digits and returns the numeric value.
str_parse_int
                li      a0, 0
                li      t2, 10              ; Base 10
str_parse_int_loop
                lbu     t0, 0[s0]
                li      t1, '0'
                blt     t0, t1, str_parse_int_exit
                li      t1, '9'
                bgt     t0, t1, str_parse_int_exit

                ; val = (val * 10) + (char - '0')
                mul     a0, a0, t2
                subi    t0, t0, '0'
                add     a0, a0, t0

                addi    s0, s0, 1
                j       str_parse_int_loop
str_parse_int_exit
                ret

; --- Subroutine: str_equals ---
; Arguments: a0 = str1 (keyword), a1 = str2 (input buffer)
; Returns:   a0 = 1 if equal (prefix match), 0 if not
; Side effects: Overwrites a0, a1, t0, t1.
; Description: Case-sensitive prefix string comparison. Matches if str1 is a prefix of str2.
str_equals
                lbu     t0, 0[a0]
                beqz    t0, str_is_equal    ; Reached end of keyword, it's a match!
                lbu     t1, 0[a1]
                bne     t0, t1, str_not_equal
                addi    a0, a0, 1
                addi    a1, a1, 1
                j       str_equals
str_not_equal
                li      a0, 0
                ret
str_is_equal
                li      a0, 1
                ret
