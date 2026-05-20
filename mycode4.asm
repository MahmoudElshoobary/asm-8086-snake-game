org 100h

jmp start

; =========================================
; CONSTANTS
; =========================================

VIDMEM     equ 0B800h

UP         equ 0
DOWN       equ 1
LEFT       equ 2
RIGHT      equ 3

; =========================================
; VARIABLES
; =========================================

snakeRow       db 100 dup(0)
snakeCol       db 100 dup(0)

snakeLength    db 3

direction      db RIGHT

tailRow        db 0
tailCol        db 0

grow           db 0

appleRow       db 8
appleCol       db 30

lastTick       dw 0

; =========================================
; START
; =========================================

start:

    mov ax, 0003h
    int 10h

    mov ax, VIDMEM
    mov es, ax

   ;; call ClearScreen

    ; =====================
    ; INITIAL SNAKE
    ; =====================

    ; head
    mov snakeRow[0], 10
    mov snakeCol[0], 20

    ; body
    mov snakeRow[1], 10
    mov snakeCol[1], 19

    ; tail
    mov snakeRow[2], 10
    mov snakeCol[2], 18

    call DrawFullSnake
    call DrawApple

; =========================================
; MAIN LOOP
; =========================================

main_loop:

    call ReadInput

    call SaveTail

    call ShiftBody

    call MoveHead

    call CheckBorders

    call CheckApple

    call EraseTail

    call DrawHead

    call DrawApple

    call WaitTick

    jmp main_loop

; =========================================
; READ INPUT
; =========================================

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
    mov byte ptr [direction], UP
    jmp done_input

set_down:
    mov byte ptr [direction], DOWN
    jmp done_input

set_left:
    mov byte ptr [direction], LEFT
    jmp done_input

set_right:
    mov byte ptr [direction], RIGHT

done_input:
    ret

; =========================================
; SAVE OLD TAIL POSITION
; =========================================

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

; =========================================
; SHIFT BODY
; =========================================

ShiftBody:

    xor cx, cx
    mov cl, [snakeLength]

    dec cx

shift_loop:

    mov si, cx
    dec si

    ; row
    mov al, snakeRow[si]
    mov snakeRow[si+1], al

    ; col
    mov al, snakeCol[si]
    mov snakeCol[si+1], al

    loop shift_loop

    ret

; =========================================
; MOVE HEAD
; =========================================

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
    dec byte ptr [snakeRow]
    ret

move_down:
    inc byte ptr [snakeRow]
    ret

move_left:
    dec byte ptr [snakeCol]
    ret

move_right:
    inc byte ptr [snakeCol]
    ret

; =========================================
; BORDER WRAP
; =========================================

CheckBorders:

    ; RIGHT
    cmp byte ptr [snakeCol], 79
    jle check_left

    mov byte ptr [snakeCol], 0

check_left:

    ; LEFT
    cmp byte ptr [snakeCol], 0
    jge check_down

    mov byte ptr [snakeCol], 79

check_down:

    ; BOTTOM
    cmp byte ptr [snakeRow], 24
    jle check_up

    mov byte ptr [snakeRow], 0

check_up:

    ; TOP
    cmp byte ptr [snakeRow], 0
    jge done_border

    mov byte ptr [snakeRow], 24

done_border:
    ret

; =========================================
; CHECK APPLE
; =========================================

CheckApple:

    mov al, snakeRow[0]
    cmp al, [appleRow]
    jne no_apple

    mov al, snakeCol[0]
    cmp al, [appleCol]
    jne no_apple

    ; grow snake
    inc byte ptr [snakeLength]

    mov byte ptr [grow], 1

    call SpawnApple

no_apple:
    ret

; =========================================
; RANDOM APPLE
; =========================================

SpawnApple:

    ; col
    mov ah, 00h
    int 1Ah

    mov ax, dx
    xor dx, dx

    mov bx, 80
    div bx

    mov [appleCol], dl

    ; row
    mov ah, 00h
    int 1Ah

    mov ax, dx
    xor dx, dx

    mov bx, 25
    div bx

    mov [appleRow], dl

    ret

; =========================================
; ERASE OLD TAIL
; =========================================

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

; =========================================
; DRAW HEAD ONLY
; =========================================

DrawHead:

    mov al, snakeRow[0]
    mov bl, snakeCol[0]

    call CalculateOffset

    mov al, 219
    mov ah, 0Ah

    mov es:[di], ax

    ret

; =========================================
; DRAW ENTIRE SNAKE
; =========================================

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

; =========================================
; DRAW APPLE
; =========================================

DrawApple:

    mov al, [appleRow]
    mov bl, [appleCol]

    call CalculateOffset

    mov al, '@'
    mov ah, 0Ch

    mov es:[di], ax

    ret

; =========================================
; CALCULATE OFFSET
; AL = row
; BL = col
; =========================================

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

; =========================================
; WAIT TIMER TICK
; =========================================

WaitTick:

    mov ah, 00h
    int 1Ah

    cmp dx, [lastTick]
    je WaitTick

    mov [lastTick], dx

    ret

; =========================================
; CLEAR SCREEN
; =========================================

ClearScreen:

    mov ax, 0720h

    xor di, di

    mov cx, 2000

clear_loop:

    mov es:[di], ax

    add di, 2

    loop clear_loop

    ret