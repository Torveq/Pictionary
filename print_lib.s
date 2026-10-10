; ------------------------------------------------------------------------------
;           Formatted Print Library
;           Provides routines for decimal and string output to LCD.
; ------------------------------------------------------------------------------

; Constants
PRINT_BASE_TEN        EQU     10
PRINT_ASCII_ZERO      EQU     0x30
; --- Subroutine: print_dec ---
; Arguments: a0 = 32-bit unsigned integer to be printed
; Returns:   None
; Side effects: Overwrites a0, a7, t0, t1, t2. Uses stack for digit buffering.
; Description: Converts integer to decimal ASCII and prints to LCD.
print_dec
; CLEVER MOVE: Uses custom 4-byte stack step (ignoring 16-byte ABI) for efficiency.
                li      t0, PRINT_BASE_TEN             
                mv      t1, sp                  ; save initial stack pointer            
divide_loop
                remu    t2, a0, t0              ; extracting lowest digit
                divu    a0, a0, t0              ; essentially shifts the number to the right by base 10
                subi    sp, sp, 4               
                sw      t2, 0[sp]               ; pushes digit to stack
                bnez    a0, divide_loop     

print_digits_loop
                lw      a0, 0[sp]               ; pops digit from stack       
                addi    sp, sp, 4
                addi    a0, a0, PRINT_ASCII_ZERO      ; converts integer to ASCII character  
                li      a7, SYS_PRINT_CHAR  
                ecall
                bne     sp, t1, print_digits_loop ; loop until stack pointer returns to initial value
                ret


; --- Subroutine: print_str ---
; Arguments: a0 = Pointer to null-terminated string
; Returns:   None
; Side effects: Overwrites a0, a7. Preserves ra, s0.
; Description: Iterates over characters in the string printing them to LCD.
print_str
                subi    sp, sp, 16
                sw      ra, 0[sp]
                sw      s0, 4[sp]               ; preserve callee-saved registers
                mv      s0, a0              
str_loop
                lb      a0, 0[s0]               ; load current character
                beqz    a0, str_exit            ; check for the null-terminator byte
                li      a7, SYS_PRINT_CHAR
                ecall
                addi    s0, s0, 1               ; move to the next byte/character
                j       str_loop
str_exit
                lw      ra, 0[sp]
                lw      s0, 4[sp]               ; restore the callee-saved register
                addi    sp, sp, 16
                ret
