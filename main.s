; ------------------------------------------------------------------------------
;           Exercise 9: Project Pictionary Game (charades but with drawings)
;           Mahmoud Alhasan
;           Version 3.0
;           16th May 2026
;
;           Implements a UART peripheral in Verilog to communicate serially 
;           via an HC-06 Bluetooth module to a connected device such as a
;           phone. Phone player can send commands to draw on the monitor,
;           and the board player can send guesses to the phone player.
;           Hardware access is strictly mediated through ECALL services.
;
;           ARCHITECTURE: Communication Manager Pattern
;           - main.s: High-level application controller.
;           - parser_lib.s: Command tokenization and dispatch.
;           - comm_lib.s: UART buffer management and message polling.
;           - keyboard_lib.s: Matrix translation and UI state management.
;
;           CLEVER MOVE: "Hot Path" Branch Optimization.
;           The loop is structured so the most frequent case (no keyboard input)
;           falls through directly into the UART polling logic. This saves 
;           one branch penalty per loop cycle, minimizing pipeline stalls.
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------

LCD_CMD_CLEAR    EQU    1
LCD_LINE1_START  EQU    0x80
LCD_LINE2_START  EQU    0xC0

ASCII_SPACE      EQU    ' '
ASCII_NEWLINE    EQU    '\n'

; ECALL Service Numbers
SYS_PRINT_CHAR   EQU    1
SYS_EXIT         EQU    2
SYS_TIMER_INIT   EQU    3
SYS_TIMER_CHECK  EQU    4
SYS_READ_BUTTONS EQU    5
SYS_LCD_CMD      EQU    6
SYS_LCD_CLEAR    EQU    7
SYS_GET_KEY      EQU    8
SYS_UART_PUT     EQU    9
SYS_UART_GET     EQU    10
SYS_BUZZER       EQU    11

; ------------------------------------------------------------------------------
; User Application (User Mode)
; ------------------------------------------------------------------------------
                ORG     0x00040000          ; User RAM region

user_main
                ; LCD clearing
                li      a0, LCD_CMD_CLEAR
                li      a7, SYS_LCD_CMD
                ecall

                ; VDU clearing (Fix for power-on garbage) - DISABLED FOR DEBUG
                ; call    graphics_clear_screen

                ; Initialize libraries
                call    comm_init
                call    keyboard_init
                call    keyboard_update_lcd

key_loop
                ; 1. Process Keyboard Input (Primary Poll)
                call    keyboard_get_char
                li      t0, KBD_POLL_EMPTY
                bne     a0, t0, process_key ; Branch ONLY if key exists (Rare)

poll_uart
                ; 2. Process UART Input (Hot Path - Fall through)
                call    comm_poll_message
                beqz    a0, key_loop        ; If no UART message, recycle

                ; Full message received! Dispatch to parser
                call    parser_parse_command
                call    comm_reset_rx       ; Reset buffer length for next message
                j       key_loop

process_key
                ; --- Rare Case: Keyboard Handler ---
                ; Check for control codes
                li      t1, KBD_CODE_SEND
                beq     a0, t1, do_send
                
                li      t1, KBD_CODE_BACK
                beq     a0, t1, do_backspace

                ; It's a regular key: Print to LCD and append to buffer
                mv      s0, a0              ; save char
                li      a7, SYS_PRINT_CHAR
                ecall
                
                mv      a0, s0
                call    comm_append_char
                j       poll_uart           ; Handled key, now check UART

do_send
                call    comm_send_message
                ; Clear LCD display
                li      a0, LCD_CMD_CLEAR
                li      a7, SYS_LCD_CMD
                ecall
                call    keyboard_update_lcd
                j       poll_uart

do_backspace
                call    comm_get_tx_len
                beqz    a0, poll_uart       ; Buffer empty, nothing to delete
                
                call    comm_backspace_tx
                
                ; Repoisiton cursor and clear char on LCD
                call    comm_get_tx_len
                mv      t1, a0
                li      a0, LCD_LINE1_START
                add     a0, a0, t1
                li      a7, SYS_LCD_CMD
                ecall
                
                li      a0, ASCII_SPACE
                li      a7, SYS_PRINT_CHAR
                ecall
                
                ; Repositon cursor back
                li      a0, LCD_LINE1_START
                add     a0, a0, t1
                li      a7, SYS_LCD_CMD
                ecall
                j       poll_uart

; ------------------------------------------------------------------------------
; Memory Allocations & Data
; ------------------------------------------------------------------------------

                align               ; align user stack to word boundary

                shared_timer    defw    1

                align   4
                user_stack      DEFS    256
                align   4
                user_stack_base

                ; ------------------------------------------------------------------------------
                ; INCLUDES
                ; ------------------------------------------------------------------------------

                include         comm_lib.s
                include         keyboard_lib.s
                include         graphics_lib.s
                include         string_lib.s
                include         parser_lib.s
                include         print_lib.s
                include         os.s
