TITLE Brick Breaker Game (Brick_Breaker.asm)
; A simple Brick Breaker game with Windows GUI
; Uses Win32 API for window and GDI for drawing

.386                                         ; use 386 instruction set
.model flat, stdcall                         ; flat memory model, stdcall convention
option casemap:none                          ; case sensitive identifiers

; ============================================
; Constants
; ============================================
NULL                EQU 0                    ; null pointer value
WS_OVERLAPPED       EQU 00000000h            ; overlapped window style
WS_CAPTION          EQU 00C00000h            ; window has title bar
WS_SYSMENU          EQU 00080000h            ; window has system menu
WS_MINIMIZEBOX      EQU 00020000h            ; window has minimize button
WS_VISIBLE          EQU 10000000h            ; window is initially visible
CS_HREDRAW          EQU 0002h                ; redraw on horizontal resize
CS_VREDRAW          EQU 0001h                ; redraw on vertical resize
IDI_APPLICATION     EQU 32512                ; default application icon
IDC_ARROW           EQU 32512                ; default arrow cursor
SW_SHOW             EQU 5                    ; show window command
CW_USEDEFAULT       EQU 80000000h            ; let windows choose position
WM_CREATE           EQU 0001h                ; window just created
WM_DESTROY          EQU 0002h                ; window being destroyed
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
VK_RETURN           EQU 0Dh              ; enter key code
VK_I                EQU 49h              ; 'I' key
VK_Q                EQU 51h              ; 'Q' key
VK_R                EQU 52h              ; 'R' key
WINDOW_WIDTH        EQU 640                  ; game window width in pixels
WINDOW_HEIGHT       EQU 500                  ; game window height in pixels

; Game area bounds
BORDER_LEFT         EQU 30                   ; left wall x position
BORDER_TOP          EQU 50                   ; top wall y position
BORDER_RIGHT        EQU 610                  ; right wall x position
BORDER_BOTTOM       EQU 450                  ; bottom open area y position
BORDER_THICKNESS    EQU 4                    ; thickness of wall in pixels

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
TIMER_INTERVAL      EQU 8               ; ~125fps refresh rate (ms)

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
Beep PROTO :DWORD,:DWORD

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
MessageBoxA PROTO :DWORD,:DWORD,:DWORD,:DWORD ; show message box
wsprintfA PROTO C :DWORD,:DWORD,:VARARG   ; format string with numbers
GetAsyncKeyState PROTO :DWORD              ; check key state asynchronously

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

; Game state
score           DWORD 0                     ; player score
lives           DWORD 3                     ; remaining lives
bricksLeft      DWORD 24                    ; how many bricks still alive
gameState       DWORD 3                     ; 0=playing, 1=won, 2=lost, 3=title, 4=instr

; Time tracking
timerTicks      DWORD 0                     ; counts ticks to calculate seconds (60 ticks ~ 1s)
timeSeconds     DWORD 0                     ; elapsed game time in seconds

; Powerups
solidBaseTimer  DWORD 0                     ; timer for solid base powerup (in ticks)

; HUD display strings
scoreLabel      BYTE "Score: ", 0           ; label for score display
livesLabel      BYTE "Lives: ", 0           ; label for lives display
timeLabel       BYTE "Time: ", 0            ; label for time display
scoreBuf        BYTE 32 DUP(0)              ; buffer for formatted score text
livesBuf        BYTE 32 DUP(0)              ; buffer for formatted lives text
timeBuf         BYTE 32 DUP(0)              ; buffer for formatted time text
fmtStr          BYTE "%d", 0                ; format string for numbers
winMsg          BYTE "YOU WIN!", 0          ; win message text
loseMsg         BYTE "GAME OVER", 0         ; lose message text
restartMsg      BYTE "Press SPACE to restart", 0 ; restart hint
startMsg        BYTE "Press SPACE to launch ball", 0 ; start hint
hint1Msg        BYTE "Left/Right Arrows to move", 0  ; control hint
hint2Msg        BYTE "Red bricks give 5s solid base!", 0 ; powerup hint
hint3Msg        BYTE "Clear under 2m for +50pt bonus", 0 ; bonus hint

; Menu Strings
titleWelcomeMsg BYTE "WELCOME TO BRICK BREAKER", 0
titlePlayMsg    BYTE "PRESS ENTER TO PLAY GAME", 0
titleInstrMsg   BYTE "PRESS I FOR INSTRUCTION BOX", 0
titleExitMsg    BYTE "PRESS ESC TO QUIT GAME", 0
instrTitleMsg   BYTE "INSTRUCTIONS", 0
endScoresMsg    BYTE "YOUR TOTAL SCORE: ", 0
endLivesMsg     BYTE "LIVES REMAINING: ", 0
endRestartMsg   BYTE "PRESS R TO RESTART YOUR GAME", 0
endQuitMsg      BYTE "PRESS Q TO QUIT GAME", 0

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

        ; --- branch based on game state ---
        cmp gameState, 3                     ; title screen?
        je drawTitleScreen
        cmp gameState, 4                     ; instruction screen?
        je drawInstructionScreen
        cmp gameState, 1                     ; won?
        je drawEndScreen
        cmp gameState, 2                     ; lost?
        je drawEndScreen

        ; ============================================
        ; draw game (playing state)
        ; ============================================

        ; --- draw game area border (gray) ---
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

        ; --- draw bottom border if solid base active ---
        cmp solidBaseTimer, 0                ; is solid base active?
        jle skipBottomBorder                 ; if not, skip
        
        invoke CreateSolidBrush, 000000FFh   ; red brush for solid base
        mov hBrush, eax                      ; save brush handle
        
        mov rc.left, BORDER_LEFT             ; left edge
        mov rc.top, BORDER_BOTTOM            ; bottom edge
        mov rc.right, BORDER_RIGHT           ; right edge
        mov eax, BORDER_BOTTOM               ; get bottom y
        add eax, BORDER_THICKNESS            ; add thickness
        mov rc.bottom, eax                   ; set bottom boundary
        
        invoke FillRect, hdc, ADDR rc, hBrush ; draw bottom border
        invoke DeleteObject, hBrush          ; free brush
    skipBottomBorder:

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

        ; --- HUD: score, time and lives ---
        invoke SetBkMode, hdc, TRANSPARENT_BK ; transparent text background
        invoke SetTextColor, hdc, 0000FFFFh   ; yellow text color
        invoke TextOutA, hdc, 250, 15, ADDR titleText, 13 ; draw title

        ; draw score label and value
        invoke SetTextColor, hdc, 00FFFFFFh   ; white color for HUD
        invoke TextOutA, hdc, 30, 15, ADDR scoreLabel, 7 ; "Score: "
        invoke wsprintfA, ADDR scoreBuf, ADDR fmtStr, score ; convert score to text
        invoke TextOutA, hdc, 86, 15, ADDR scoreBuf, eax ; draw score number

        ; draw time label and value
        invoke TextOutA, hdc, 430, 15, ADDR timeLabel, 6 ; "Time: "
        invoke wsprintfA, ADDR timeBuf, ADDR fmtStr, timeSeconds ; convert time to text
        invoke TextOutA, hdc, 480, 15, ADDR timeBuf, eax ; draw time number

        ; draw lives label and value
        invoke TextOutA, hdc, 540, 15, ADDR livesLabel, 7 ; "Lives: "
        invoke wsprintfA, ADDR livesBuf, ADDR fmtStr, lives ; convert lives to text
        invoke TextOutA, hdc, 596, 15, ADDR livesBuf, eax ; draw lives number

        ; show start hints if ball is on paddle and game just started
        cmp ballActive, 0                    ; ball on paddle?
        jne skipStartMsg                     ; if launched, skip
        
        invoke SetTextColor, hdc, 00AAAAAAh  ; light gray text
        invoke TextOutA, hdc, 225, 300, ADDR startMsg, 26 ; show start hint
    skipStartMsg:
        jmp donePaint                        ; done drawing game

        ; ============================================
        ; dedicated menu screens
        ; ============================================
    drawTitleScreen:
        invoke SetBkMode, hdc, TRANSPARENT_BK
        invoke SetTextColor, hdc, 0000FFFFh  ; yellow title
        invoke TextOutA, hdc, 220, 150, ADDR titleWelcomeMsg, 24
        invoke SetTextColor, hdc, 00FFFFFFh  ; white text
        invoke TextOutA, hdc, 220, 220, ADDR titlePlayMsg, 24
        invoke TextOutA, hdc, 220, 270, ADDR titleInstrMsg, 27
        invoke TextOutA, hdc, 220, 320, ADDR titleExitMsg, 22
        jmp donePaint

    drawInstructionScreen:
        invoke SetBkMode, hdc, TRANSPARENT_BK
        invoke SetTextColor, hdc, 0000FFFFh
        invoke TextOutA, hdc, 260, 100, ADDR instrTitleMsg, 12
        invoke SetTextColor, hdc, 00FFFFFFh
        invoke TextOutA, hdc, 180, 180, ADDR hint1Msg, 25
        invoke TextOutA, hdc, 180, 220, ADDR hint2Msg, 30
        invoke TextOutA, hdc, 180, 260, ADDR hint3Msg, 30
        invoke TextOutA, hdc, 220, 350, ADDR titlePlayMsg, 24
        jmp donePaint

    drawEndScreen:
        invoke SetBkMode, hdc, TRANSPARENT_BK
        invoke SetTextColor, hdc, 0000FFFFh   ; yellow
        cmp gameState, 1
        jne lostState
        invoke TextOutA, hdc, 280, 100, ADDR winMsg, 8
        jmp drawStats
    lostState:
        invoke TextOutA, hdc, 280, 100, ADDR loseMsg, 9
    drawStats:
        invoke SetTextColor, hdc, 00FFFFFFh   ; white
        invoke TextOutA, hdc, 200, 180, ADDR endScoresMsg, 18
        invoke wsprintfA, ADDR scoreBuf, ADDR fmtStr, score
        invoke TextOutA, hdc, 380, 180, ADDR scoreBuf, eax
        invoke TextOutA, hdc, 200, 220, ADDR endLivesMsg, 17
        invoke wsprintfA, ADDR livesBuf, ADDR fmtStr, lives
        invoke TextOutA, hdc, 380, 220, ADDR livesBuf, eax
        invoke TextOutA, hdc, 200, 300, ADDR endRestartMsg, 28
        invoke TextOutA, hdc, 200, 340, ADDR endQuitMsg, 20
        jmp donePaint

    donePaint:
        invoke EndPaint, hWin, ADDR ps       ; finish painting
        xor eax, eax                         ; return 0 (message handled)
        ret

    .ELSEIF eax == WM_CREATE
        ; start the game timer when window is created
        invoke SetTimer, hWin, TIMER_ID, TIMER_INTERVAL, NULL ; create timer
        xor eax, eax                         ; return 0
        ret

    .ELSEIF eax == WM_TIMER
        ; --- update time ---
        cmp gameState, 0                     ; is game still in play?
        jne skipTimeUpdate                   ; if won or lost, dont update time
        cmp ballActive, 1                    ; is ball active (game running)?
        jne skipTimeUpdate                   ; if not, dont update time
        inc timerTicks                       ; increment tick counter
        cmp timerTicks, 125                  ; reached 125 ticks? (approx 1 sec at 8ms interval)
        jl skipTimeUpdate                    ; if not, skip
        mov timerTicks, 0                    ; reset tick counter
        inc timeSeconds                      ; increment seconds
    skipTimeUpdate:

        ; --- update powerup timers ---
        cmp solidBaseTimer, 0                ; is solid base active?
        jle skipSolidUpdate                  ; if not, skip
        dec solidBaseTimer                   ; decrement timer
    skipSolidUpdate:

        ; --- move the ball if its active ---
        cmp gameState, 0                     ; is game still in play?
        jne skipBallMove                     ; if won or lost, dont move ball
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

        ; bounce off bottom wall (ONLY if solid base active)
        cmp solidBaseTimer, 0                ; is solid base active?
        jle noBottomBounce                   ; if not, skip
        mov eax, ballY                       ; check y position
        add eax, BALL_SIZE                   ; add ball size
        cmp eax, BORDER_BOTTOM               ; past bottom wall?
        jl noBottomBounce                    ; if not, skip
        neg ballDY                           ; reverse y direction
        mov eax, BORDER_BOTTOM               ; push back inside
        sub eax, BALL_SIZE
        mov ballY, eax
    noBottomBounce:

        ; --- check brick collision ---
        ; loop through all bricks and see if ball overlaps any
        xor ecx, ecx                         ; ecx = brick index (0 to 23)
    checkBrickLoop:
        cmp ecx, TOTAL_BRICKS                ; checked all bricks?
        jge doneBrickCheck                   ; if so, done

        movzx eax, BYTE PTR [bricks + ecx]   ; is this brick alive?
        cmp eax, 0                           ; 0 = destroyed
        je nextBrickCheck                    ; skip dead bricks

        ; calculate this brick's position
        push ecx                             ; save brick index
        mov eax, ecx                         ; copy index
        xor edx, edx                         ; clear for division
        mov ebx, BRICK_COLS                  ; divisor = 8
        div ebx                              ; eax = row, edx = column

        ; brick Y = BRICK_START_Y + row * (BRICK_HEIGHT + BRICK_GAP)
        push edx                             ; save column
        mov ebx, BRICK_HEIGHT + BRICK_GAP    ; row stride
        imul eax, ebx                        ; row * stride
        add eax, BRICK_START_Y               ; add start offset
        mov esi, eax                         ; esi = brick top Y

        ; brick X = BRICK_START_X + col * (BRICK_WIDTH + BRICK_GAP)
        pop edx                              ; restore column
        mov eax, edx                         ; column index
        mov ebx, BRICK_WIDTH + BRICK_GAP     ; column stride
        imul eax, ebx                        ; col * stride
        add eax, BRICK_START_X               ; add start offset
        mov edi, eax                         ; edi = brick left X

        ; check overlap: ball rect vs brick rect
        ; ball right > brick left?
        mov eax, ballX                       ; ball left
        add eax, BALL_SIZE                   ; ball right edge
        cmp eax, edi                         ; compare with brick left
        jle noBrickHit                       ; no overlap

        ; ball left < brick right?
        mov eax, ballX                       ; ball left
        mov ebx, edi                         ; brick left
        add ebx, BRICK_WIDTH                 ; brick right edge
        cmp eax, ebx                         ; compare
        jge noBrickHit                       ; no overlap

        ; ball bottom > brick top?
        mov eax, ballY                       ; ball top
        add eax, BALL_SIZE                   ; ball bottom edge
        cmp eax, esi                         ; compare with brick top
        jle noBrickHit                       ; no overlap

        ; ball top < brick bottom?
        mov eax, ballY                       ; ball top
        mov ebx, esi                         ; brick top
        add ebx, BRICK_HEIGHT                ; brick bottom edge
        cmp eax, ebx                         ; compare
        jge noBrickHit                       ; no overlap

        ; --- hit! destroy this brick ---
        pop ecx                              ; restore brick index
        mov BYTE PTR [bricks + ecx], 0       ; mark brick as dead
        neg ballDY                           ; bounce the ball vertically
        add score, 10                        ; add 10 points
        dec bricksLeft                       ; one less brick

        ; beep sound (middle C, short duration)
        invoke Beep, 261, 20

        ; check if red brick (row 2)
        mov eax, ecx                         ; copy index
        xor edx, edx                         ; clear
        mov ebx, BRICK_COLS                  ; cols per row
        div ebx                              ; eax = row
        cmp eax, 2                           ; is it row 2 (red)?
        jne noPowerup                        ; if not, skip
        mov solidBaseTimer, 300              ; 300 ticks = 5 seconds
    noPowerup:

        ; check if all bricks are destroyed (win condition)
        cmp bricksLeft, 0                    ; any bricks remaining?
        jg doneBrickCheck                    ; if yes, continue
        
        ; check for time bonus
        cmp timeSeconds, 120                 ; did they finish in under 2 minutes?
        jg skipBonus                         ; if took longer, no bonus
        add score, 50                        ; add 50 bonus points
    skipBonus:
        
        mov gameState, 1                     ; player wins!
        mov ballActive, 0                    ; stop the ball
        jmp doneBrickCheck                   ; done checking

    noBrickHit:
        pop ecx                              ; restore brick index
    nextBrickCheck:
        inc ecx                              ; next brick
        jmp checkBrickLoop                   ; keep checking
    doneBrickCheck:

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
        
        ; hit the paddle!
        neg ballDY                           ; bounce upward
        
        ; edge mechanic: change x direction based on where it hit
        mov eax, ballX                       ; get ball x
        add eax, BALL_SIZE / 2               ; ball center
        mov ecx, paddleX                     ; paddle left
        add ecx, PADDLE_WIDTH / 3            ; left third boundary
        cmp eax, ecx                         ; hit left third?
        jg checkRightEdge                    ; if not, check right
        mov ballDX, -BALL_SPEED              ; force ball left
        jmp donePaddleEdge
    checkRightEdge:
        mov ecx, paddleX                     ; paddle left
        add ecx, (PADDLE_WIDTH * 2) / 3      ; right third boundary
        cmp eax, ecx                         ; hit right third?
        jl donePaddleEdge                    ; if not, it's middle (keep current dx)
        mov ballDX, BALL_SPEED               ; force ball right
    donePaddleEdge:

        mov eax, PADDLE_Y                    ; reposition ball
        sub eax, BALL_SIZE                   ; above paddle
        mov ballY, eax                       ; update position
        jmp noPaddleBounce                   ; done with bounce

    ballFell:
        ; if solid base is active, do not die, let ball hit bottom
        cmp solidBaseTimer, 0                ; is solid base active?
        jg noPaddleBounce                    ; just keep moving
        
        ; ball went below paddle, lose a life
        dec lives                            ; subtract one life
        cmp lives, 0                         ; any lives left?
        jg stillAlive                        ; if yes, continue
        mov gameState, 2                     ; game over - player lost
        mov ballActive, 0                    ; stop ball
        jmp noPaddleBounce                   ; skip reset
    stillAlive:
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
        mov eax, wParam                      ; get the key code

        ; --- global quit ---
        .IF eax == VK_ESCAPE
            invoke PostQuitMessage, 0
            xor eax, eax
            ret
        .ENDIF

        ; --- branch input based on game state ---
        cmp gameState, 3                     ; title screen?
        je titleInput
        cmp gameState, 4                     ; instruction screen?
        je instrInput
        cmp gameState, 1                     ; won?
        je endInput
        cmp gameState, 2                     ; lost?
        je endInput

        ; --- playing input ---
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
        jmp doneKey

    titleInput:
        .IF eax == VK_RETURN                 ; play game
            mov gameState, 0                 ; playing state
        .ELSEIF eax == VK_I                  ; instructions
            mov gameState, 4                 ; instruction state
        .ENDIF
        jmp doneKey

    instrInput:
        .IF eax == VK_RETURN                 ; play game from instructions
            mov gameState, 0                 ; playing state
        .ENDIF
        jmp doneKey

    endInput:
        .IF eax == VK_R                      ; restart
            ; --- restart the game ---
            mov gameState, 0                 ; reset game state to playing
            mov score, 0                     ; reset score to zero
            mov lives, 3                     ; reset lives to 3
            mov timeSeconds, 0               ; reset time
            mov timerTicks, 0                ; reset ticks
            mov solidBaseTimer, 0            ; reset solid base
            mov bricksLeft, TOTAL_BRICKS     ; reset brick count
            mov paddleX, 280                 ; reset paddle position

            ; reset all bricks to alive
            mov ecx, 0                       ; brick index counter
        resetBricks:
            mov BYTE PTR [bricks + ecx], 1   ; mark brick as alive
            inc ecx                          ; next brick
            cmp ecx, TOTAL_BRICKS            ; all bricks reset?
            jl resetBricks                   ; keep going if not

            ; reset ball onto paddle
            mov ballActive, 0                ; ball on paddle
            mov eax, paddleX                 ; center on paddle
            add eax, PADDLE_WIDTH / 2        ; middle of paddle
            sub eax, BALL_SIZE / 2           ; center ball
            mov ballX, eax                   ; set ball x
            mov eax, PADDLE_Y                ; above paddle
            sub eax, BALL_SIZE               ; on top
            mov ballY, eax                   ; set ball y
        .ELSEIF eax == VK_Q                  ; quit game
            invoke PostQuitMessage, 0
        .ENDIF
        jmp doneKey

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