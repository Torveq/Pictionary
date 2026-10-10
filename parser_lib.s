; ------------------------------------------------------------------------------
;           Command Parser Library
;           Tokenizes and dispatches graphics commands.
; ------------------------------------------------------------------------------

; --- Subroutine: parser_parse_command ---
; Arguments: comm_rx_buffer contains the command string
; Returns:   None
; Side effects: Overwrites a0-a4, t0-t6. Preserves ra, s0-s5. Calls graphics.
; Description: Tokenizes the input buffer and dispatches to rect/circle routines.
parser_parse_command
                subi    sp, sp, 32
                sw      ra, 0[sp]
                sw      s0, 4[sp]           ; Buffer pointer
                sw      s1, 8[sp]           ; Temp
                sw      s2, 12[sp]
                sw      s3, 16[sp]
                sw      s4, 20[sp]
                sw      s5, 24[sp]

                la      s0, comm_rx_buffer

                call    str_skip_ws
                ; Check for "rect"
                la      a0, parser_cmd_rect
                mv      a1, s0
                call    str_equals
                bnez    a0, parser_do_rect

                ; Check for "circle"
                la      a0, parser_cmd_circle
                mv      a1, s0
                call    str_equals
                bnez    a0, parser_do_circle

                j       parser_done

parser_do_rect
                addi    s0, s0, 4           ; Skip "rect"

                call    str_skip_ws
                call    str_parse_int
                mv      s4, a0              ; s4 = color

                call    str_skip_ws
                call    str_parse_int
                mv      s1, a0              ; s1 = x1

                call    str_skip_ws
                call    str_parse_int
                mv      s2, a0              ; s2 = y1

                call    str_skip_ws
                call    str_parse_int
                mv      s3, a0              ; s3 = x2

                call    str_skip_ws
                call    str_parse_int
                mv      s5, a0              ; s5 = y2

                ; Dispatch to graphics_lib
                mv      a0, s1
                mv      a1, s2
                mv      a2, s3
                mv      a3, s5
                mv      a4, s4
                call    graphics_draw_rect
                j       parser_done

parser_do_circle
                addi    s0, s0, 6           ; Skip "circle"

                call    str_skip_ws
                call    str_parse_int
                mv      s4, a0              ; s4 = color

                call    str_skip_ws
                call    str_parse_int
                mv      s1, a0              ; s1 = xc

                call    str_skip_ws
                call    str_parse_int
                mv      s2, a0              ; s2 = yc

                call    str_skip_ws
                call    str_parse_int
                mv      s3, a0              ; s3 = radius

                ; Dispatch to graphics_lib
                mv      a0, s1
                mv      a1, s2
                mv      a2, s3
                mv      a3, s4
                call    graphics_draw_circle

parser_done
                lw      ra, 0[sp]
                lw      s0, 4[sp]
                lw      s1, 8[sp]
                lw      s2, 12[sp]
                lw      s3, 16[sp]
                lw      s4, 20[sp]
                lw      s5, 24[sp]
                addi    sp, sp, 32
                ret

; Command Strings
parser_cmd_rect        defb    'r', 'e', 'c', 't', 0
parser_cmd_circle      defb    'c', 'i', 'r', 'c', 'l', 'e', 0
