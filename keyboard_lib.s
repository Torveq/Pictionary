; ------------------------------------------------------------------------------
;           Keyboard Library for Multi-Page Entry
;           Provides UI management and state transitions for the keyboard.
; ------------------------------------------------------------------------------

; Constants
KBD_NUM_PAGES        EQU    3
KBD_PAGE_SIZE        EQU    16

KBD_CODE_SEND        EQU    0xFF
KBD_CODE_SWITCH      EQU    0xFE
KBD_CODE_BACK        EQU    0x08
KBD_POLL_EMPTY       EQU    -1

; --- Subroutine: keyboard_init ---
keyboard_init
                la      t0, kbd_current_page
                sw      zero, 0[t0]
                ret

; --- Subroutine: keyboard_get_char ---
; Returns:   a0 = ASCII character, KBD_CODE_SEND, KBD_CODE_BACK, or -1 if no key.
; Side effects: Overwrites a0, a7, t0, t1, t2. Preserves ra.
; Description: May update internal page state and LCD.
keyboard_get_char
                subi    sp, sp, 16
                sw      ra, 0[sp]

kbd_get_loop
                li      a7, SYS_GET_KEY
                ecall
                
                li      t0, KBD_POLL_EMPTY
                beq     a0, t0, kbd_get_exit

                ; 2D Translate: Address = kbd_pages + (current_page * 16) + key_index
                la      t0, kbd_current_page
                lw      t1, 0[t0]
                slli    t1, t1, 4           ; t1 = current_page * 16
                add     t1, t1, a0          ; t1 = offset
                la      t2, kbd_pages
                add     t2, t2, t1
                lbu     a0, 0[t2]           ; loads mapped character

                ; Check for Switch Page code (Internal logic)
                li      t0, KBD_CODE_SWITCH
                bne     a0, t0, kbd_get_exit

                ; Handle Page Switch
                la      t0, kbd_current_page
                lw      t1, 0[t0]
                addi    t1, t1, 1
                li      t2, KBD_NUM_PAGES
                blt     t1, t2, kbd_switch_save
                li      t1, 0
kbd_switch_save
                sw      t1, 0[t0]
                call    keyboard_update_lcd
                j       kbd_get_loop        ; Loop to get next real key

kbd_get_exit
                lw      ra, 0[sp]
                addi    sp, sp, 16
                ret

; --- Subroutine: keyboard_update_lcd ---
; Side effects: Overwrites a0, a7, t0, t1. Preserves ra.
; Description: Updates the 2nd line of LCD with page info and restores cursor.
keyboard_update_lcd
                subi    sp, sp, 16
                sw      ra, 0[sp]
                
                ; 1. Move cursor to start of 2nd line
                li      a0, LCD_LINE2_START
                li      a7, SYS_LCD_CMD
                ecall
                
                ; 2. Print current page indicator string
                la      t0, kbd_current_page
                lw      t1, 0[t0]
                slli    t1, t1, 2           ; word offset
                la      t2, kbd_page_strs
                add     t2, t2, t1
                lw      a0, 0[t2]
                call    print_str
                
                ; 3. Move cursor back to current input position on 1st line
                ; Address = 0x80 + tx_buffer_len
                call    comm_get_tx_len
                mv      t1, a0
                li      a0, LCD_LINE1_START
                add     a0, a0, t1
                li      a7, SYS_LCD_CMD
                ecall
                
                lw      ra, 0[sp]
                addi    sp, sp, 16
                ret

; --- Data Allocations ---
                align
kbd_current_page defw    0

kbd_pages
                ; --- PAGE 0: Letters a-n ---
                defb    'a', 'b', 'c', 'd'
                defb    'e', 'f', 'g', 'h'
                defb    'i', 'j', 'k', 0xFE     ; 0xFE = Switch Page
                defb    'l', 'm', 'n', 0xFF     ; 0xFF = Send

                ; --- PAGE 1: Letters o-z + Space + Backspace ---
                defb    'o', 'p', 'q', 'r'
                defb    's', 't', 'u', 'v'
                defb    'w', 'x', 'y', 0xFE
                defb    'z', ' ', 0x08, 0xFF    ; 0x08 = Backspace

                ; --- PAGE 2: Numbers & Symbols ---
                defb    '1', '2', '3', '4'
                defb    '5', '6', '7', '8'
                defb    '9', '0', '.', 0xFE
                defb    ',', '?', '!', 0xFF

kbd_page_0_str  defb    '[', 'a', '-', 'n', ']', ' ', 0
kbd_page_1_str  defb    '[', 'o', '-', 'z', ']', ' ', 0
kbd_page_2_str  defb    '[', '1', '-', '9', ']', ' ', 0

                align
kbd_page_strs   defw    kbd_page_0_str, kbd_page_1_str, kbd_page_2_str
