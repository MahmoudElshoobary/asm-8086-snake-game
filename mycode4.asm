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

axisFlip    db 0            ; Variable to balance vertical movement speed

; Dashboard & Screen UI Strings
titleMsg    db 'The Snake by M&K'
titleLen    dw 16

opt1Msg     db '[1] Easy Mode (Wrap Around)'
opt1Len     dw 27

opt2Msg     db '[2] Hard Mode (Solid Walls)'
opt2Len     dw 27

loseMsg     db '  YOU LOSE! Score: 00  '
msgLength   dw 23

retryMsg    db 'Press [1] to Try Again'
retryLength dw 22

; =========================================================================
; GAME INITIALIZATION ENTRY POINT
; =========================================================================
start:
    ; Set video mode to 03h (Standard Text Mode, 80 columns x 25 rows)
    mov ax, 0003h     
    int 10h

    ; Initialize the Extra Segment (ES) register to point to the Video Memory
    mov ax, VIDMEM
    mov es, ax

; =========================================================================
; DISPLAY DASHBOARD (MAIN MENU)
; =========================================================================
show_dashboard:
    mov ah, 13h         
    mov al, 01h         
    xor bh, bh          
    mov bl, 0Ah         ; Light Green attribute
    mov cx, [titleLen]  
    mov dh, 6           
    mov dl, 32          
    push cs
    pop es              
    lea bp, [titleMsg]  
    int 10h             

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
    mov ah, 00h
    int 16h

    cmp al, '1'
    je set_easy_mode

    cmp al, '2'
    je set_hard_mode

    jmp wait_for_mode   

set_easy_mode:
    mov byte ptr [gameMode], 0
    jmp start_game_play

set_hard_mode:
    mov byte ptr [gameMode], 1

start_game_play:
    mov ax, 0003h
    int 10h
    mov ax, VIDMEM
    mov es, ax

; =========================================================================
; INITIAL GAME PLAYGROUND STATE
; =========================================================================
init_game_state:
    mov byte ptr [snakeLength], 3
    mov byte ptr [direction], RIGHT
    mov byte ptr [grow], 0
    mov byte ptr [appleRow], 8
    mov byte ptr [appleCol], 30
    mov byte ptr [axisFlip], 0

    call UpdateLEDScore     ; ????? ???? ????? ?? ??????? ??? ????? ?????

    ; ?????????? ??????? ????????
    mov snakeRow[0], 10
    mov snakeCol[0], 20

    mov snakeRow[1], 10
    mov snakeCol[1], 19

    mov snakeRow[2], 10
    mov snakeCol[2], 18

    call DrawFullSnake
    call DrawApple

; =========================================================================
; MAIN GAME LOOP
; =========================================================================
main_loop:

    call ReadInput          

    ; ?????? ???? ??????? (????? ???? ??????? ?????? ?? ??????? ??????? ??? Text Mode)
    cmp byte ptr [direction], LEFT
    je proceed_move
    cmp byte ptr [direction], RIGHT
    je proceed_move

    xor byte ptr [axisFlip], 1  
    jz skip_this_frame          ; ????? ??? ????? ?????? ??????

proceed_move:
    call SaveTail           
    call ShiftBody          
    call MoveHead           
    call CheckBorders       
    call CheckSelfCollision 
    call CheckApple         
    call EraseTail          
    call DrawHead           
    call DrawApple          

skip_this_frame:
    call WaitTick           
    jmp main_loop           

; =========================================================================
; KEYBOARD INPUT HANDLER
; =========================================================================
ReadInput:
    mov ah, 01h
    int 16h
    jz done_input       

    mov ah, 00h
    int 16h

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
    ret

move_down:
    inc byte ptr [snakeRow[0]]
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
    
    cmp al, 80          
    jae handle_col_border   
    jmp check_rows

handle_col_border:
    cmp byte ptr [gameMode], 1
    je game_over            
    
    cmp al, 254         
    jae set_col_max         
    mov byte ptr [snakeCol[0]], 0  
    jmp check_rows

set_col_max:
    mov byte ptr [snakeCol[0]], 79

check_rows:
    mov al, [snakeRow[0]]
    cmp al, 25          
    jae handle_row_border   
    ret

handle_row_border:
    cmp byte ptr [gameMode], 1
    je game_over            
    
    cmp al, 254         
    jae set_row_max         
    mov byte ptr [snakeRow[0]], 0  
    ret

set_row_max:
    mov byte ptr [snakeRow[0]], 24
    ret

; =========================================================================
; SELF COLLISION DETECTOR
; =========================================================================
CheckSelfCollision:
    cmp byte ptr [snakeLength], 4   
    jb done_collision

    xor cx, cx
    mov cl, [snakeLength]
    dec cx                         

    mov si, 1               

collision_loop:
    mov al, snakeRow[0]
    cmp al, snakeRow[si]
    jne next_segment        

    mov al, snakeCol[0]
    cmp al, snakeCol[si]
    je game_over            

next_segment:
    inc si
    loop collision_loop

done_collision:
    ret

; =========================================================================
; GAME OVER & RETRY MANAGER
; =========================================================================
game_over:
    xor ax, ax
    mov al, [snakeLength]
    sub al, 3

    mov bl, 10
    div bl              
    
    add al, '0'         
    mov [loseMsg + 20], al 
    
    add ah, '0'         
    mov [loseMsg + 21], ah 

    mov ah, 13h         
    mov al, 01h         
    xor bh, bh          
    mov bl, 4Fh         
    mov cx, [msgLength] 
    mov dh, 11          
    mov dl, 28          
    push cs
    pop es
    lea bp, [loseMsg]
    int 10h             

    mov ah, 13h         
    mov al, 01h         
    xor bh, bh          
    mov bl, 0Fh         
    mov cx, [retryLength] 
    mov dh, 13          
    mov dl, 29          
    push cs
    pop es
    lea bp, [retryMsg]
    int 10h             

wait_for_one:
    mov ah, 00h
    int 16h
    cmp al, '1'         
    jne wait_for_one    

restart_to_dashboard:
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

    inc byte ptr [snakeLength]  
    
    call UpdateLEDScore         ; ????? ???? ????? ???????? ??? ??? ??? ???????

    mov byte ptr [grow], 1      

    xor cx, cx
    mov cl, [snakeLength]
    dec cx
    mov si, cx
    
    mov al, [tailRow]
    mov snakeRow[si], al
    mov al, [tailCol]
    mov snakeCol[si], al

    call SpawnApple             

no_apple:
    ret

; =========================================================================
; RANDOM APPLE GENERATOR
; =========================================================================
SpawnApple:
    mov ah, 00h
    int 1Ah             
    mov ax, dx
    xor dx, dx
    mov bx, 80
    div bx              
    mov [appleCol], dl

    mov ah, 00h
    int 1Ah             
    mov ax, dx
    xor dx, dx
    mov bx, 25
    div bx              
    mov [appleRow], dl

    ret

; =========================================================================
; TRAIL CLEANER
; =========================================================================
EraseTail:
    cmp byte ptr [grow], 1
    je skip_erase       

    mov al, [tailRow]
    mov bl, [tailCol]

    call CalculateOffset 

    mov al, ' '         
    mov ah, 07h         

    mov es:[di], ax      
    ret

skip_erase:
    mov byte ptr [grow], 0 
    ret

; =========================================================================
; DRAW HEAD SYMBOL
; =========================================================================
DrawHead:
    mov al, snakeRow[0]
    mov bl, snakeCol[0]

    call CalculateOffset

    mov al, 219         
    mov ah, 0Ah         

    mov es:[di], ax      
    ret

; =========================================================================
; DRAW ENTIRE SNAKE STRUCTURE
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

    mov al, '@'         
    mov ah, 0Ch         

    mov es:[di], ax      
    ret

; =========================================================================
; CALCULATE MEMORY OFFSET FROM COORDINATES
; =========================================================================
CalculateOffset:
    push ax
    push bx

    xor ah, ah
    mov bh, 160
    mul bh              
    mov di, ax          

    xor ax, ax
    mov al, bl
    shl ax, 1           
    add di, ax          

    pop bx
    pop ax
    ret

; =========================================================================
; HARDWARE DELAY ENGINE
; =========================================================================
WaitTick:
    mov ah, 00h
    int 1Ah             

wait_loop:
    mov ah, 00h
    int 1Ah
    cmp dx, [lastTick]
    je wait_loop        

    mov [lastTick], dx  
    ret

; =========================================================================
; UPDATE EMU8086 EXTERNAL LED SCREEN HARDWARE
; =========================================================================
UpdateLEDScore:
    push ax
    push dx

    xor ax, ax
    mov al, [snakeLength]
    sub al, 3           

    mov dx, 199         ; ????? ?????? ??? Port 199 ????? ?????? ?? emu8086
    out dx, ax          

    pop dx
    pop ax
    ret
