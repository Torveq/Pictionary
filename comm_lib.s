; ------------------------------------------------------------------------------
;           Communication Library (Bluetooth/UART)
;           Manages message buffers and serial transmission/reception.
; ------------------------------------------------------------------------------

; Constants
COMM_MAX_BUF       EQU    127
COMM_ASCII_NEWLINE EQU    '\n'
COMM_POLL_EMPTY    EQU    -1

; --- Subroutine: comm_init ---
; Description: Initializes communication buffers.
comm_init
                la      t0, comm_tx_len
                sw      zero, 0[t0]
                la      t0, comm_rx_len
                sw      zero, 0[t0]
                ret

; --- Subroutine: comm_poll_message ---
; Returns:   a0 = 1 if a full newline-terminated message is ready, 0 otherwise.
; Side effects: Overwrites a0, a7, t0, t1, t2. Preserves ra, s0.
; Description: Polls UART, appends to buffer, and checks for message completion.
comm_poll_message
                subi    sp, sp, 16
                sw      ra, 0[sp]
                sw      s0, 4[sp]

comm_poll_loop
                li      a7, SYS_UART_GET
                ecall
                li      t0, COMM_POLL_EMPTY
                beq     a0, t0, comm_poll_no_data

                li      t0, COMM_ASCII_NEWLINE
                beq     a0, t0, comm_poll_complete
                li      t0, 0x0D            ; Check for Carriage Return (\r)
                beq     a0, t0, comm_poll_complete

                ; Append to rx_buffer
                la      t0, comm_rx_len
                lw      t1, 0[t0]
                li      t2, COMM_MAX_BUF
                bge     t1, t2, comm_poll_loop ; Buffer full: drop character

                la      t2, comm_rx_buffer
                add     t2, t2, t1
                sb      a0, 0[t2]
                addi    t1, t1, 1
                sw      t1, 0[t0]
                j       comm_poll_loop      ; Keep draining hardware FIFO

comm_poll_no_data
                li      a0, 0               ; Not ready
                j       comm_poll_exit

comm_poll_complete
                ; Full message received! Trigger "Receive Alert" buzzer (Pattern 1)
                li      a0, 1
                li      a7, SYS_BUZZER
                ecall

                ; Null-terminate the message
                la      t0, comm_rx_len
                lw      t1, 0[t0]
                la      t2, comm_rx_buffer
                add     t2, t2, t1
                sb      zero, 0[t2]
                li      a0, 1               ; Message ready!

comm_poll_exit
                lw      ra, 0[sp]
                lw      s0, 4[sp]
                addi    sp, sp, 16
                ret

; --- Subroutine: comm_send_message ---
; Arguments: None (uses internal tx_buffer)
; Side effects: Overwrites a0, a7, t0, t1. Preserves ra, s1, s2, s3.
; Description: Sends a buffer followed by a newline via UART.
comm_send_message
                subi    sp, sp, 16
                sw      ra, 0[sp]
                sw      s1, 4[sp]
                sw      s2, 8[sp]
                sw      s3, 12[sp]

                ; Trigger "Send Success" buzzer (Pattern 0)
                li      a0, 0
                li      a7, SYS_BUZZER
                ecall

                la      s1, comm_tx_len
                lw      s2, 0[s1]           ; s2 = length
                
                li      s3, 0               ; index
comm_send_loop
                beqz    s2, comm_send_newline
                la      t0, comm_tx_buffer
                add     t0, t0, s3
                lb      a0, 0[t0]
                li      a7, SYS_UART_PUT
                ecall
                addi    s3, s3, 1
                blt     s3, s2, comm_send_loop

comm_send_newline
                li      a0, COMM_ASCII_NEWLINE
                li      a7, SYS_UART_PUT
                ecall

                ; Reset buffer
                sw      zero, 0[s1]

                lw      ra, 0[sp]
                lw      s1, 4[sp]
                lw      s2, 8[sp]
                lw      s3, 12[sp]
                addi    sp, sp, 16
                ret

; --- Subroutine: comm_append_char ---
; Arguments: a0 = character to append to tx_buffer
; Description: Adds a single character to the transmission buffer.
comm_append_char
                la      t0, comm_tx_len
                lw      t1, 0[t0]
                li      t2, COMM_MAX_BUF
                bge     t1, t2, comm_append_exit
                
                la      t2, comm_tx_buffer
                add     t2, t2, t1
                sb      a0, 0[t2]
                addi    t1, t1, 1
                sw      t1, 0[t0]
comm_append_exit
                ret

; --- Subroutine: comm_get_rx_buffer ---
; Returns: a0 = Pointer to rx_buffer
comm_get_rx_buffer
                la      a0, comm_rx_buffer
                ret

; --- Subroutine: comm_reset_rx ---
comm_reset_rx
                la      t0, comm_rx_len
                sw      zero, 0[t0]
                ret

; --- Subroutine: comm_get_tx_len ---
comm_get_tx_len
                la      t0, comm_tx_len
                lw      a0, 0[t0]
                ret

; --- Subroutine: comm_backspace_tx ---
comm_backspace_tx
                la      t0, comm_tx_len
                lw      t1, 0[t0]
                beqz    t1, comm_backspace_exit
                subi    t1, t1, 1
                sw      t1, 0[t0]
comm_backspace_exit
                ret

; --- Data Allocations ---
                align
comm_tx_buffer  DEFS    128
comm_tx_len     defw    0
comm_rx_buffer  DEFS    128
comm_rx_len     defw    0
