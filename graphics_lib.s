                align   4           ; Ensure library starts on word boundary
; ------------------------------------------------------------------------------
;           Graphics Library for VDU Rendering
;           Provides user-space pixel and shape drawing routines.
; ------------------------------------------------------------------------------

; Graphics Constants
VDU_FRAMESTORE   EQU    0x00100000
VDU_WIDTH        EQU    640
VDU_HEIGHT       EQU    480

; --- Subroutine: graphics_draw_pixel ---
; Arguments: a0 = X, a1 = Y, a2 = Color (8-bit)
; Returns:   None
; Side effects: Overwrites t0, t1. Preserves ra.
; Description: Calculates the DDRAM address and writes a byte to the framestore.
graphics_draw_pixel
                ; Bounds checking
                li      t0, VDU_WIDTH
                bgeu    a0, t0, graphics_draw_pixel_exit
                li      t0, VDU_HEIGHT
                bgeu    a1, t0, graphics_draw_pixel_exit

                ; Offset = (y * 640) + x
                ; 640 = 512 + 128
                slli    t0, a1, 9           ; t0 = y * 512
                slli    t1, a1, 7           ; t1 = y * 128
                add     t0, t0, t1
                add     t0, t0, a0          ; t0 = total pixel offset
                
                li      t1, VDU_FRAMESTORE
                add     t1, t1, t0
                sb      a2, 0[t1]           ; Write pixel to framestore
graphics_draw_pixel_exit
                ret

; --- Subroutine: graphics_draw_rect ---
; Arguments: a0 = x1, a1 = y1, a2 = x2, a3 = y2, a4 = color
; Returns:   None
; Side effects: Overwrites t0-t6, a7. Preserves ra.
; Description: Draws a solid rectangle from (x1, y1) to (x2, y2).
graphics_draw_rect
; CLEVER MOVE: This is a "leaf function" optimization. By inlining the 
; pixel logic, we use t0-t6 scratch registers and eliminate all stack 
; operations (sw/lw), significantly speeding up large shape rendering.
                ; Move arguments to t-registers for high-speed looping
                mv      t0, a0              ; t0 = current_x
                mv      t1, a1              ; t1 = current_y
                mv      t2, a2              ; t2 = target_x2
                mv      t3, a3              ; t3 = target_y2
                mv      t4, a4              ; t4 = color
                mv      t5, a0              ; t5 = start_x1

rect_y_loop
                bgt     t1, t3, rect_exit   ; if y > y2, done
rect_x_loop
                bgt     t0, t2, rect_x_done ; if x > x2, move to next row
                
                ; --- Inlined Pixel Logic ---
                ; Bounds check
                li      t6, VDU_WIDTH
                bgeu    t0, t6, skip_pixel
                li      t6, VDU_HEIGHT
                bgeu    t1, t6, skip_pixel

                ; Offset = (y * 640) + x
                slli    t6, t1, 9           
                slli    a7, t1, 7           ; Use a7 as temporary scratch
                add     t6, t6, a7
                add     t6, t6, t0          
                
                li      a7, VDU_FRAMESTORE
                add     t6, t6, a7
                sb      t4, 0[t6]           ; Write pixel
                ; ---------------------------

skip_pixel
                addi    t0, t0, 1
                j       rect_x_loop

rect_x_done
                addi    t1, t1, 1           ; y++
                mv      t0, t5              ; x = x1
                j       rect_y_loop

rect_exit
                ret

; --- Subroutine: graphics_draw_circle ---
; Arguments: a0 = xc, a1 = yc, a2 = radius, a3 = color
; Returns:   None
; Side effects: Overwrites a0-a2, t0. Preserves ra, s0-s6.
; Description: Draws an outlined circle using Bresenham's Midpoint Algorithm.
graphics_draw_circle
                subi    sp, sp, 32
                sw      ra, 0[sp]
                sw      s0, 4[sp]
                sw      s1, 8[sp]
                sw      s2, 12[sp]
                sw      s3, 16[sp]
                sw      s4, 20[sp]
                sw      s5, 24[sp]
                sw      s6, 28[sp]

                mv      s0, a0              ; s0 = xc
                mv      s1, a1              ; s1 = yc
                mv      s2, a2              ; s2 = radius
                mv      s3, a3              ; s3 = color
                
                mv      s4, a2              ; s4 (x) = radius
                li      s5, 0               ; s5 (y) = 0
                li      t0, 1
                sub     s6, t0, s4          ; s6 (p) = 1 - x

circle_loop
                blt     s4, s5, circle_done ; while (x >= y)

                ; Draw 8 symmetric points
                ; (xc + x, yc + y)
                add     a0, s0, s4
                add     a1, s1, s5
                mv      a2, s3
                call    graphics_draw_pixel

                ; (xc - x, yc + y)
                sub     a0, s0, s4
                add     a1, s1, s5
                mv      a2, s3
                call    graphics_draw_pixel

                ; (xc + x, yc - y)
                add     a0, s0, s4
                sub     a1, s1, s5
                mv      a2, s3
                call    graphics_draw_pixel

                ; (xc - x, yc - y)
                sub     a0, s0, s4
                sub     a1, s1, s5
                mv      a2, s3
                call    graphics_draw_pixel

                ; (xc + y, yc + x)
                add     a0, s0, s5
                add     a1, s1, s4
                mv      a2, s3
                call    graphics_draw_pixel

                ; (xc - y, yc + x)
                sub     a0, s0, s5
                add     a1, s1, s4
                mv      a2, s3
                call    graphics_draw_pixel

                ; (xc + y, yc - x)
                add     a0, s0, s5
                sub     a1, s1, s4
                mv      a2, s3
                call    graphics_draw_pixel

                ; (xc - y, yc - x)
                sub     a0, s0, s5
                sub     a1, s1, s4
                mv      a2, s3
                call    graphics_draw_pixel

                ; Update variables
                addi    s5, s5, 1           ; y++
                
                bgez    s6, p_greater_zero
                ; p < 0: p = p + 2*y + 1
                slli    t0, s5, 1           ; t0 = 2*y
                addi    t0, t0, 1           ; t0 = 2*y + 1
                add     s6, s6, t0
                j       circle_loop

p_greater_zero
                subi    s4, s4, 1           ; x--
                ; p = p + 2*(y - x) + 1
                sub     t0, s5, s4          ; t0 = y - x
                slli    t0, t0, 1           ; t0 = 2*(y - x)
                addi    t0, t0, 1
                add     s6, s6, t0
                j       circle_loop

circle_done
                lw      ra, 0[sp]
                lw      s0, 4[sp]
                lw      s1, 8[sp]
                lw      s2, 12[sp]
                lw      s3, 16[sp]
                lw      s4, 20[sp]
                lw      s5, 24[sp]
                lw      s6, 28[sp]
                addi    sp, sp, 32
                ret

; --- Subroutine: graphics_clear_screen ---
; Arguments: None
; Returns:   None
; Side effects: Overwrites t0, t1. Preserves ra.
; Description: Wipes the entire 640x480 framestore to black (0x00).
;              Uses word-aligned stores (sw) to clear 4 pixels at a time.
graphics_clear_screen
                li      t0, VDU_FRAMESTORE
                li      t1, 76800           ; (640 * 480) / 4 = 76,800 words
graphics_clear_loop
                sw      zero, 0[t0]
                addi    t0, t0, 4
                subi    t1, t1, 1
                bnez    t1, graphics_clear_loop
                ret
