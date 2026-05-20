org 100h

jmp start

; =========================================================================
; CONSTANTS
; =========================================================================
VIDMEM      equ 0B800h      ; Video Memory base address for Text Mode (80x25)

; Movement direction identifiers
UP          equ 0
DOWN        equ 1
LEFT        equ 2
RIGHT       equ 3

; =========================================================================
; VARIABLES & DATA SEGMENT
; =========================================================================
snakeRow    db 100 dup(0)   ; Array storing the row coordinates of each snake segment
snakeCol    db 100 dup(0)   ; Array storing the column coordinates of each snake segment

snakeLength db 3            ; Current length of the snake (Starts at 3)

direction   db RIGHT        ; Current moving direction of the snake

tailRow     db 0            ; Stores the previous row of the tail (used for erasing)
tailCol     db 0            ; Stores the previous column of the tail (used for erasing)

grow        db 0            ; Growth flag: 1 if snake ate an apple, 0 otherwise

appleRow    db 8            ; Current row coordinate of the apple
appleCol    db 30           ; Current column coordinate of the apple

lastTick    dw 0            ; Stores the system clock tick of the last movement

gameMode    db 0            ; Game Difficulty: 0 = Easy (Wrap around), 1 = Hard (Solid walls)

; Dashboard & Screen UI Strings
titleMsg    db 'The Snake by M&K'
titleLen    dw 16

opt1Msg     db '[1] Easy Mode (Wrap Around)'
opt1Len     dw 27

opt2Msg     db '[2] Hard Mode (Solid Walls)'
opt2Len     dw 27

loseMsg     db '  YOU LOSE!  '
msgLength   dw 13

retryMsg    db 'Press [1] to Try Again'
retryLength dw 22

; =========================================================================
; GAME INITIALIZATION ENTRY POINT
; =========================================================================
start:
    ; Set video mode to 03h (Standard Text Mode, 80 columns x 25 rows)
    ; This also clears the screen completely.
    mov ax, 0003h     
    int 10h

    ; Initialize the Extra Segment (ES) register to point to the Video Memory
    mov ax, VIDMEM
    mov es, ax

; =========================================================================
; DISPLAY DASHBOARD (MAIN MENU)
; =========================================================================
show_dashboard:
    ; 1. Print Game Title centered at Row 6, Col 32 (Light Green text)
    mov ah, 13h         ; BIOS string printing function
    mov al, 01h         ; Update cursor position after printing
    xor bh, bh          ; Video page 0
    mov bl, 0Ah         ; Light Green attribute
    mov cx, [titleLen]  ; Length of title string
    mov dh, 6           ; Row 6
    mov dl, 32          ; Column 32
    push cs
    pop es              ; Set ES to Code Segment where strings are stored
    lea bp, [titleMsg]  ; Load effective address of string into BP
    int 10h             

    ; 2. Print Option 1 (Easy Mode) at Row 10, Col 26 (White text)
    mov ah, 13h         
    mov al, 01h         
    xor bh, bh          
    mov bl, 0Fh         ; Bright White attribute
    mov cx, [opt1Len] 
    mov dh, 10          
    mov dl, 26          
    push cs
    pop es
    lea bp, [opt1Msg]
    int 10h             

    ; 3. Print Option 2 (Hard Mode) at Row 12, Col 26 (White text)
    mov ah, 13h         
    mov al, 01h         
    xor bh, bh          
    mov bl, 0Fh         
    mov cx, [opt2Len] 
    mov dh, 12                                                             
    mov dl, 26          
    push cs
    pop es
    lea bp, [opt2Msg]
    int 10h             

wait_for_mode:
    ; Blocking keyboard read to capture user mode selection
    mov ah, 00h
    int 16h

    cmp al, '1'
    je set_easy_mode

    cmp al, '2'
    je set_hard_mode

    jmp wait_for_mode   ; Keep waiting if any other key is pressed

set_easy_mode:
    mov byte ptr [gameMode], 0
    jmp start_game_play

set_hard_mode:
    mov byte ptr [gameMode], 1

start_game_play:
    ; Clear the menu screen before entering the actual gameplay loop
    mov ax, 0003h
    int 10h
    mov ax, VIDMEM
    mov es, ax

; =========================================================================
; INITIAL GAME PLAYGROUND STATE
; =========================================================================
init_game_state:
    ; Reset initial gameplay parameters
    mov byte ptr [snakeLength], 3
    mov byte ptr [direction], RIGHT
    mov byte ptr [grow], 0
    mov byte ptr [appleRow], 8
    mov byte ptr [appleCol], 30

    ; Reset external emu8086 hardware LED screen to zero
    call UpdateLEDScore 

    ; Setup initial coordinates for Snake Head (Segment 0)
    mov snakeRow[0], 10
    mov snakeCol[0], 20

    ; Setup initial coordinates for Snake Body (Segment 1)
    mov snakeRow[1], 10
    mov snakeCol[1], 19

    ; Setup initial coordinates for Snake Tail (Segment 2)
    mov snakeRow[2], 10
    mov snakeCol[2], 18

    ; Render initial frame objects
    call DrawFullSnake
    call DrawApple

; =========================================================================
; MAIN GAME LOOP (Executes continuously during gameplay)
; =========================================================================
main_loop:

    call ReadInput          ; Check and update direction from keyboard

    call SaveTail           ; Record the exact position of the tail before moving

    call ShiftBody          ; Pass coordinates forward down the body segments

    call MoveHead           ; Advance the snake's head forward based on direction

    call CheckBorders       ; Handle boundary checking (Wrap around or Wall crash)

    call CheckSelfCollision ; Ensure the snake hasn't crashed into itself

    call CheckApple         ; Verify if the head collides with an apple

    call EraseTail          ; Clear the snake's oldest trail element from screen

    call DrawHead           ; Draw the new position of the head

    call DrawApple          ; Persist and draw apple graphic onto the screen

    call WaitTick           ; Create game delay based on hardware timer ticks

    jmp main_loop           ; Restart loop sequence

; =========================================================================
; KEYBOARD INPUT HANDLER
; =========================================================================
ReadInput:
    ; Non-blocking keyboard status check
    mov ah, 01h
    int 16h
    jz done_input       ; Exit safely if no key was pressed

    ; Read keystroke code from buffer
    mov ah, 00h
    int 16h

    ; Identify directional arrow keys via scan codes (AH)
    cmp ah, 48h
    je set_up

    cmp ah, 50h
    je set_down

    cmp ah, 4Bh
    je set_left

    cmp ah, 4Dh
    je set_right

    jmp done_input

set_up:
    ; Prevent immediate reverse disaster (cannot move UP if moving DOWN)
    cmp byte ptr [direction], DOWN  
    je done_input
    mov byte ptr [direction], UP
    jmp done_input

set_down:
    cmp byte ptr [direction], UP    
    je done_input
    mov byte ptr [direction], DOWN
    jmp done_input

set_left:
    cmp byte ptr [direction], RIGHT 
    je done_input
    mov byte ptr [direction], LEFT
    jmp done_input

set_right:
    cmp byte ptr [direction], LEFT  
    je done_input
    mov byte ptr [direction], RIGHT

done_input:
    ret

; =========================================================================
; SAVE OLD TAIL POSITION
; =========================================================================
SaveTail:
    ; Extract coordinates of the last segment prior to structural shifting
    xor cx, cx
    mov cl, [snakeLength]
    dec cx
    mov si, cx

    mov al, snakeRow[si]
    mov [tailRow], al

    mov al, snakeCol[si]
    mov [tailCol], al

    ret

; =========================================================================
; SHIFT BODY SEGMENTS
; =========================================================================
ShiftBody:
    ; Iterate backwards from tail down to neck, copying previous coordinates
    xor cx, cx
    mov cl, [snakeLength]
    dec cx

shift_loop:
    mov si, cx
    dec si

    mov al, snakeRow[si]
    mov snakeRow[si+1], al

    mov al, snakeCol[si]
    mov snakeCol[si+1], al

    loop shift_loop

    ret

; =========================================================================
; MOVE HEAD POSITION
; =========================================================================
MoveHead:
    ; Modify head index coordinates according to active direction vector
    cmp byte ptr [direction], UP
    je move_up

    cmp byte ptr [direction], DOWN
    je move_down

    cmp byte ptr [direction], LEFT
    je move_left

    cmp byte ptr [direction], RIGHT
    je move_right

move_up:
    dec byte ptr [snakeRow[0]]
    call Delay
    ret

move_down:
    inc byte ptr [snakeRow[0]]
    call delay
    ret

move_left:
    dec byte ptr [snakeCol[0]]
    ret

move_right:
    inc byte ptr [snakeCol[0]]
    ret

; =========================================================================
; BORDER LAWS (EASY WRAP VS HARD WALLS)
; =========================================================================
CheckBorders:
    mov al, [snakeCol[0]]
    
    ; COLUMN BOUNDARY CHECK (X-Axis limits: 0 - 79)
    cmp al, 80          
    jae handle_col_border   ; Triggers if Col >= 80 or Col Underflows to 255
    jmp check_rows

handle_col_border:
    cmp byte ptr [gameMode], 1
    je game_over            ; Instantly crash if Hard Mode is active
    
    ; Easy Mode Wrap-around Logic
    cmp al, 254         
    jae set_col_max         ; If it went past left side (255), warp to right wall
    mov byte ptr [snakeCol[0]], 0  ; Else it went past right side, warp to left wall
    jmp check_rows

set_col_max:
    mov byte ptr [snakeCol[0]], 79

check_rows:
    ; ROW BOUNDARY CHECK (Y-Axis limits: 0 - 24)
    mov al, [snakeRow[0]]
    cmp al, 25          
    jae handle_row_border   ; Triggers if Row >= 25 or Row Underflows to 255
    ret

handle_row_border:
    cmp byte ptr [gameMode], 1
    je game_over            ; Instantly crash if Hard Mode is active
    
    ; Easy Mode Wrap-around Logic
    cmp al, 254         
    jae set_row_max         ; If it went past top ceiling (255), warp to floor
    mov byte ptr [snakeRow[0]], 0  ; Else it went past bottom floor, warp to ceiling
    ret

set_row_max:
    mov byte ptr [snakeRow[0]], 24
    ret

; =========================================================================
; SELF COLLISION DETECTOR
; =========================================================================
CheckSelfCollision:
    ; A snake with length less than 4 cannot physically hit its own body
    cmp byte ptr [snakeLength], 4   
    jb done_collision

    xor cx, cx
    mov cl, [snakeLength]
    dec cx                         

    mov si, 1               ; Start scanning from body segment index 1 (neck)

collision_loop:
    mov al, snakeRow[0]
    cmp al, snakeRow[si]
    jne next_segment        ; If row does not match, proceed to next chunk

    mov al, snakeCol[0]
    cmp al, snakeCol[si]
    je game_over            ; If BOTH row and column match, head hit body!

next_segment:
    inc si
    loop collision_loop

done_collision:
    ret

; =========================================================================
; GAME OVER & RETRY MANAGER
; =========================================================================
game_over:
    ; 1. Draw "YOU LOSE!" container at Row 11, Col 33 (White on Red text)
    mov ah, 13h         
    mov al, 01h         
    xor bh, bh          
    mov bl, 4Fh         ; White text on Red background
    mov cx, [msgLength] 
    mov dh, 11          
    mov dl, 33          
    push cs
    pop es
    lea bp, [loseMsg]
    int 10h             

    ; 2. Draw "Press [1] to Try Again" at Row 13, Col 29 (White on Black text)
    mov ah, 13h         
    mov al, 01h         
    xor bh, bh          
    mov bl, 0Fh         ; Normal white text
    mov cx, [retryLength] 
    mov dh, 13          
    mov dl, 29          
    push cs
    pop es
    lea bp, [retryMsg]
    int 10h             

wait_for_one:
    ; Halt execution in loop awaiting key '1' to confirm reset
    mov ah, 00h
    int 16h
    cmp al, '1'         
    jne wait_for_one    

restart_to_dashboard:
    ; Clean state transition back to Main Menu Dashboard
    jmp start 

; =========================================================================
; APPLE COLLISION CHECKER
; =========================================================================
CheckApple:
    mov al, snakeRow[0]
    cmp al, [appleRow]
    jne no_apple

    mov al, snakeCol[0]
    cmp al, [appleCol]
    jne no_apple

    ; Action taken when Head matches Apple coordinates:
    inc byte ptr [snakeLength]  ; Grow snake configuration
    
    call UpdateLEDScore         ; Push updated score values to emu8086 LED panel

    mov byte ptr [grow], 1      ; Block tail erasing routine for this turn

    ; Assign last segment coordinates immediately to prevent trailing artifacts
    xor cx, cx
    mov cl, [snakeLength]
    dec cx
    mov si, cx
    
    mov al, [tailRow]
    mov snakeRow[si], al
    mov al, [tailCol]
    mov snakeCol[si], al

    call SpawnApple             ; Drop a brand new random apple

no_apple:
    ret

; =========================================================================
; RANDOM APPLE GENERATOR
; =========================================================================
SpawnApple:
    ; Generate random column component using system clock ticks (0 to 79)
    mov ah, 00h
    int 1Ah             ; Get ticks since midnight into DX
    mov ax, dx
    xor dx, dx
    mov bx, 80
    div bx              ; Divide AX by 80, remainder falls in DX (0-79)
    mov [appleCol], dl

    ; Generate random row component using system clock ticks (0 to 24)
    mov ah, 00h
    int 1Ah             
    mov ax, dx
    xor dx, dx
    mov bx, 25
    div bx              ; Divide AX by 25, remainder falls in DX (0-24)
    mov [appleRow], dl

    ret

; =========================================================================
; TRAIL CLEANER (ERASE TAIL FROM SCREEN)
; =========================================================================
EraseTail:
    cmp byte ptr [grow], 1
    je skip_erase       ; Bypass erasing if growth flag is tripped

    mov al, [tailRow]
    mov bl, [tailCol]

    call CalculateOffset ; Fetch target memory address inside screen space

    mov al, ' '         ; Erase character (ASCII space)
    mov ah, 07h         ; Default text attributes (Light grey)

    mov es:[di], ax      ; Clear character directly in VRAM
    ret

skip_erase:
    mov byte ptr [grow], 0 ; Clear flag for subsequent standard cycles
    ret

; =========================================================================
; DRAW HEAD SYMBOL
; =========================================================================
DrawHead:
    mov al, snakeRow[0]
    mov bl, snakeCol[0]

    call CalculateOffset

    mov al, 219         ; Complete solid square ASCII block
    mov ah, 0Ah         ; Bright Green text color

    mov es:[di], ax      ; Commit to Video Memory
    ret

; =========================================================================
; DRAW ENTIRE INITIAL SNAKE STRUCTURE
; =========================================================================
DrawFullSnake:
    xor cx, cx
    mov cl, [snakeLength]
    xor si, si

draw_loop:
    mov al, snakeRow[si]
    mov bl, snakeCol[si]

    call CalculateOffset

    mov al, 219
    mov ah, 0Ah

    mov es:[di], ax

    inc si
    loop draw_loop

    ret

; =========================================================================
; DRAW APPLE SYMBOL
; =========================================================================
DrawApple:
    mov al, [appleRow]
    mov bl, [appleCol]

    call CalculateOffset

    mov al, '@'         ; Apple display glyph symbol
    mov ah, 0Ch         ; Bright Red text attribute color

    mov es:[di], ax      ; Render onto screen buffer
    ret

; =========================================================================
; CALCULATE MEMORY OFFSET FROM COORDINATES
; Formula: Offset = (Row * 160) + (Col * 2)
; Input: AL = Row, BL = Column | Output: DI = Calculated Offset
; =========================================================================
CalculateOffset:
    push ax
    push bx

    xor ah, ah
    mov bh, 160
    mul bh              ; AX = Row * 160
    mov di, ax          ; Move partial sum into Destination Index

    xor ax, ax
    mov al, bl
    shl ax, 1           ; AX = Column * 2 (Shift Left 1 is equivalent to multiplying by 2)
    add di, ax          ; Add to final VRAM Offset pointer

    pop bx
    pop ax
    ret

; =========================================================================
; HARDWARE DELAY ENGINE (CLOCK TICK SYNC)
; =========================================================================
WaitTick:
    mov ah, 00h
    int 1Ah             ; Read BIOS system timer counter

    cmp dx, [lastTick]
    je WaitTick         ; Continuous loop until clock tick shifts forward

    mov [lastTick], dx  ; Save current time stamp anchor for next tick
    ret

; =========================================================================
; UPDATE EMU8086 EXTERNAL LED SCREEN HARDWARE
; =========================================================================
UpdateLEDScore:
    push ax
    push dx

    xor ax, ax
    mov al, [snakeLength]
    sub al, 3           ; Calculate active Score (Apples Eaten = Total Length - 3)

    mov dx, 199         ; Virtual Hardware I/O Register Port Address for emu8086 LED Panel
    out dx, ax          ; Output score value directly to external device register

    pop dx
    pop ax
    ret

; =========================================================================
; Delay
; =========================================================================    
    
Delay:
    
    mov ah, 00h
    int 1Ah

    mov bx, dx
    add bx, 2

wait_tick:

    mov ah, 00h
    int 1Ah

    cmp dx, bx
    jl wait_tick

    ret
