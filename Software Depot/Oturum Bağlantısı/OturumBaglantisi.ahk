; VER:1.2
#Requires AutoHotkey v2.0
MsgBox "Makro yüklendi!"
#SingleInstance Force
SetWorkingDir A_ScriptDir
SetTitleMatchMode 2         
CoordMode "Mouse", "Window" 
CoordMode "Pixel", "Window" 

; --- AYAR DOSYASI VE VARSAYILANLAR ---
Global SettingsFile := A_ScriptDir . "\settings.ini"
; Ayar dosyasından kısayolu oku, yoksa varsayılan "F3" olsun
Global CurrentHotkey := IniRead(SettingsFile, "Settings", "Hotkey", "F3")
Global CurrentSession := 2  ; Varsayılan olarak Oturum 2 seçili
Global StartupShortcut := A_Startup . "\Oturuma Bağlan.lnk" ; Başlangıç kısayolu
Global HotkeyMenuItemName := "Kısayol Değiştir (" . CurrentHotkey . ")" ; Menü ismini değişkende tut

; --- İKON AYARI ---
IconPath := A_ScriptDir . "\icon.ico"
if FileExist(IconPath) {
    TraySetIcon(IconPath)
}
; ------------------

; --- TRAY MENÜSÜ AYARLARI ---
A_TrayMenu.Delete() ; Varsayılan menüyü temizle

; Başlık
A_TrayMenu.Add("Hangi Oturuma Bağlanmak İstersiniz?", (*) => {}) 
A_TrayMenu.Disable("Hangi Oturuma Bağlanmak İstersiniz?")
A_TrayMenu.Add() ; Çizgi

; Oturum Seçenekleri
A_TrayMenu.Add("Oturum 1", SelectSession1)
A_TrayMenu.Add("Oturum 2", SelectSession2)
A_TrayMenu.Add() ; Çizgi

; Windows Başlangıç Seçeneği
A_TrayMenu.Add("Windows ile Başlat", ToggleStartup)
A_TrayMenu.Add() ; Çizgi

; Kısayol Değiştirme (İstediğin gibi alta alındı)
A_TrayMenu.Add(HotkeyMenuItemName, ChangeHotkeyUI)
A_TrayMenu.Add() ; Çizgi

; Çıkış
A_TrayMenu.Add("Çıkış", (*) => ExitApp())

; --- BAŞLANGIÇ KONTROLLERİ ---
UpdateTrayCheck() ; Oturum tikini ayarla
; Eğer kısayol varsa 'Windows ile Başlat' tikini at
if FileExist(StartupShortcut) {
    A_TrayMenu.Check("Windows ile Başlat")
}

; --- DİNAMİK KISAYOL KAYDI ---
; Script başladığında kayıtlı kısayolu aktif et
try {
    Hotkey CurrentHotkey, RunAutomation, "On"
} catch {
    MsgBox("Kayıtlı kısayol geçersiz, F3 varsayılan olarak atandı.")
    CurrentHotkey := "F3"
    Hotkey "F3", RunAutomation, "On"
    ; Menü ismini de güncelle
    OldName := HotkeyMenuItemName
    HotkeyMenuItemName := "Kısayol Değiştir (F3)"
    try A_TrayMenu.Rename(OldName, HotkeyMenuItemName)
}

; --- FONKSİYONLAR: SEÇİM & AYAR ---
SelectSession1(*) {
    Global CurrentSession := 1
    UpdateTrayCheck()
}

SelectSession2(*) {
    Global CurrentSession := 2
    UpdateTrayCheck()
}

UpdateTrayCheck() {
    if (CurrentSession == 1) {
        A_TrayMenu.Check("Oturum 1")
        A_TrayMenu.Uncheck("Oturum 2")
    } else {
        A_TrayMenu.Uncheck("Oturum 1")
        A_TrayMenu.Check("Oturum 2")
    }
}

ToggleStartup(*) {
    if FileExist(StartupShortcut) {
        try {
            FileDelete(StartupShortcut)
            A_TrayMenu.Uncheck("Windows ile Başlat")
            MsgBox("Windows başlangıcından kaldırıldı.", "Bilgi", "T1")
        } catch as err {
            MsgBox("Kısayol silinemedi: " err.Message)
        }
    } else {
        try {
            FileCreateShortcut(A_ScriptFullPath, StartupShortcut, A_ScriptDir)
            A_TrayMenu.Check("Windows ile Başlat")
            MsgBox("Windows başlangıcına eklendi.", "Bilgi", "T1")
        } catch as err {
            MsgBox("Kısayol oluşturulamadı: " err.Message)
        }
    }
}

; --- KISAYOL DEĞİŞTİRME MEKANİZMASI ---
ChangeHotkeyUI(*) {
    hkGui := Gui(, "Kısayol Belirle")
    hkGui.Add("Text",, "Yeni kısayol tuşuna basın:")
    
    ; Hotkey Eşleşme Kontrolü
    hkControl := hkGui.Add("Hotkey", "vNewHotkey w200", CurrentHotkey) 
    
    hkGui.Add("Button", "Default w100", "Kaydet").OnEvent("Click", (*) => SaveNewHotkey(hkGui, hkControl))
    hkGui.Show()
}

SaveNewHotkey(guiObj, controlObj) {
    NewKey := controlObj.Value
    
    if (NewKey == "") {
        MsgBox("Lütfen bir tuşa basın.", "Uyarı")
        return
    }

    try {
        ; Eski kısayolu devre dışı bırak
        if (CurrentHotkey != "")
            Hotkey CurrentHotkey, "Off"

        ; Yeni kısayolu ata
        Hotkey NewKey, RunAutomation, "On"

        ; Başarılı ise kaydet ve güncelle
        Global CurrentHotkey := NewKey
        IniWrite(CurrentHotkey, SettingsFile, "Settings", "Hotkey")
        
        ; Menüdeki yazıyı güncelle (Güvenli Yöntem: İsim üzerinden)
        Global HotkeyMenuItemName
        NewMenuName := "Kısayol Değiştir (" . CurrentHotkey . ")"
        
        try {
            A_TrayMenu.Rename(HotkeyMenuItemName, NewMenuName)
            HotkeyMenuItemName := NewMenuName ; Yeni ismi global değişkene kaydet
        } catch {
            ; Eğer isim bulamazsa menüyü tekrar oluştur (Fallback)
             A_TrayMenu.Delete() 
             Reload() ; En temizi scripti yeniden başlatmak olabilir ama burada hata vermemesi lazım
        }
        
        guiObj.Destroy()
        MsgBox("Kısayol başarıyla değiştirildi: " . CurrentHotkey, "Bilgi", "T1")

    } catch as err {
        MsgBox("Bu tuş kombinasyonu desteklenmiyor veya kullanımda.`nHata: " . err.Message)
        ; Hata olursa eskiyi geri aç
        Hotkey CurrentHotkey, RunAutomation, "On"
    }
}

; --- ANA OTOMASYON KODU (Eski F3:: bloğu buraya taşındı) ---
RunAutomation(*) {
    ; --- MOUSE POZİSYONUNU KAYDET ---
    CoordMode "Mouse", "Screen"
    MouseGetPos &OrigX, &OrigY
    CoordMode "Mouse", "Window" 
    ; --------------------------------

    Loop {
        try {
            shouldRetry := false 

            ; KİLİT AÇILIRKEN MÜDAHALE EDİLMESİN
            Thread "Priority", 2147483647 
            BlockInput true 
            
            try {
                shouldRetry := PerformAutomationTasks()
            } finally {
                ForceUnlockSafety()
            }

            if (shouldRetry == "RETRY") {
                continue
            } else {
                break
            }

        } catch as err {
            ForceUnlockSafety()
            MsgBox "Kritik Hata: " err.Message
            break
        }
    }

    ; --- MOUSE POZİSYONUNU GERİ YÜKLE ---
    CoordMode "Mouse", "Screen"
    SetMouseDelay -1 ; Işınlanma hızı (Kaydırma yapmaz)
    MouseMove OrigX, OrigY
    CoordMode "Mouse", "Window"
    ; ------------------------------------
}

PerformAutomationTasks() {
    ; --- UUYARI/HATA PENCERESİ KAPATMA ---
    ; Başlık: "Pratik İcra", İçerik Metni: "Hata Oluştu"
    ; Sadece başlığa bakarsak ana programı kapatabilir, o yüzden metin şart.
    warningTitle := "Pratik İcra ahk_exe Pratik İcra.exe"
    warningText := "Hata Oluştu" 
    
    if WinExist(warningTitle, warningText) {
        RunWait('taskkill /F /FI "WINDOWTITLE eq Pratik İcra" /FI "WINDOWTEXT eq Hata Oluştu*"',, "Hide") ; Alternatif zorla kapatma
        ; Veya standart yöntem:
        if WinExist(warningTitle, warningText) {
             WinClose(warningTitle, warningText)
             WinWaitClose(warningTitle, warningText, 1) ; 1 sn bekle
        }
        Sleep 100 ; Kapanma sonrası nefes alma
    }
    ; -------------------------------------

    targetWin := "Uyap Oturum Seç ahk_exe Pratik İcra.exe"
    mainAppWin := "Pratik İcra ahk_exe Pratik İcra.exe"

    ; --- OTURUM SEÇİMİNE GÖRE KOORDİNATLAR ---
    if (CurrentSession == 1) {
        ; OTURUM 1 KOORDİNATLARI
        SolUstX := 471, SolUstY := 238
        SagAltX := 557, SagAltY := 258
        TargetClickX := 79, TargetClickY := 246
    } else {
        ; OTURUM 2 KOORDİNATLARI 
        SolUstX := 470, SolUstY := 264
        SagAltX := 572, SagAltY := 286
        TargetClickX := 155, TargetClickY := 273
    }
    ; -----------------------------------------

    SetMouseDelay -1 ; GENEL IŞINLANMA HIZI
    SetControlDelay -1

    ; --- 1. PENCERE KAPAT/AÇ DÖNGÜSÜ ---
    if WinExist(targetWin) {
        WinClose(targetWin)
        WinWaitClose(targetWin, , 2)
        Sleep 50 
    }

    if WinExist(mainAppWin) {
        WinActivate(mainAppWin)
        if WinWaitActive(mainAppWin, , 2) {
            Sleep 50 
            
            ; --- Yeni İşlem ---
            Click 310, 49  ; Belirtilen koordinata tıkla
            Sleep 100
            Send "{Up 2}"  ; 2 Kere Yukarı Ok
            Sleep 50
            Send "{Enter}" ; Enter
            
            WinWait(targetWin, , 3) 
        }
    }

    ; --- 2. RESİM ARAMA & İŞLEM ---
    if WinExist(targetWin) {
        WinActivate(targetWin)
        if !WinWaitActive(targetWin, , 2)
            return false
        
        Sleep 150 ; Pencere grafikleri otursun diye minimum bekleme

        ; Resim Yolu ve Ayarları (*100 tolerans)
        imageFullPath := "*100 " . A_ScriptDir . "\bağlandı.png"
        FoundX := 0, FoundY := 0

        ; Arkaplanda sessiz arama
        if ImageSearch(&FoundX, &FoundY, SolUstX, SolUstY, SagAltX, SagAltY, imageFullPath) {
            
            ; --- BAŞARILI İŞLEM ---
            SetMouseDelay -1 ; Işınlanma hızı (Kaydırma yok)
            
            ; 1. Sol Tık (Seçim)
            Click TargetClickX, TargetClickY
            Sleep 50 

            ; 2. Sağ Tık (Menü)
            Click "Right", TargetClickX, TargetClickY
            Sleep 250 ; Menü açılış süresi

            ; 3. Klavye İşlemleri (Hızlı)
            Send "{Down}"
            Sleep 30 
            Send "{Down}"
            Sleep 30 
            Send "{Down}"
            Sleep 30 
            Send "{Enter}"
            
            ; 4. Pencereleri Kapatma / Aşağı Atma
            Sleep 100 ; Enter'ın algılanması için biraz bekleme
            
            ; Önce Uyap Oturum Seç penceresini küçült (Hala açıksa)
            if WinExist(targetWin) {
                WinMinimize(targetWin)
                
                ; ÇÖZÜM: Pencere modal olduğu için küçültülse bile ana programı "Disabled" modda bırakabilir.
                ; Bu komut ana programın kilidini zorla açar (Re-enable).
                if WinExist(mainAppWin) {
                    try WinSetEnabled(true, mainAppWin)
                }
            }
            
            ; Sonra Ana pencereyi küçült
            if WinExist(mainAppWin) {
                WinMinimize(mainAppWin)
            }
            
            return "SUCCESS"

        } else {
            ; --- BAŞARISIZ ---
            WinClose(targetWin)
            WinMinimize(mainAppWin)
            
            ; Kullanıcıya sormak için kilidi açıyoruz
            BlockInput false 
            Result := MsgBox("Seçilen oturum (" CurrentSession ") için 'bağlandı' yazısı bulunamadı.`n`nTekrar denemek ister misiniz?", "Bulunamadı", 4 + 32)
            
            if (Result == "Yes")
                return "RETRY" 
            else 
                return "FAIL"
        }
    }
    return "FAIL"
}

ForceUnlockSafety() {
    BlockInput false
    BlockInput "MouseMoveOff"
    Sleep 100
}
