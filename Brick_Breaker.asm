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
WM_PAINT            EQU 000Fh
TRANSPARENT_BK      EQU 1
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
FillRect PROTO :DWORD,:DWORD,:DWORD

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

        ; --- title text above border ---
        invoke SetBkMode, hdc, TRANSPARENT_BK ; transparent text background
        invoke SetTextColor, hdc, 0000FFFFh   ; yellow text color
        invoke TextOutA, hdc, 270, 15, ADDR titleText, 13 ; draw title

        invoke EndPaint, hWin, ADDR ps       ; finish painting
        xor eax, eax                         ; return 0 (message handled)
        ret

    .ELSEIF eax == WM_DESTROY
        invoke PostQuitMessage, 0
        xor eax, eax
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