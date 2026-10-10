; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------

; System Return Booleans
TRUE            EQU     1
FALSE           EQU     0

; System Register Masks
MSTATUS_MPP_MASK EQU    0x1800
MSTATUS_MPIE_MIE_MASK EQU    0x0088
MIE_MEI_MASK     EQU    0x0800
MCAUSE_MASK      EQU    0x0F


; Hardware Base Addresses
LCD_BASE        EQU     0x00010100
LCD_DATA        EQU     0x0
LCD_CTRL        EQU     0x1
TIMER_BASE      EQU     0x00010200
BUTTON_PORT     EQU     0x00010000
HALT_PORT       EQU     0x00010700
SYS_CTRL_BASE   EQU     0x00010700
PIN_FN_REG      EQU     0x08
LED_FN_REG      EQU     0x0C
INT_CONTROL     EQU     0x00010400
INT_EN_OFFSET   EQU     0x04
INT_REQ_OFFSET  EQU     0x08

; VDU Peripheral Addresses
VDU_BASE        EQU     0x00010600
VDU_SCREEN_BASE EQU     0x0
VDU_MODE        EQU     0x4

; User Peripheral Addresses
USER_UART_BASE  EQU     0x0002_0000
UART_DATA       EQU     0x00
UART_STAT       EQU     0x04
UART_BAUD       EQU     0x08
UART_BUZ        EQU     0x0C

; UART Status/Control Bits
UART_RX_RDY     EQU     0x01
UART_RX_ERR     EQU     0x02
UART_TX_RDY     EQU     0x10
UART_RX_ERR_IE  EQU     0x03    ; RX + RX_ERR Interrupt Enable
UART_FULL_IE    EQU     0x13    ; RX + RX_ERR + TX Interrupt Enable

; Interrupt Controller Bits
INT_RX_BIT      EQU     0x01
INT_TX_BIT      EQU     0x02
INT_ERR_BIT     EQU     0x04
UART_ERR_BIT    EQU     0x04
INT_TIMER_BIT   EQU     0x10
TIMER_BIT_OFFSET EQU    0x10
INT_ALL_ENABLED EQU     0x07    ; UART RX/TX/ERR ONLY (Timer disabled for debug)

; FIFO Configuration
FIFO_SIZE       EQU     128
FIFO_MASK       EQU     (FIFO_SIZE - 1)

; System Configuration Masks
SYS_UART_PINS_MASK EQU  0xC0000000
SYS_BUZZER_PINS_MASK EQU 0x000000C0
SYS_LED_LCD_EXP_MASK EQU 0x2FF

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

; MCAUSE Constants
USER_ECALL       EQU    8       ; exception code number for a ecall from U-mode
MEI_CODE         EQU    11

; LCD Control bits
LCD_CLEAR        EQU    1
LCD_RS_CMD       EQU    0b0000
LCD_RS_DATA      EQU    0b0010
LCD_E_HIGH       EQU    0b0100
LCD_E_LOW        EQU    0b0000
LCD_READ_BF      EQU    0b0001
LCD_BUSY_FLAG    EQU    0x80
LCD_DELAY_CYCLES EQU    6

; Timer Peripheral Configurations
TIMER_REG_LIMIT  EQU    0x04
TIMER_REG_STATUS EQU    0x0C
TIMER_REG_CLEAR  EQU    0x10
TIMER_REG_CTRL   EQU    0x14

TIMER_1HZ_LIMIT  EQU    999999  ; 1 million ticks minus one for the 1MHz clock
TIMER_1kHZ_LIMIT EQU    999     ; 1 thousand ticks minus one for the 1MHz clock to send an interrupt every millisecond
TIMER_CFG_EN_MOD EQU    0b0011  ; activates timer and enables modulus mode
TIMER_CFG_INTEN  EQU    0b1000  ; activates intterupt firing from the peripheral
TIMER_CLR_TERM   EQU    0x10    ; bit to clear terminal count of the timer

; PIO Peripheral Address and Offsets
PIO_BASE         EQU    0x10300
PIO_DATA         EQU    0x0
PIO_DIRECTION    EQU    0x4
PIO_CLEAR        EQU    0x8
PIO_SET          EQU    0xC

; PIO Bit Selections
PIO_ROWS_OUTPUT  EQU    0xF00
PIO_COLS_INPUT   EQU    0xF000
PIO_COL_OFFSET   EQU    12
PIO_BIT_OFFSET   EQU    8

; Keyboard Scanning Constants
KEY_COLS         EQU    4
DEBOUNCE_THRESHOLD EQU  5
SCAN_ROW_MASK    EQU    0x3

; Button Port Offsets and Masks
BTN_BYTE_OFFSET  EQU    1
BTN_MASK_ALL     EQU    0xF

; Shared Memory Variables between User and OS Spaces
TIMER_COUNT      EQU    shared_timer


; ------------------------------------------------------------------------------
; Operating System Initialisation (Machine Mode)
; ------------------------------------------------------------------------------
                ORG     0x00000000          ; Protected OS region

system_init
                la      sp, os_stack_base   ; Initialise OS stack
                la      t0, os_trap_handler ; Install trap vector
                csrw    MTVEC, t0
                csrw    MSCRATCH, sp        ; Preserve OS stack pointer
                la      sp, user_stack_base ; Switch to User stack
                la      t0, user_main       ; Set user entry point
                csrw    MEPC, t0            ; Set mret destination to user entry point

                ; Privilege drop and entry to user space
                li      t0, MSTATUS_MPP_MASK  ; Clear MPP bits (Target = User Mode)
                csrc    MSTATUS, t0

                ; Correct MPIE/MIE logic:
                li      t0, 0x80            ; MSTATUS_MPIE is bit 7
                csrs    MSTATUS, t0         ; MPIE = 1 (Interrupts ON when mret)

                li      t0, 0x08            ; MSTATUS_MIE is bit 3
                csrc    MSTATUS, t0         ; MIE = 0 (Interrupts OFF during Machine Mode)

                ; --- Minimal Polled Mode for Debugging ---
                ; Interrupts are globally OFF in the controller for now
                li      t0, INT_CONTROL
                sw      zero, INT_EN_OFFSET[t0]

                ; VDU Initialization: Setup 640x480 8-bit color framestore - DISABLED FOR DEBUG
                ; li      t0, VDU_BASE
                ; li      t1, 0               ; Framestore start address (0 offset from 0x00100000)
                ; sw      t1, VDU_SCREEN_BASE[t0]
                ; li      t1, 0               ; Mode 0: 640x480, 8bpp
                ; sw      t1, VDU_MODE[t0]

                mret                        ; Enter User Mode

                ; ------------------------------------------------------------------------------
                ; ------------------------------------------------------------------------------
                ; OS Trap Handler (Machine Mode)
                ; ------------------------------------------------------------------------------
                align   4
                os_trap_handler
                csrrw   sp, MSCRATCH, sp    ; Swap User SP with Machine SP

                ; Save context
                subi    sp, sp, 32          
                sw      a7, 0[sp]
                sw      ra, 4[sp]
                sw      t0, 8[sp]
                sw      t1, 12[sp]
                sw      t2, 16[sp]
                sw      t3, 20[sp]
                sw      t4, 24[sp]
                sw      a0, 28[sp]

                csrr    t0, MCAUSE          ; Identify trap source
                bltz    t0, interrupt_handler    ; Branch if HW interrupt
                li      t1, USER_ECALL
                bne     t0, t1, os_fatal_trap

                ; ------------------------------------------------------------------------------
                ; ECALL Dispatcher
                ; ------------------------------------------------------------------------------
                ecall_handler
                ; Enhanced scalable Jump Table for ECALLs
                bltz    a7, os_trap_exit
                li      t0, SYS_BUZZER
                bgt     a7, t0, os_trap_exit

                la      t0, ecall_vector_table
                slli    t1, a7, 2           ; multiply syscall number by 4 for word offset
                add     t0, t0, t1
                lw      t2, 0[t0]
                jr      t2                  ; execute specific system service

                align
                ecall_vector_table
                defw    os_trap_exit        ; 0: Invalid    
                defw    sys_print           ; 1: SYS_PRINT_CHAR
                defw    sys_halt            ; 2: SYS_EXIT
                defw    os_trap_exit        ; 3: SYS_TIMER_INIT
                defw    sys_timer_check     ; 4: SYS_TIMER_CHECK
                defw    sys_read_buttons    ; 5: SYS_READ_BUTTONS
                defw    sys_lcd_cmd         ; 6: SYS_LCD_CMD
                defw    os_trap_exit        ; 7: SYS_LCD_CLEAR
                defw    sys_get_key         ; 8: SYS_GET_KEY
                defw    sys_uart_put        ; 9: SYS_UART_PUT
                defw    sys_uart_get        ; 10: SYS_UART_GET
                defw    sys_buzzer          ; 11: SYS_BUZZER

                ; ------------------------------------------------------------------------------
                ; OS Services
                ; ------------------------------------------------------------------------------
                sys_print
                call    os_lcd_wait
                li      t3, LCD_BASE
                li      t4, LCD_RS_DATA     ; RS=1, R/W=0 (Data Mode)
                sb      t4, LCD_CTRL[t3]
                sb      a0, LCD_DATA[t3]
                ori     t4, t4, LCD_E_HIGH  ; E=1
                sb      t4, LCD_CTRL[t3]
                call    os_lcd_delay
                andi    t4, t4, LCD_RS_DATA ; RS=1, R/W=0, E=0
                sb      t4, LCD_CTRL[t3]
                j       os_trap_exit

                sys_lcd_cmd
                call    os_lcd_wait
                li      t3, LCD_BASE
                li      t4, LCD_RS_CMD      ; RS=0, R/W=0 (Command Mode)
                sb      t4, LCD_CTRL[t3]
                sb      a0, LCD_DATA[t3]
                ori     t4, t4, LCD_E_HIGH  ; E=1
                sb      t4, LCD_CTRL[t3]
                call    os_lcd_delay
                andi    t4, t4, LCD_E_LOW   ; E=0
                sb      t4, LCD_CTRL[t3]
                j       os_trap_exit

                sys_timer_check
                li      t3, TIMER_BASE
                lw      t0, TIMER_REG_STATUS[t3]
                bgez    t0, timer_not_ready     ; bit 31(sign bit) is 0 until terminal count
                li      t1, TIMER_CLR_TERM
                sw      t1, TIMER_REG_CLEAR[t3] ; Write to clear register to reset terminal flag
                li      a0, TRUE                ; return True directly to user in a0
                j       os_trap_exit
                timer_not_ready
                li      a0, FALSE               ; return false directly to user in a0
                j       os_trap_exit

                sys_get_key
                la      t0, fifo_head
                lw      t1, 0[t0]
                la      t2, fifo_tail
                lw      t3, 0[t2]
                beq     t1, t3, fifo_empty
                    ; pop byte from fifo
                    la      t2, fifo_buffer
                    add     t2, t2, t1      ; fifo_buffer + head
                    lb      a0, 0[t2]       ; read key directly to a0
                    addi    t1, t1, 1       ; head++
                    andi    t1, t1, FIFO_MASK ; wrap correctly inside 128 items
                    sw      t1, 0[t0]
                    j       os_trap_exit
                fifo_empty
                    li      a0, -1          ; Return empty flag
                    j       os_trap_exit

                sys_read_buttons
                    li      t3, BUTTON_PORT
                    lbu     a0, BTN_BYTE_OFFSET[t3] ; bypass slide switches to read byte 1
                    andi    a0, a0, BTN_MASK_ALL    ; mask out unused upper bits and pass to a0
                    j       os_trap_exit

                sys_uart_put
                    ; 1. Push a0 into uart_tx_fifo
                    la      t0, uart_tx_fifo_tail
                    lw      t1, 0[t0]           ; t1 = tail
                    addi    t2, t1, 1
                    andi    t2, t2, FIFO_MASK   ; t2 = next_tail

                    la      t3, uart_tx_fifo_head
                    lw      t3, 0[t3]           ; t3 = head
                sys_uart_put_wait
                    beq     t2, t3, sys_uart_put_wait ; Block if FIFO is full

                    la      t4, uart_tx_fifo_buffer
                    add     t4, t4, t1
                    sb      a0, 0[t4]           ; store byte
                    sw      t2, 0[t0]           ; update tail

                    ; 2. Enable TX interrupt in the UART peripheral
                    li      t3, USER_UART_BASE
                    li      t0, UART_FULL_IE    ; RX (0x01) | RX_ERR (0x02) | TX (0x10)
                    sw      t0, UART_STAT[t3]   ; Write back to Control

                    j       os_trap_exit

                sys_uart_get
                    la      t0, uart_fifo_head
                    lw      t1, 0[t0]
                    la      t2, uart_fifo_tail
                    lw      t3, 0[t2]
                    beq     t1, t3, uart_rx_empty
                        ; pop byte from uart_fifo
                        la      t2, uart_fifo_buffer
                        add     t2, t2, t1      ; buffer + head
                        lbu     a0, 0[t2]       ; read byte
                        addi    t1, t1, 1       ; head++
                        andi    t1, t1, FIFO_MASK ; wrap
                        sw      t1, 0[t0]
                        j       os_trap_exit
                uart_rx_empty
                    li      a0, -1
                    j       os_trap_exit

                sys_buzzer
                    li      t3, USER_UART_BASE
                    sw      a0, UART_BUZ[t3]
                    j       os_trap_exit

                os_fatal_trap
                ; WRITE MCAUSE TO LEDs for DEBUGGING
                li      t3, BUTTON_PORT     ; 0x10000
                sw      t0, 0[t3]           ; Write raw MCAUSE to LED bits 7:0
                sys_halt
                li      t0, HALT_PORT
                sb      zero, [t0]
                j       sys_halt

                ; ------------------------------------------------------------------------------
                ; Hardware Interrupt Handler
                ; ------------------------------------------------------------------------------
                interrupt_handler
                andi    t0, t0, MCAUSE_MASK     ; clearing upper bits to check for interrupt type
                li      t1, MEI_CODE

                bne     t0, t1, hw_interrupt_exit


check_timer_int
                ; 1. Check for Timer Interrupt (Highest frequency, 1kHz)
                li      t0, INT_CONTROL
                lw      t1, INT_REQ_OFFSET[t0]
                andi    t1, t1, INT_TIMER_BIT
                beqz    t1, check_err_int

                ; Acknowledge the Interrupt to Prevent an Infinite Loop
                li      t0, TIMER_BASE
                li      t1, TIMER_CLR_TERM  ;CHECK COULD BE TRUE instead of TIMER_CLR_TERM
                sw      t1, TIMER_REG_CLEAR[t0]

                ; Keyboard scanning & debouncing
                la      t0, scan_row
                lw      t2, 0[t0]        ; t2 = scan_row 0..3

                li      t0, PIO_BASE
                lw      t3, PIO_DATA[t0]
                srli    t3, t3, PIO_COL_OFFSET ; shift cols to bits 0-3
                andi    t3, t3, 0xF      ; t3 = column bits

                ; 2. Update debounce counters for the 4 keys in this row
                li      t4, 0            ; col_index
col_debounce_loop
                ; Determine pressed status
                srl     t0, t3, t4
                andi    t0, t0, 1        ; t0 = 1 (pressed), 0 (released)

                ; Compute key_index to match physical hardware layout
                ; Index = ((3 - col_index) * 4) + scan_row
                li      a0, (KEY_COLS - 1)
                sub     a0, a0, t4       
                slli    a0, a0, 2        
                add     a0, a0, t2       ; a0 = key_index

                ; CLEVER MOVE: Reusing Machine Mode ra/a7 as scratchpads.
                ; This is safe because user's ra/a7 were already saved in the trap entry.
                ; This avoids using t5/t6 and keeps the stack frame small.
                la      a7, debounce_counters
                add     a7, a7, a0  
                lbu     a7, 0[a7]        ; a7 = debounce counter

                beqz    t0, release_key

press_key
                li      t0, DEBOUNCE_THRESHOLD ; Debounce threshold
                bge     a7, t0, done_debounce ; already stable
                addi    a7, a7, 1        ; increment counter
                bne     a7, t0, done_debounce ; not yet threshold
                
                ; Reached threshold, record key-down in FIFO!
                la      t0, fifo_tail
                lw      a7, 0[t0]        ; a7 = tail
                addi    ra, a7, 1
                andi    ra, ra, FIFO_MASK ; ra = next_tail
                
                la      t1, fifo_head    ; temp reuse of t1
                lw      t1, 0[t1]        ; t1 = head
                beq     ra, t1, debounce_overflow ; Overflow: drop key
                
                la      t1, fifo_buffer
                add     t1, t1, a7
                sb      a0, 0[t1]        ; push key_index
                sw      ra, 0[t0]        ; update tail
                
debounce_overflow
                li      a7, DEBOUNCE_THRESHOLD ; restore a7 for done_debounce
                j       done_debounce

release_key
                li      a7, 0            ; quickly reset debounce clock

done_debounce
                la      t0, debounce_counters
                add     t0, t0, a0
                sb      a7, 0[t0]        ; save updated counter

                addi    t4, t4, 1
                li      t0, KEY_COLS
                blt     t4, t0, col_debounce_loop

                ; 3. Move to next scan_row
                addi    t2, t2, 1
                andi    t2, t2, SCAN_ROW_MASK
                la      t0, scan_row
                sw      t2, 0[t0]

                ; 4. Clear all rows, then activate the next row for the next interrupt
                li      t0, PIO_BASE
                li      t3, PIO_ROWS_OUTPUT
                sw      t3, PIO_CLEAR[t0]
                
                li      t3, 1
                sll     t3, t3, t2       ; 1 << next scan_row
                slli    t3, t3, PIO_BIT_OFFSET ; shift into row bits (8-11)
                sw      t3, PIO_SET[t0]

                ; Increment Shared Variable for Time
                li      t0, TIMER_COUNT
                lw      t2, [t0]
                addi    t2, t2, 1
                sw      t2, [t0]

check_err_int
                ; 2. Check for UART Error (Bit 2)
                li      t0, INT_CONTROL
                lw      t1, INT_REQ_OFFSET[t0]
                andi    t2, t1, UART_ERR_BIT
                beqz    t2, check_uart_rx

                ; Handle Error: Discard byte and clear status register to reset hardware interrupt line
                li      t2, USER_UART_BASE
                lw      t3, UART_STAT[t2]   ; Read status to clear error flags
                la      t2, uart_error_count
                lw      t3, 0[t2]
                addi    t3, t3, 1
                sw      t3, 0[t2]

check_uart_rx
                ; 3. Check for UART RX Ready (Bit 0)
                li      t0, INT_CONTROL
                lw      t1, INT_REQ_OFFSET[t0]
                andi    t0, t1, INT_RX_BIT
                beqz    t0, check_uart_tx

                ; Capture byte into UART FIFO
                li      t0, USER_UART_BASE
                lw      t2, UART_DATA[t0]   ; Read data
                
                la      t0, uart_fifo_tail
                lw      t3, 0[t0]           ; t3 = tail
                addi    t4, t3, 1
                andi    t4, t4, FIFO_MASK   ; t4 = next_tail
                
                la      t0, uart_fifo_head
                lw      t0, 0[t0]           ; t0 = head
                beq     t4, t0, check_uart_tx ; Overflow: drop byte
                
                la      t0, uart_fifo_buffer
                add     t0, t0, t3
                sb      t2, 0[t0]           ; push byte
                la      t0, uart_fifo_tail
                sw      t4, 0[t0]           ; update tail

check_uart_tx
                ; 4. Check for UART TX Ready (Bit 1)
                li      t0, INT_CONTROL
                lw      t1, INT_REQ_OFFSET[t0]
                andi    t0, t1, INT_TX_BIT  ; UART TX Ready interrupt bit
                beqz    t0, hw_interrupt_exit

                ; We have a TX interrupt! Let's check the software FIFO.
                la      t0, uart_tx_fifo_head
                lw      t2, 0[t0]           ; t2 = head
                la      t3, uart_tx_fifo_tail
                lw      t3, 0[t3]           ; t3 = tail
                
                beq     t2, t3, disable_tx_int  ; If empty, disable TX interrupt

                ; Not empty! Pop byte and send it to hardware
                la      t3, uart_tx_fifo_buffer
                add     t3, t3, t2
                lbu     t4, 0[t3]           ; t4 = byte to send
                
                li      t3, USER_UART_BASE
                sw      t4, UART_DATA[t3]   ; Send byte
                
                addi    t2, t2, 1
                andi    t2, t2, FIFO_MASK   ; head = (head + 1) % 128
                sw      t2, 0[t0]           ; update head
                j       hw_interrupt_exit

disable_tx_int
                ; FIFO is empty, so disable the TX interrupt at the UART peripheral
                li      t0, USER_UART_BASE
                li      t2, UART_RX_ERR_IE  ; RX (0x01) | RX_ERR (0x02)
                
                sw      t2, UART_STAT[t0]
                j       hw_interrupt_exit

; ------------------------------------------------------------------------------
; Context Restore & Return to User Mode
; ------------------------------------------------------------------------------
os_trap_exit
                csrr    t0, MEPC
                addi    t0, t0, 4
                csrw    MEPC, t0           ; increment MEPC past the ecall instruction
                ; Syscalls return values directly in a0. We bypass hw_interrupt_exit's lw a0

                j common_interrupt_exit

hw_interrupt_exit
                lw      a0, 28[sp]          ; restore user a0 state (only for async interrupts)
common_interrupt_exit
                lw      a7, 0[sp]
                lw      ra, 4[sp]
                lw      t0, 8[sp]
                lw      t1, 12[sp]
                lw      t2, 16[sp]
                lw      t3, 20[sp]
                lw      t4, 24[sp]
                
                addi    sp, sp, 32
                csrrw   sp, MSCRATCH, sp
                mret

; ------------------------------------------------------------------------------
; OS Hardware Drivers (Machine Mode Only)
; ------------------------------------------------------------------------------
os_lcd_wait
                li      t3, LCD_BASE
wait_loop
                li      t1, LCD_READ_BF     ; R/W=1, RS=0, E=0
                sb      t1, LCD_CTRL[t3]
                ori     t1, t1, LCD_E_HIGH  ; E=1
                sb      t1, LCD_CTRL[t3]
                
                subi    sp, sp, 16
                sw      ra, 0[sp]
                call    os_lcd_delay
                lw      ra, 0[sp]
                addi    sp, sp, 16

                lb      t2, LCD_DATA[t3]    ; read busy flag
                
                li      t1, LCD_READ_BF     ; E=0
                sb      t1, LCD_CTRL[t3]

                subi    sp, sp, 16
                sw      ra, 0[sp]
                call    os_lcd_delay
                lw      ra, 0[sp]
                addi    sp, sp, 16
                
                andi    t2, t2, LCD_BUSY_FLAG   ; check busy flag by masking everything but bit 7
                bnez    t2, wait_loop           ; loops if busy flag is still high
                ret

os_lcd_delay
                li      t0, LCD_DELAY_CYCLES
delay_loop
                subi    t0, t0, 1
                bnez    t0, delay_loop
                ret


; ------------------------------------------------------------------------------
; Stack Allocation
; ------------------------------------------------------------------------------

                align   4
os_stack        DEFS    128
                align   4
os_stack_base

align

fifo_head       defw    0
fifo_tail       defw    0
fifo_buffer     DEFS    128

align

uart_fifo_head  defw    0
uart_fifo_tail  defw    0
uart_fifo_buffer DEFS   128

align

uart_tx_fifo_head defw  0
uart_tx_fifo_tail defw  0
uart_tx_fifo_buffer DEFS 128

uart_error_count defw   0

align   

scan_row        defw    0

align

debounce_counters DEFS  16
