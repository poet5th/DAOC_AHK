; Jabremen님 코드 향상 버전
; 설정 섹션
#SingleInstance Force      ; 이전 스크립트 인스턴스 자동 종료
#UseHook On                ; 키보드 훅 사용
SetKeyDelay, 50, 50        ; 키 입력 기본 딜레이 설정, 0.05초
CoordMode, Pixel, Window   ; 픽셀 좌표를 게임 창 내부 기준으로 설정
CoordMode, Mouse, Window   ; 마우스 좌표를 게임 창 내부 기준으로 설정

; 게임 창 정보 (Window Spy로 찾은 정보로 Camelot 클라이언트 정보.)
global GameWindowTitle := "Camelot"      ; 게임 창 제목
global GameWindowClass := "ahk_class Camelot" ; 게임 클래스(확인 필요)
global GameExeName := "ahk_exe Camelot.exe" ; 게임 실행 파일명(확인 필요)

; 창 좌표 확인 도우미 함수
; F10 키를 누르면 현재 마우스 좌표가 게임 창 기준으로 표시됨
F10::
    MouseGetPos, MouseX, MouseY
    PixelGetColor, color, %MouseX%, %MouseY%
    ToolTip, X: %MouseX%, Y: %MouseY%, 색상: %color%, 0, 0
    SetTimer, RemoveToolTip, -5000
return

; 전역 변수
global needPort := true    ; 처음에는 포트가 필요
global isRunning := false  ; 스크립트 실행 상태
global checkInterval := 20000 ; 기본 체크 간격 (20초)

; 좌표 설정 (게임 UI에 맞게 조정 필요, F10키를 눌러 좌료를 편집해 주세요.) 
global reviveButtonX := 165
global reviveButtonY := 165
global checkColorX := 233
global checkColorY := 140

; F12: 스크립트 시작/중지 토글
F12::
    if (isRunning) {
        isRunning := false
        SoundPlay, *-1 ; 중지 알림음
        ToolTip, 스크립트 중지됨, 0, 0
        SetTimer, RemoveToolTip, -3000
    } else {
        isRunning := true
        needPort := true ; 시작할 때는 항상 포트부터
        SoundPlay, *64 ; 시작 알림음
        ToolTip, 스크립트 시작됨, 0, 0
        SetTimer, RemoveToolTip, -3000
        SetTimer, MainLoop, 100 ; 메인 루프 시작
    }
return

; F11: 게임 창 확인 및 활성화
F11::
    if WinExist(GameExeName) {
        WinActivate
        ToolTip, 게임 창 활성화됨, 0, 0
    } else {
        ToolTip, 게임 창을 찾을 수 없음, 0, 0
    }
    SetTimer, RemoveToolTip, -3000
return

; ESC: 긴급 정지
Esc::
    if (isRunning) {
        isRunning := false
        SoundPlay, *16 ; 경고음
        ToolTip, 스크립트 긴급 정지!, 0, 0
        SetTimer, RemoveToolTip, -3000
    }
return

; 메인 루프 함수
MainLoop:
    if (!isRunning) {
        SetTimer, MainLoop, Off
        return
    }
    
    ; 게임 창이 활성화되어 있는지 확인
    if (!WinActive(GameExeName)) {
        WinActivate, %GameExeName%
        Sleep, 200
        
        ; 창 활성화 후 좌표계 재설정 (중요: 창 모드에서는 항상 활성화 확인 필요)
        CoordMode, Pixel, Window
        CoordMode, Mouse, Window
    }
    
    ; 메인 로직 실행
    if (!needPort) {
        CheckReviveStatus()
    } else {
        PerformPortSequence()
    }
    
    ; 다음 검사 예약
    SetTimer, MainLoop, %checkInterval%
return

; 부활 상태 체크 함수
CheckReviveStatus() {
    ; 시각적 디버깅 정보
    ToolTip, 부활 상태 확인 중..., 0, 0
    
    ; 색상 체크
    PixelGetColor, color, %checkColorX%, %checkColorY%
    green_value := (color >> 8) & 0xFF
    
    if (green_value == 0xFF) { ; 부활 타이머 절반 지난 경우
        ToolTip, 부활 타이머 절반 지남 - 부활 버튼 클릭, 0, 0
        MouseMove, %reviveButtonX%, %reviveButtonY%, 5 ; 부드럽게 이동
        Sleep, 100
        MouseClick, left, %reviveButtonX%, %reviveButtonY%
        needPort := true ; 부활 버튼을 눌렀으니, 다음으로 포트가 필요
        return
    } else { ; 부활 타이머가 절반 지나지 않거나 죽지 않은 경우
        ToolTip, 정상 상태 - 접속 유지 스킬 사용, 0, 0
        PressKeyWithFeedback(6) ; 접속 종료 방지
    }
    
    SetTimer, RemoveToolTip, -2000
}

; 포트 시퀀스 실행 함수
PerformPortSequence() {
    ToolTip, 포트 시퀀스 시작..., 0, 0
    
    ; 포트 시퀀스 (5초마다 상태 업데이트)
    PressKeyWithFeedback(1)
    ToolTip, 포트 시퀀스 (1/12): 키 1 누름, 0, 0
    Sleep, 5000
    
    ToggleNumLock()
    ToolTip, 포트 시퀀스 (2/12): NumLock 토글, 0, 0
    Sleep, 4000
    
    PressKeyWithFeedback(2)
    ToolTip, 포트 시퀀스 (3/12): 키 2 누름, 0, 0
    Sleep, 4000
    
    PressKeyWithFeedback(3)
    ToolTip, 포트 시퀀스 (4/12): 키 3 누름, 0, 0
    Sleep, 1500
    
    PressKeyWithFeedback(4)
    ToolTip, 포트 시퀀스 (5/12): 키 4 누름, 0, 0
    Sleep, 1000
    
    ToggleNumLock()
    ToolTip, 포트 시퀀스 (6/12): NumLock 토글, 0, 0
    Sleep, 500
    
    PressKeyWithFeedback("56")
    ToolTip, 포트 시퀀스 (7/12): 키 56 누름, 0, 0
    Sleep, 500
    
    ToggleNumLock()
    ToolTip, 포트 시퀀스 (8/12): NumLock 토글, 0, 0
    Sleep, 500
    
    PressKeyWithFeedback(3)
    ToolTip, 포트 시퀀스 (9/12): 키 3 누름, 0, 0
    Sleep, 1000
    
    PressKeyWithFeedback(4)
    ToolTip, 포트 시퀀스 (10/12): 키 4 누름, 0, 0
    Sleep, 1000
    
    ToggleNumLock()
    ToolTip, 포트 시퀀스 (11/12): NumLock 토글, 0, 0
    Sleep, 500
    
    PressKeyWithFeedback(5)
    ToolTip, 포트 시퀀스 (12/12): 키 5 누름, 0, 0
    Sleep, 500
    
    ToolTip, 포트 시퀀스 완료, 0, 0
    Sleep, 1000
    
    needPort := false
    SetTimer, RemoveToolTip, -1000
}

; 키 입력 함수 (피드백 포함)
PressKeyWithFeedback(key) {
    Send, %key%
    Sleep, 50
}

; NumLock 토글 함수
ToggleNumLock() {
    Send, {NumLock}
    Sleep, 50
}

; 툴팁 제거 함수
RemoveToolTip:
    ToolTip
return

; 스크립트 초기화
Init:
    SoundPlay, *64
    ToolTip, 스크립트가 준비되었습니다.`nF10: 마우스 좌표 확인`nF11: 게임 창 활성화`nF12: 스크립트 시작/중지, 0, 0
    SetTimer, RemoveToolTip, -8000
return

; 스크립트 자동 초기화
gosub, Init

; 도움말 표시
F1::
    MsgBox, 0, 게임 자동화 스크립트 도움말, 
    (
    클라이언트 내부 좌표를 사용하는 게임 자동화 스크립트

    기능 키:
    F1: 이 도움말 표시
    F10: 마우스 좌표 및 색상 확인 (좌표 설정에 사용)
    F11: 게임 창 활성화
    F12: 스크립트 시작/중지
    ESC: 긴급 정지

    사용 전 반드시 수정해야 할 설정:
    1. 게임 창 정보 (GameWindowTitle, GameWindowClass, GameExeName)
    2. 부활 버튼 좌표 (reviveButtonX, reviveButtonY)
    3. 색상 체크 좌표 (checkColorX, checkColorY)

    주의: 게임 창 모드로 설정되어 있어, 게임 창이 활성화된 상태에서만 정상 작동합니다.
    )
return