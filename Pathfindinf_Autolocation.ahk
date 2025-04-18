#SingleInstance Force
SetWorkingDir, %A_ScriptDir%
SetBatchLines, -1  ; 스크립트 실행 속도 최대화

; 전역 변수
global CoordinateNodes := {}  ; 추출된 좌표를 저장할 배열
global CurrentNodeIndex := 1  ; 현재 이동 중인 노드 인덱스
global IsMoving := false     ; 현재 이동 중인지 여부
global PlayerX := 0, PlayerY := 0, PlayerZ := 0  ; 플레이어 현재 좌표
global LastLocationCheck := 0 ; 마지막 위치 확인 시간

; F1: 채팅창에서 /loc 명령어로 좌표 추출 및 노드 추가
F1::
    ; 채팅창 열기
    Send, {Enter}
    Sleep, 100
    
    ; /loc 명령어 입력
    Send, /loc
    Sleep, 100
    Send, {Enter}
    
    ; 채팅창이 업데이트될 시간을 줌
    Sleep, 500
    
    ; 채팅창 영역 캡처 (위치는 게임에 맞게 조정 필요)
    chatX := 50
    chatY := A_ScreenHeight - 300
    chatWidth := 500
    chatHeight := 200
    
    tempImage := A_Temp "\chat_capture.png"
    CaptureScreenRegion(chatX, chatY, chatWidth, chatHeight, tempImage)
    
    ; OCR로 텍스트 추출
    extractedText := ExtractTextFromImage(tempImage)
    
    ; 좌표 패턴 추출
    oldLength := CoordinateNodes.Length()
    ExtractCoordinates(extractedText)
    
    ; 임시 파일 삭제
    FileDelete, %tempImage%
    
    ; 결과 표시
    if (CoordinateNodes.Length() > oldLength) {
        newNode := CoordinateNodes[CoordinateNodes.Length()]
        MsgBox, 0, 좌표 추가, 새 좌표가 추가되었습니다:`nX=%newNode.x%, Y=%newNode.y%, Z=%newNode.z%
        
        ; 현재 플레이어 위치 업데이트
        PlayerX := newNode.x
        PlayerY := newNode.y
        PlayerZ := newNode.z
    } else {
        MsgBox, 0, 좌표 추출 실패, 채팅창에서 좌표 패턴을 찾을 수 없습니다.
    }
return

; F2: 여러 지점 좌표 수집 (자동으로 /loc 여러번 실행)
F2::
    InputBox, numPoints, 좌표 수집, 수집할 좌표 개수를 입력하세요:, , 300, 150
    if ErrorLevel
        return
    
    numPoints := Floor(numPoints)
    if (numPoints < 1)
        return
        
    MsgBox, 0, 좌표 수집 시작, %numPoints%개의 좌표를 수집합니다.`n각 지점에서 멈춰서 F1을 누르세요.
    
    ; 초기 위치 저장
    Send, {Enter}
    Sleep, 100
    Send, /loc
    Sleep, 100
    Send, {Enter}
    Sleep, 500
    
    ; 채팅창 캡처 및 좌표 추출
    chatX := 50
    chatY := A_ScreenHeight - 300
    chatWidth := 500
    chatHeight := 200
    
    tempImage := A_Temp "\chat_capture.png"
    CaptureScreenRegion(chatX, chatY, chatWidth, chatHeight, tempImage)
    extractedText := ExtractTextFromImage(tempImage)
    CoordinateNodes := {} ; 기존 노드 초기화
    ExtractCoordinates(extractedText)
    FileDelete, %tempImage%
    
    if (CoordinateNodes.Length() > 0) {
        startNode := CoordinateNodes[CoordinateNodes.Length()]
        PlayerX := startNode.x
        PlayerY := startNode.y
        PlayerZ := startNode.z
        
        MsgBox, 0, 시작 위치, 시작 위치 좌표:`nX=%PlayerX%, Y=%PlayerY%, Z=%PlayerZ%`n다음 위치로 이동 후 엔터 키를 누르세요.
    } else {
        MsgBox, 0, 오류, 시작 위치 좌표를 찾을 수 없습니다.
        return
    }
    
    ; 좌표 수집 지속
    collectedPoints := 1
    while (collectedPoints < numPoints) {
        ; 다음 위치로 이동 대기
        KeyWait, Enter, D
        
        ; 위치 확인
        Send, {Enter}
        Sleep, 100
        Send, /loc
        Sleep, 100
        Send, {Enter}
        Sleep, 500
        
        ; 채팅창 캡처 및 좌표 추출
        tempImage := A_Temp "\chat_capture.png"
        CaptureScreenRegion(chatX, chatY, chatWidth, chatHeight, tempImage)
        extractedText := ExtractTextFromImage(tempImage)
        oldLength := CoordinateNodes.Length()
        ExtractCoordinates(extractedText)
        FileDelete, %tempImage%
        
        if (CoordinateNodes.Length() > oldLength) {
            collectedPoints++
            newNode := CoordinateNodes[CoordinateNodes.Length()]
            
            if (collectedPoints < numPoints) {
                ToolTip, 좌표 추가됨 (%collectedPoints%/%numPoints%):`nX=%newNode.x%, Y=%newNode.y%, Z=%newNode.z%`n다음 위치로 이동 후 엔터 키를 누르세요., 10, 10
            }
        }
    }
    
    ToolTip, ; 툴팁 제거
    
    ; 결과 표시 및 저장
    if (CoordinateNodes.Length() > 0) {
        resultMsg := "수집된 좌표 노드: " . CoordinateNodes.Length() . "개`n`n"
        for i, node in CoordinateNodes {
            resultMsg .= i . ": X=" . node.x . ", Y=" . node.y . ", Z=" . node.z . "`n"
        }
        MsgBox, 0, 좌표 수집 결과, %resultMsg%
        
        ; 좌표 파일로 저장
        SaveCoordinatesToFile()
    }
return

; F3: 저장된 노드로 경로 탐색 및 이동 시작
F3::
    if (CoordinateNodes.Length() < 1) {
        MsgBox, 0, 오류, 저장된 좌표 노드가 없습니다. F1이나 F2를 눌러 좌표를 먼저 추출하세요.
        return
    }
    
    ; 현재 위치 확인
    GetCurrentPlayerPosition()
    
    ; 경로 탐색 - 추출된 좌표를 순서대로 방문
    MsgBox, 0, 경로 탐색, 추출된 %CoordinateNodes.Length%개의 좌표를 W/A/S/D 키로 순서대로 방문합니다.`n계속하려면 OK를 클릭하세요.
    
    ; 이동 시작
    IsMoving := true
    CurrentNodeIndex := 1
    SetTimer, MoveTowardsNextNode, 100  ; 0.1초마다 이동 방향 조정
return

; F4: 노드 이동 중지
F4::
    IsMoving := false
    SetTimer, MoveTowardsNextNode, Off
    
    ; 모든 이동 키 해제
    ReleaseAllMovementKeys()
    
    MsgBox, 0, 이동 중지, 좌표 노드 이동이 중지되었습니다.
return

; F5: 저장된 좌표 파일 불러오기
F5::
    FileSelectFile, coordFile, 3, , 좌표 파일 선택, Text Files (*.txt)
    if (ErrorLevel)
        return
    
    LoadCoordinatesFromFile(coordFile)
    
    ; 결과 표시
    if (CoordinateNodes.Length() > 0) {
        resultMsg := "불러온 좌표 노드: " . CoordinateNodes.Length() . "개`n`n"
        for i, node in CoordinateNodes {
            resultMsg .= i . ": X=" . node.x . ", Y=" . node.y . ", Z=" . node.z . "`n"
        }
        MsgBox, 0, 좌표 불러오기 결과, %resultMsg%
    }
return

; F6: 현재 플레이어 위치 확인
F6::
    GetCurrentPlayerPosition()
    
    MsgBox, 0, 현재 위치, 현재 플레이어 좌표:`nX=%PlayerX%, Y=%PlayerY%, Z=%PlayerZ%
return

; 주기적으로 현재 노드를 향해 이동하는 함수 (타이머에 의해 호출)
MoveTowardsNextNode:
    if (!IsMoving || CurrentNodeIndex > CoordinateNodes.Length()) {
        IsMoving := false
        SetTimer, MoveTowardsNextNode, Off
        ReleaseAllMovementKeys()
        MsgBox, 0, 이동 완료, 모든 좌표 노드 방문이 완료되었습니다.
        return
    }
    
    ; 현재 목표 노드
    targetNode := CoordinateNodes[CurrentNodeIndex]
    
    ; 현재 위치 갱신 (주기적으로 - 너무 자주 하면 게임 플레이에 방해됨)
    currentTime := A_TickCount
    if (currentTime - LastLocationCheck > 3000) {  ; 3초마다 위치 확인
        GetCurrentPlayerPosition()
        LastLocationCheck := currentTime
    }
    
    ; 현재 위치와 목표 위치 간 거리 계산
    distX := targetNode.x - PlayerX
    distY := targetNode.y - PlayerY
    distZ := targetNode.z - PlayerZ
    
    ; 거리 제곱합의 제곱근 (3D 유클리드 거리)
    distance := Sqrt(distX*distX + distY*distY + distZ*distZ)
    
    ; 이동 상태 표시
    ToolTip, 노드 %CurrentNodeIndex%/%CoordinateNodes.Length%로 이동 중`n현재: (%PlayerX%,%PlayerY%,%PlayerZ%)`n목표: (%targetNode.x%,%targetNode.y%,%targetNode.z%)`n거리: %distance%, 10, 10
    
    ; 목표 도달 확인 (근접 거리에 왔으면 다음 노드로)
    if (distance < 5) {  ; 도달 판정 거리는 게임에 맞게 조정
        CurrentNodeIndex++
        return
    }
    
    ; W/A/S/D 키로 방향 이동 (기본 FPS 방식)
    ; X축은 좌(A)/우(D), Y축은 앞(W)/뒤(S)로 가정
    
    ; 모든 키 초기화
    ReleaseAllMovementKeys()
    
    ; X축 이동
    if (distX > 5) {
        Send, {d down}  ; 우측 이동
    } else if (distX < -5) {
        Send, {a down}  ; 좌측 이동
    }
    
    ; Y축 이동
    if (distY > 5) {
        Send, {w down}  ; 전진
    } else if (distY < -5) {
        Send, {s down}  ; 후진
    }
    
    ; Z축 이동 (필요시 점프 등으로 구현)
    if (distZ > 10) {
        ; 점프가 필요하면 Space 키 사용
        Send, {Space}
    }
return

; 모든 이동 키 해제
ReleaseAllMovementKeys() {
    Send, {w up}
    Send, {a up}
    Send, {s up}
    Send, {d up}
}

; 현재 플레이어 위치 읽기 (/loc 명령어 사용)
GetCurrentPlayerPosition() {
    ; 채팅창 열기
    Send, {Enter}
    Sleep, 100
    
    ; /loc 명령어 입력
    Send, /loc
    Sleep, 100
    Send, {Enter}
    
    ; 채팅창이 업데이트될 시간을 줌
    Sleep, 500
    
    ; 채팅창 영역 캡처 (위치는 게임에 맞게 조정 필요)
    chatX := 50
    chatY := A_ScreenHeight - 300
    chatWidth := 500
    chatHeight := 200
    
    tempImage := A_Temp "\chat_capture.png"
    CaptureScreenRegion(chatX, chatY, chatWidth, chatHeight, tempImage)
    
    ; OCR로 텍스트 추출
    extractedText := ExtractTextFromImage(tempImage)
    
    ; 좌표 패턴 검색
    pattern1 := "O)[\(\[\{]?\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*[\)\]\}]?"
    pattern2 := "O)X\s*[=:]?\s*(-?\d+\.?\d*)[^\d]*Y\s*[=:]?\s*(-?\d+\.?\d*)[^\d]*Z\s*[=:]?\s*(-?\d+\.?\d*)"
    pattern3 := "O)현재\s*위치\s*[:\s]*(-?\d+\.?\d*)[^\d]*(-?\d+\.?\d*)[^\d]*(-?\d+\.?\d*)"  ; 게임에 따라 다른 패턴 추가
    
    foundPosition := false
    
    ; 패턴 검색
    if (RegExMatch(extractedText, pattern1, match)) {
        if (match1 != "" && match2 != "" && match3 != "") {
            PlayerX := match1
            PlayerY := match2
            PlayerZ := match3
            foundPosition := true
        }
    } else if (RegExMatch(extractedText, pattern2, match)) {
        if (match1 != "" && match2 != "" && match3 != "") {
            PlayerX := match1
            PlayerY := match2
            PlayerZ := match3
            foundPosition := true
        }
    } else if (RegExMatch(extractedText, pattern3, match)) {
        if (match1 != "" && match2 != "" && match3 != "") {
            PlayerX := match1
            PlayerY := match2
            PlayerZ := match3
            foundPosition := true
        }
    }
    
    ; 임시 파일 삭제
    FileDelete, %tempImage%
    
    return foundPosition
}

; 텍스트에서 좌표 추출하는 함수
ExtractCoordinates(text) {
    ; 좌표 패턴 정규식 (여러 형식 지원)
    ; 1. (X, Y, Z) 형식
    pattern1 := "O)[\(\[\{]?\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*[\)\]\}]?"
    
    ; 2. X:123 Y:456 Z:789 형식
    pattern2 := "O)X\s*[=:]?\s*(-?\d+\.?\d*)[^\d]*Y\s*[=:]?\s*(-?\d+\.?\d*)[^\d]*Z\s*[=:]?\s*(-?\d+\.?\d*)"
    
    ; 3. "현재 위치: 123 456 789" 형식 (게임에 따라 조정)
    pattern3 := "O)현재\s*위치\s*[:\s]*(-?\d+\.?\d*)[^\d]*(-?\d+\.?\d*)[^\d]*(-?\d+\.?\d*)"
    
    ; 패턴 1 검색
    pos := 1
    while (pos := RegExMatch(text, pattern1, match, pos)) {
        AppendCoordinateNode(match1, match2, match3)
        pos += StrLen(match)
    }
    
    ; 패턴 2 검색
    pos := 1
    while (pos := RegExMatch(text, pattern2, match, pos)) {
        AppendCoordinateNode(match1, match2, match3)
        pos += StrLen(match)
    }
    
    ; 패턴 3 검색
    pos := 1
    while (pos := RegExMatch(text, pattern3, match, pos)) {
        AppendCoordinateNode(match1, match2, match3)
        pos += StrLen(match)
    }
}

; 좌표 노드 추가
AppendCoordinateNode(x, y, z) {
    ; 숫자 형식인지 확인
    if (x = "" || y = "" || z = "")
        return
    
    ; 좌표 노드 생성 및 추가
    node := {x: x, y: y, z: z}
    CoordinateNodes.Push(node)
}

; 좌표를 파일에 저장
SaveCoordinatesToFile() {
    if (CoordinateNodes.Length() < 1)
        return
    
    filename := A_ScriptDir "\coordinates_" A_Now ".txt"
    fileContent := ""
    
    for i, node in CoordinateNodes {
        fileContent .= node.x . "," . node.y . "," . node.z . "`n"
    }
    
    FileDelete, %filename%
    FileAppend, %fileContent%, %filename%
    
    MsgBox, 0, 좌표 저장, 좌표가 파일에 저장되었습니다:`n%filename%
}

; 파일에서 좌표 불러오기
LoadCoordinatesFromFile(filepath) {
    if (!FileExist(filepath))
        return
    
    ; 기존 노드 초기화
    CoordinateNodes := {}
    
    ; 파일 읽기
    FileRead, content, %filepath%
    
    ; 각 라인 처리
    Loop, Parse, content, `n, `r
    {
        if (A_LoopField = "")
            continue
        
        coords := StrSplit(A_LoopField, ",")
        if (coords.Length() >= 3) {
            AppendCoordinateNode(coords[1], coords[2], coords[3])
        }
    }
}

; 지정된 화면 영역 캡처 함수
CaptureScreenRegion(x, y, w, h, outputFile) {
    ; 비트맵 생성 및 캡처
    hBitmap := CreateDIBSection(w, h)
    hDC := CreateCompatibleDC()
    obm := SelectObject(hDC, hBitmap)
    
    ; 화면 영역 복사
    sourceDC := DllCall("GetDC", "Ptr", 0)
    DllCall("BitBlt", "Ptr", hDC, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", sourceDC, "Int", x, "Int", y, "UInt", 0x00CC0020) ; SRCCOPY
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", sourceDC)
    
    ; 비트맵 저장
    SaveHBITMAPToFile(hBitmap, outputFile)
    
    ; 리소스 해제
    SelectObject(hDC, obm)
    DeleteObject(hBitmap)
    DeleteDC(hDC)
}

; Windows OCR API를 사용하여 이미지에서 텍스트 추출하는 함수
ExtractTextFromImage(imagePath) {
    ; COM 객체 생성
    try {
        static ocrEngine := ComObjCreate("Windows.Media.Ocr.OcrEngine")
    } catch e {
        ; Windows 10 이상에서만 작동
        MsgBox, 0, 오류, Windows OCR 엔진을 사용할 수 없습니다. Windows 10 이상이 필요합니다.
        return ""
    }
    
    ; COM 객체로 이미지 로드
    try {
        fileObj := ComObjCreate("WIA.ImageFile")
        fileObj.LoadFile(imagePath)
        
        ; 이미지 변환 (필요한 경우)
        imageObj := ComObjCreate("WIA.ImageProcess")
        imageObj.Filters.Add(imageObj.FilterInfos("Convert").FilterID)
        imageObj.Filters(1).Properties("FormatID") := "{B96B3CAF-0728-11D3-9D7B-0000F81EF32E}" ; PNG 형식으로 변환
        convertedImage := imageObj.Apply(fileObj)
        
        ; OCR 수행
        ocrResult := ocrEngine.RecognizeAsync(convertedImage).GetResults()
        
        ; 결과 텍스트 추출
        resultText := ""
        Loop % ocrResult.Lines.Count {
            line := ocrResult.Lines.GetAt(A_Index - 1)
            resultText .= line.Text . "`n"
        }
        
        return resultText
    } catch e {
        MsgBox, 0, OCR 오류, %e%
        return ""
    }
}

; 화면 캡처 관련 함수들 (GDI+)
CreateDIBSection(w, h, bpp=32) {
    VarSetCapacity(bi, 40, 0)
    NumPut(40, bi, 0, "uint")
    NumPut(w, bi, 4, "uint")
    NumPut(h, bi, 8, "uint")
    NumPut(1, bi, 12, "ushort")
    NumPut(bpp, bi, 14, "ushort")
    
    hDC := DllCall("GetDC", "ptr", 0)
    hBM := DllCall("CreateDIBSection", "ptr", hDC, "ptr", &bi, "uint", 0, "ptr*", 0, "ptr", 0, "uint", 0, "ptr")
    DllCall("ReleaseDC", "ptr", 0, "ptr", hDC)
    return hBM
}

CreateCompatibleDC() {
    return DllCall("CreateCompatibleDC", "ptr", 0)
}

SelectObject(hDC, hObject) {
    return DllCall("SelectObject", "ptr", hDC, "ptr", hObject)
}

DeleteObject(hObject) {
    return DllCall("DeleteObject", "ptr", hObject)
}

DeleteDC(hDC) {
    return DllCall("DeleteDC", "ptr", hDC)
}

SaveHBITMAPToFile(hBitmap, filePath) {
    ; GDI+ 시작
    VarSetCapacity(si, 16, 0)
    NumPut(1, si, "UChar")
    DllCall("gdiplus\GdiplusStartup", "ptr*", pToken, "ptr", &si, "ptr", 0)
    
    ; 비트맵을 GDI+ 비트맵으로 변환
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBitmap, "ptr", 0, "ptr*", pBitmap)
    
    ; CLSID 가져오기 (PNG 형식)
    VarSetCapacity(CLSID, 16, 0)
    DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", &CLSID)
    
    ; 파일 저장
    DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", filePath, "ptr", &CLSID, "ptr", 0)
    
    ; 리소스 해제
    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    DllCall("gdiplus\GdiplusShutdown", "ptr", pToken)
}

; 3D 거리 계산 함수
Sqrt(n) {
    return n ** 0.5
}

Esc::ExitApp
