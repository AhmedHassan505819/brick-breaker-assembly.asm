TITLE Brick Breaker Game (Brick_Breaker.asm)
; Brick Breaker - a simple console game
; Built with MASM + Irvine32

Include irvine32.inc

.data
welcomeMsg  BYTE "WELCOME TO BRICK BREAKER", 0

.code
main PROC
    call ClrScr

    ; print welcome message in the middle of screen
    mov dh, 12          ; row
    mov dl, 28          ; column
    call Gotoxy
    mov edx, OFFSET welcomeMsg
    call WriteString

    call ReadChar       ; wait for keypress
    exit
main ENDP
END main