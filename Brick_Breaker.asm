TITLE Brick Breaker Game (Brick_Breaker.asm)
; A simple Brick Breaker game with Windows GUI
; Uses Win32 API for window and GDI for drawing

.386
.model flat, stdcall
option casemap:none

; ============================================
; Constants
; ============================================
NULL                EQU 0
WS_OVERLAPPED       EQU 00000000h
WS_CAPTION          EQU 00C00000h
WS_SYSMENU          EQU 00080000h
WS_MINIMIZEBOX      EQU 00020000h
WS_VISIBLE          EQU 10000000h
CS_HREDRAW          EQU 0002h
CS_VREDRAW          EQU 0001h
IDI_APPLICATION     EQU 32512
IDC_ARROW           EQU 32512
SW_SHOW             EQU 5
CW_USEDEFAULT       EQU 80000000h
WM_CREATE           EQU 0001h
WM_DESTROY          EQU 0002h
WM_PAINT            EQU 000Fh            ; window needs repainting
WM_KEYDOWN          EQU 0100h            ; a key was pressed
WM_TIMER            EQU 0113h            ; timer tick message
TRUE                EQU 1                ; boolean true
TRANSPARENT_BK      EQU 1                ; transparent background mode

; Virtual key codes for input
VK_LEFT             EQU 25h              ; left arrow key code
VK_RIGHT            EQU 27h              ; right arrow key code
VK_SPACE            EQU 20h              ; space bar key code
VK_ESCAPE           EQU 1Bh              ; escape key code
WINDOW_WIDTH        EQU 640
WINDOW_HEIGHT       EQU 500

; Game area bounds
BORDER_LEFT         EQU 30
BORDER_TOP          EQU 50
BORDER_RIGHT        EQU 610
BORDER_BOTTOM       EQU 450
BORDER_THICKNESS    EQU 4

; Brick layout constants
BRICK_ROWS          EQU 3               ; 3 rows of bricks
BRICK_COLS          EQU 8               ; 8 bricks per row
TOTAL_BRICKS        EQU 24              ; 3 * 8 = 24 bricks total
BRICK_WIDTH         EQU 62              ; width of each brick in pixels
BRICK_HEIGHT        EQU 20              ; height of each brick in pixels
BRICK_GAP           EQU 6               ; gap between bricks
BRICK_START_X       EQU 42              ; x position of first brick
BRICK_START_Y       EQU 70              ; y position of first row

; Paddle constants
PADDLE_WIDTH        EQU 80              ; paddle width in pixels
PADDLE_HEIGHT       EQU 12              ; paddle height in pixels
PADDLE_Y            EQU 425             ; paddle vertical position
PADDLE_SPEED        EQU 15              ; pixels moved per keypress

; Ball constants
BALL_SIZE           EQU 8               ; ball width and height in pixels
BALL_SPEED          EQU 3               ; ball speed in pixels per tick

; Timer
TIMER_ID            EQU 1               ; id for our game timer
TIMER_INTERVAL      EQU 16              ; ~60fps refresh rate (ms)

; ============================================
; Structures
; ============================================
POINT STRUCT
    x   DWORD ?
    y   DWORD ?
POINT ENDS

RECT STRUCT
    left    DWORD ?
    top     DWORD ?
    right   DWORD ?
    bottom  DWORD ?
RECT ENDS

MSG STRUCT
    hwnd    DWORD ?
    message DWORD ?
    wParam  DWORD ?
    lParam  DWORD ?
    time    DWORD ?
    pt      POINT <>
MSG ENDS

WNDCLASSEX STRUCT
    cbSize          DWORD ?
    style           DWORD ?
    lpfnWndProc     DWORD ?
    cbClsExtra      DWORD ?
    cbWndExtra      DWORD ?
    hInstance       DWORD ?
    hIcon           DWORD ?
    hCursor         DWORD ?
    hbrBackground   DWORD ?
    lpszMenuName    DWORD ?
    lpszClassName   DWORD ?
    hIconSm         DWORD ?
WNDCLASSEX ENDS

PAINTSTRUCT STRUCT
    hdc         DWORD ?
    fErase      DWORD ?
    rcPaint     RECT <>
    fRestore    DWORD ?
    fIncUpdate  DWORD ?
    rgbReserved BYTE 32 DUP(?)
PAINTSTRUCT ENDS

; ============================================
; Function Prototypes
; ============================================
; kernel32
GetModuleHandleA PROTO :DWORD
ExitProcess PROTO :DWORD

; user32
RegisterClassExA PROTO :DWORD
CreateWindowExA PROTO :DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD
ShowWindow PROTO :DWORD,:DWORD
UpdateWindow PROTO :DWORD
GetMessageA PROTO :DWORD,:DWORD,:DWORD,:DWORD
TranslateMessage PROTO :DWORD
DispatchMessageA PROTO :DWORD
DefWindowProcA PROTO :DWORD,:DWORD,:DWORD,:DWORD
PostQuitMessage PROTO :DWORD
BeginPaint PROTO :DWORD,:DWORD
EndPaint PROTO :DWORD,:DWORD
LoadIconA PROTO :DWORD,:DWORD
LoadCursorA PROTO :DWORD,:DWORD
GetClientRect PROTO :DWORD,:DWORD
FillRect PROTO :DWORD,:DWORD,:DWORD      ; fill rectangle with brush
SetTimer PROTO :DWORD,:DWORD,:DWORD,:DWORD ; start a timer
KillTimer PROTO :DWORD,:DWORD             ; stop a timer
InvalidateRect PROTO :DWORD,:DWORD,:DWORD ; mark window for repaint

; gdi32
CreateSolidBrush PROTO :DWORD
DeleteObject PROTO :DWORD
SetBkMode PROTO :DWORD,:DWORD
SetTextColor PROTO :DWORD,:DWORD
TextOutA PROTO :DWORD,:DWORD,:DWORD,:DWORD,:DWORD
Rectangle PROTO :DWORD,:DWORD,:DWORD,:DWORD,:DWORD
SelectObject PROTO :DWORD,:DWORD
GetStockObject PROTO :DWORD

; ============================================
; Data
; ============================================
.data
className       BYTE "BrickBreakerWnd", 0  ; window class name for registration
windowTitle     BYTE "Brick Breaker", 0    ; text shown in title bar
titleText       BYTE "BRICK BREAKER", 0    ; text drawn on the window
hInstance       DWORD 0                     ; handle to this program instance
hwndMain        DWORD 0                     ; handle to our main window

; Brick status array: 1 = alive, 0 = destroyed
; 24 bricks total (3 rows x 8 columns)
bricks          BYTE 1,1,1,1,1,1,1,1        ; row 0 (blue bricks)
                BYTE 1,1,1,1,1,1,1,1        ; row 1 (green bricks)
                BYTE 1,1,1,1,1,1,1,1        ; row 2 (red bricks)

; Colors for each row (BGR format for Win32)
rowColors       DWORD 00FF0000h             ; row 0 = blue
                DWORD 0000CC00h             ; row 1 = green
                DWORD 000000FFh             ; row 2 = red

; Paddle state
paddleX         DWORD 280                   ; paddle x position (starts centered)

; Ball state
ballX           DWORD 316                   ; ball x position (centered on paddle)
ballY           DWORD 413                   ; ball y position (on top of paddle)
ballDX          SDWORD 3                    ; ball x velocity (positive = right)
ballDY          SDWORD -3                   ; ball y velocity (negative = up)
ballActive      DWORD 0                     ; 0 = sitting on paddle, 1 = moving

; ============================================
; Code
; ============================================
.code

; --------------------------------------------
; Window Procedure
; --------------------------------------------
WndProc PROC hWin:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL ps:PAINTSTRUCT                    ; paint struct for BeginPaint
    LOCAL hdc:DWORD                         ; device context handle
    LOCAL rc:RECT                           ; temp rectangle for drawing
    LOCAL hBrush:DWORD                      ; temp brush handle
    LOCAL brickRow:DWORD                    ; current brick row counter
    LOCAL brickCol:DWORD                    ; current brick column counter
    LOCAL brickX:DWORD                      ; current brick x position
    LOCAL brickY:DWORD                      ; current brick y position

    mov eax, uMsg

    .IF eax == WM_PAINT
        invoke BeginPaint, hWin, ADDR ps
        mov hdc, eax

        ; dark background
        invoke GetClientRect, hWin, ADDR rc
        invoke CreateSolidBrush, 00400000h
        mov hBrush, eax
        invoke FillRect, hdc, ADDR rc, hBrush
        invoke DeleteObject, hBrush

        ; draw game border (gray)
        invoke CreateSolidBrush, 00808080h
        mov hBrush, eax
        invoke SelectObject, hdc, hBrush
        ; top wall
        mov rc.left, BORDER_LEFT
        mov rc.top, BORDER_TOP
        mov rc.right, BORDER_RIGHT
        mov rc.bottom, BORDER_TOP + BORDER_THICKNESS
        invoke FillRect, hdc, ADDR rc, hBrush
        ; left wall
        mov rc.left, BORDER_LEFT
        mov rc.top, BORDER_TOP
        mov rc.right, BORDER_LEFT + BORDER_THICKNESS
        mov rc.bottom, BORDER_BOTTOM
        invoke FillRect, hdc, ADDR rc, hBrush
        ; right wall
        mov rc.left, BORDER_RIGHT - BORDER_THICKNESS
        mov rc.top, BORDER_TOP
        mov rc.right, BORDER_RIGHT
        mov rc.bottom, BORDER_BOTTOM
        invoke FillRect, hdc, ADDR rc, hBrush
        invoke DeleteObject, hBrush         ; free the gray brush

        ; --- draw bricks ---
        mov brickRow, 0                      ; start from row 0
    drawRowLoop:
        cmp brickRow, BRICK_ROWS             ; check if we drew all rows
        jge doneDrawBricks                   ; if so, skip to end

        ; pick color for this row
        mov eax, brickRow                    ; get current row index
        shl eax, 2                           ; multiply by 4 (DWORD size)
        mov eax, [rowColors + eax]           ; load row color (BGR)
        invoke CreateSolidBrush, eax         ; create brush with that color
        mov hBrush, eax                      ; save brush handle

        ; calculate y position for this row
        mov eax, brickRow                    ; row index
        mov ecx, BRICK_HEIGHT + BRICK_GAP    ; height + gap per row
        imul eax, ecx                        ; row * (height + gap)
        add eax, BRICK_START_Y               ; add starting y offset
        mov brickY, eax                      ; store y position

        mov brickCol, 0                      ; start from column 0
    drawColLoop:
        cmp brickCol, BRICK_COLS             ; check if we drew all columns
        jge doneRow                          ; if so, move to next row

        ; check if this brick is still alive
        mov eax, brickRow                    ; current row
        imul eax, BRICK_COLS                 ; row * 8 = offset into array
        add eax, brickCol                    ; add column = brick index
        movzx eax, BYTE PTR [bricks + eax]   ; load alive flag (0 or 1)
        cmp eax, 0                           ; is brick destroyed?
        je skipBrick                         ; if dead, skip drawing it

        ; calculate x position for this column
        mov eax, brickCol                    ; column index
        mov ecx, BRICK_WIDTH + BRICK_GAP     ; width + gap per column
        imul eax, ecx                        ; col * (width + gap)
        add eax, BRICK_START_X               ; add starting x offset
        mov brickX, eax                      ; store x position

        ; set up the rectangle for this brick
        mov eax, brickX                      ; left edge
        mov rc.left, eax
        mov eax, brickY                      ; top edge
        mov rc.top, eax
        mov eax, brickX                      ; right = left + width
        add eax, BRICK_WIDTH
        mov rc.right, eax
        mov eax, brickY                      ; bottom = top + height
        add eax, BRICK_HEIGHT
        mov rc.bottom, eax

        invoke FillRect, hdc, ADDR rc, hBrush ; fill the brick rectangle

    skipBrick:
        inc brickCol                         ; move to next column
        jmp drawColLoop                      ; repeat for all columns

    doneRow:
        invoke DeleteObject, hBrush          ; free this row's brush
        inc brickRow                         ; move to next row
        jmp drawRowLoop                      ; repeat for all rows

    doneDrawBricks:

        ; --- draw paddle ---
        invoke CreateSolidBrush, 00FFFF00h   ; cyan color for paddle (BGR)
        mov hBrush, eax                      ; save the brush handle
        mov eax, paddleX                     ; get paddle x position
        mov rc.left, eax                     ; set left edge of paddle
        mov rc.top, PADDLE_Y                 ; set top edge of paddle
        add eax, PADDLE_WIDTH                ; calculate right edge
        mov rc.right, eax                    ; set right edge
        mov eax, PADDLE_Y                    ; get paddle y again
        add eax, PADDLE_HEIGHT               ; calculate bottom edge
        mov rc.bottom, eax                   ; set bottom edge
        invoke FillRect, hdc, ADDR rc, hBrush ; draw the paddle
        invoke DeleteObject, hBrush          ; free the brush

        ; --- draw ball ---
        invoke CreateSolidBrush, 00FFFFFFh   ; white color for ball (BGR)
        mov hBrush, eax                      ; save brush handle
        mov eax, ballX                       ; get ball x position
        mov rc.left, eax                     ; set left edge
        mov eax, ballY                       ; get ball y position
        mov rc.top, eax                      ; set top edge
        mov eax, ballX                       ; calculate right edge
        add eax, BALL_SIZE                   ; left + ball size
        mov rc.right, eax                    ; set right edge
        mov eax, ballY                       ; calculate bottom edge
        add eax, BALL_SIZE                   ; top + ball size
        mov rc.bottom, eax                   ; set bottom edge
        invoke FillRect, hdc, ADDR rc, hBrush ; draw ball
        invoke DeleteObject, hBrush          ; free brush

        ; --- title text above border ---
        invoke SetBkMode, hdc, TRANSPARENT_BK ; transparent text background
        invoke SetTextColor, hdc, 0000FFFFh   ; yellow text color
        invoke TextOutA, hdc, 270, 15, ADDR titleText, 13 ; draw title

        invoke EndPaint, hWin, ADDR ps       ; finish painting
        xor eax, eax                         ; return 0 (message handled)
        ret

    .ELSEIF eax == WM_CREATE
        ; start the game timer when window is created
        invoke SetTimer, hWin, TIMER_ID, TIMER_INTERVAL, NULL ; create timer
        xor eax, eax                         ; return 0
        ret

    .ELSEIF eax == WM_TIMER
        ; --- move the ball if its active ---
        cmp ballActive, 0                    ; is ball launched?
        je skipBallMove                      ; if not, skip movement

        ; update ball x position
        mov eax, ballX                       ; get current x
        add eax, ballDX                      ; add x velocity
        mov ballX, eax                       ; save new x

        ; update ball y position
        mov eax, ballY                       ; get current y
        add eax, ballDY                      ; add y velocity
        mov ballY, eax                       ; save new y

        ; bounce off left wall
        mov eax, ballX                       ; check x position
        cmp eax, BORDER_LEFT + BORDER_THICKNESS ; past left wall?
        jg noLeftBounce                      ; if not, skip
        neg ballDX                           ; reverse x direction
        mov ballX, BORDER_LEFT + BORDER_THICKNESS ; push back inside
    noLeftBounce:

        ; bounce off right wall
        mov eax, ballX                       ; check x position
        add eax, BALL_SIZE                   ; add ball width
        cmp eax, BORDER_RIGHT - BORDER_THICKNESS ; past right wall?
        jl noRightBounce                     ; if not, skip
        neg ballDX                           ; reverse x direction
        mov eax, BORDER_RIGHT - BORDER_THICKNESS ; push back inside
        sub eax, BALL_SIZE
        mov ballX, eax
    noRightBounce:

        ; bounce off top wall
        mov eax, ballY                       ; check y position
        cmp eax, BORDER_TOP + BORDER_THICKNESS ; past top wall?
        jg noTopBounce                       ; if not, skip
        neg ballDY                           ; reverse y direction
        mov ballY, BORDER_TOP + BORDER_THICKNESS ; push back inside
    noTopBounce:

        ; check paddle collision
        mov eax, ballY                       ; ball y position
        add eax, BALL_SIZE                   ; bottom edge of ball
        cmp eax, PADDLE_Y                    ; reached paddle level?
        jl noPaddleBounce                    ; if above paddle, skip
        cmp eax, PADDLE_Y + PADDLE_HEIGHT    ; below paddle bottom?
        jg ballFell                          ; ball fell past paddle
        mov eax, ballX                       ; ball x position
        add eax, BALL_SIZE                   ; right edge of ball
        cmp eax, paddleX                     ; left of paddle?
        jl ballFell                          ; missed paddle
        mov eax, ballX                       ; ball x position
        mov ecx, paddleX                     ; paddle left edge
        add ecx, PADDLE_WIDTH                ; paddle right edge
        cmp eax, ecx                         ; right of paddle?
        jg ballFell                          ; missed paddle
        neg ballDY                           ; bounce upward
        mov eax, PADDLE_Y                    ; reposition ball
        sub eax, BALL_SIZE                   ; above paddle
        mov ballY, eax                       ; update position
        jmp noPaddleBounce                   ; done with bounce

    ballFell:
        ; ball went below paddle, reset to paddle
        mov ballActive, 0                    ; deactivate ball
        mov eax, paddleX                     ; center ball on paddle
        add eax, PADDLE_WIDTH / 2            ; middle of paddle
        sub eax, BALL_SIZE / 2               ; center the ball
        mov ballX, eax                       ; set ball x
        mov eax, PADDLE_Y                    ; above paddle
        sub eax, BALL_SIZE                   ; position on top
        mov ballY, eax                       ; set ball y

    noPaddleBounce:
    skipBallMove:

        ; if ball is on paddle, track paddle position
        cmp ballActive, 0                    ; ball sitting on paddle?
        jne skipTrack                        ; if moving, skip
        mov eax, paddleX                     ; get paddle x
        add eax, PADDLE_WIDTH / 2            ; center of paddle
        sub eax, BALL_SIZE / 2               ; center ball on it
        mov ballX, eax                       ; update ball x
        mov eax, PADDLE_Y                    ; just above paddle
        sub eax, BALL_SIZE                   ; on top of paddle
        mov ballY, eax                       ; update ball y
    skipTrack:

        invoke InvalidateRect, hWin, NULL, TRUE ; mark window for repaint
        xor eax, eax                         ; return 0
        ret

    .ELSEIF eax == WM_KEYDOWN
        mov eax, wParam                      ; get which key was pressed

        .IF eax == VK_LEFT                   ; left arrow key
            mov eax, paddleX                 ; get current paddle position
            sub eax, PADDLE_SPEED            ; move left by speed amount
            cmp eax, BORDER_LEFT + BORDER_THICKNESS ; check left boundary
            jl doneKey                       ; if past boundary, dont move
            mov paddleX, eax                 ; update paddle position
        .ELSEIF eax == VK_RIGHT              ; right arrow key
            mov eax, paddleX                 ; get current paddle position
            add eax, PADDLE_SPEED            ; move right by speed amount
            add eax, PADDLE_WIDTH            ; check right edge of paddle
            cmp eax, BORDER_RIGHT - BORDER_THICKNESS ; check right boundary
            jg doneKey                       ; if past boundary, dont move
            sub eax, PADDLE_WIDTH            ; restore to left edge
            mov paddleX, eax                 ; update paddle position
        .ELSEIF eax == VK_SPACE              ; space bar
            cmp ballActive, 0                ; is ball on paddle?
            jne doneKey                      ; if already moving, skip
            mov ballActive, 1                ; launch the ball
            mov ballDX, BALL_SPEED           ; set x velocity right
            mov eax, BALL_SPEED              ; get speed value
            neg eax                          ; make it negative (upward)
            mov ballDY, eax                  ; set y velocity up
        .ENDIF

    doneKey:
        xor eax, eax                         ; return 0
        ret

    .ELSEIF eax == WM_DESTROY
        invoke KillTimer, hWin, TIMER_ID     ; stop the timer
        invoke PostQuitMessage, 0            ; tell windows to quit
        xor eax, eax                         ; return 0
        ret
    .ENDIF

    invoke DefWindowProcA, hWin, uMsg, wParam, lParam
    ret
WndProc ENDP

; --------------------------------------------
; Main Entry Point
; --------------------------------------------
main PROC
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG

    invoke GetModuleHandleA, NULL
    mov hInstance, eax

    ; setup window class
    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInstance
    mov wc.hInstance, eax
    invoke LoadIconA, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursorA, NULL, IDC_ARROW
    mov wc.hCursor, eax
    mov wc.hbrBackground, NULL
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET className

    invoke RegisterClassExA, ADDR wc

    ; create the game window
    invoke CreateWindowExA, 0, \
           ADDR className, ADDR windowTitle, \
           WS_VISIBLE or WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, \
           CW_USEDEFAULT, CW_USEDEFAULT, \
           WINDOW_WIDTH, WINDOW_HEIGHT, \
           NULL, NULL, hInstance, NULL
    mov hwndMain, eax

    invoke ShowWindow, hwndMain, SW_SHOW
    invoke UpdateWindow, hwndMain

    ; message loop
    msgLoop:
        invoke GetMessageA, ADDR msg, NULL, 0, 0
        cmp eax, 0
        je exitLoop
        invoke TranslateMessage, ADDR msg
        invoke DispatchMessageA, ADDR msg
        jmp msgLoop

    exitLoop:
    invoke ExitProcess, 0
main ENDP

END main