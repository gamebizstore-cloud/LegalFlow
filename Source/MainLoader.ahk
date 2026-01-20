#Requires AutoHotkey v2.0
#SingleInstance Force

; --- AYARLAR ---
AppName := "LegalFlow"
CurrentVersion := "1.0.0" ; Versiyonu güncelledik

; GitHub'daki config dosyanızın RAW linki buraya:
ServerConfigURL := "https://raw.githubusercontent.com/gamebizstore-cloud/LegalFlow/refs/heads/main/ServerFiles/config.ini" 

LocalMacroDir := A_AppData . "\HukukAsistani\Makrolar"
if !DirExist(LocalMacroDir)
    DirCreate(LocalMacroDir)

; --- LİSANS VE GÜVENLİK ---
MsgBox("Sistem kontrolleri yapılıyor...", AppName, "T1")

MyHWID := GetHWID()
ServerDataFile := GetServerConfig(ServerConfigURL)

if (ServerDataFile = "") {
    MsgBox("Sunucu bağlantı hatası! Config dosyası okunamadı.", "Hata", 16)
    ExitApp
}

; 2. Lisans Kontrolü
LicDate := IniRead(ServerDataFile, "Lisanslar", MyHWID, "YOK")
if (LicDate = "YOK") {
    A_Clipboard := MyHWID 
    MsgBox("LİSANS HATASI!`n`nID'niz kopyalandı: " . MyHWID, "Lisanssız", 48)
    ExitApp
}

; --- ARAYÜZ VE GÜNCELLEME ---
MainGui := Gui(, AppName . " - Yönetici Paneli")
MainGui.Opt("+Resize")
MainGui.SetFont("s9", "Segoe UI")
MainGui.OnEvent("Close", (*) => ExitApp())

MainGui.Add("Text", "xm w400", "Kullanıcı ID: " . MyHWID)
MainGui.Add("Text", "xm y+5 w400 cGreen", "Lisans Bitiş: " . FormatTime(LicDate, "dd.MM.yyyy"))

MainGui.Add("Text", "xm y+20", "Yüklü Modüller:")
LV := MainGui.Add("ListView", "w650 h300 Grid", ["Modül Adı", "Ver.", "Durum", "Hata Detayı"])
LV.ModifyCol(1, 150)
LV.ModifyCol(2, 50)
LV.ModifyCol(3, 150)
LV.ModifyCol(4, 250)

; --- MODÜL İŞLEMLERİ ---
try {
    Section := IniRead(ServerDataFile, "Moduller")
} catch {
    Section := ""
}

if (Section != "") {
    Loop Parse, Section, "`n", "`r" {
        if (A_LoopField = "")
            continue
            
        ; Eşittir işaretinden böl
        SplitLine := StrSplit(A_LoopField, "=", , 2)
        if (SplitLine.Length < 2)
            continue
            
        ModuleName := SplitLine[1]
        RawData := SplitLine[2]
        
        ; Veri: Versiyon|Aktiflik|Link
        Split := StrSplit(RawData, "|")
        
        if (Split.Length >= 3) {
            ServerVer := Split[1]
            IsActive := Split[2]
            DownloadUrl := Split[3]
            
            LocalPath := LocalMacroDir . "\" . ModuleName . ".ahk"
            Status := "Hazır"
            ErrDetail := ""
            
            if (IsActive = "0") {
                Status := "PASİF"
                ErrDetail := "Yönetici kapattı"
            } else {
                ; Güncelleme Kontrolü
                NeedUpdate := true
                if FileExist(LocalPath) {
                    try {
                        LocalContent := FileRead(LocalPath)
                        if InStr(LocalContent, "; VER:" . ServerVer)
                            NeedUpdate := false
                    }
                }
                
                if (NeedUpdate) {
                    Status := "İndiriliyor..."
                    Row := LV.Add(, ModuleName, ServerVer, Status, "")
                    
                    ; GÜVENLİ İNDİRME FONKSİYONUNU KULLANIYORUZ
                    DownloadResult := DownloadFileSafe(DownloadUrl, LocalPath)
                    
                    if (DownloadResult = "OK") {
                        Status := "Güncellendi"
                        LV.Modify(Row, , ModuleName, ServerVer, Status, "Başarılı")
                    } else {
                        Status := "İndirme Hatası"
                        ErrDetail := DownloadResult ; Hatanın sebebini yaz (404 vs)
                        LV.Modify(Row, , ModuleName, ServerVer, Status, ErrDetail)
                    }
                } else {
                    Status := "Güncel"
                    LV.Add(, ModuleName, ServerVer, Status, "")
                }
                
                ; Sadece güncelleme başarılıysa veya zaten güncelse çalıştır
                if (Status = "Güncel" || Status = "Güncellendi") {
                    if FileExist(LocalPath) {
                        try {
                            Run(LocalPath)
                            Status .= " (Çalışıyor)"
                            LV.Modify(LV.GetCount(), , , , Status)
                        } catch {
                            LV.Modify(LV.GetCount(), , , , Status, "Çalıştırma hatası")
                        }
                    }
                }
            }
        }
    }
}

MainGui.Show()

; --- GÜVENLİ FONKSİYONLAR ---

DownloadFileSafe(Url, SavePath) {
    ; Standart Download() yerine bunu kullanıyoruz.
    ; 404 hatalarını dosyaya kaydetmez.
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", Url . "?nocache=" . A_TickCount, true)
        req.Send()
        req.WaitForResponse()
        
        if (req.Status != 200) {
            return "HTTP Hata Kodu: " . req.Status ; Örn: 404 Not Found
        }
        
        FileDelete(SavePath) ; Eski dosyayı sil
        
        ; AHK dosyaları genellikle UTF-8 with BOM veya UTF-8 olmalı
        FileAppend(req.ResponseText, SavePath, "UTF-8")
        
        return "OK"
    } catch as e {
        return "Bağlantı Hatası: " . e.Message
    }
}

GetHWID() {
    hwid := "BILINMIYOR"
    try {
        objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
        colItems := objWMIService.ExecQuery("Select ProcessorId From Win32_Processor")
        for objItem in colItems
            hwid := objItem.ProcessorId
    }
    if (hwid == "" || hwid == "BILINMIYOR")
        hwid := A_ComputerName
    return hwid
}

GetServerConfig(url) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", url . "?nocache=" . A_TickCount, true)
        req.Send()
        req.WaitForResponse()
        
        if (req.Status != 200) {
            MsgBox("Sunucu Hatası Kodu: " . req.Status . "`nLink: " . url, "Hata", 16)
            return ""
        }
            
        TempFile := A_Temp . "\temp_hukuk_config.ini"
        if FileExist(TempFile)
            try FileDelete(TempFile)
        
        FileAppend(req.ResponseText, TempFile, "UTF-8")
        return TempFile
    } catch as e {
        MsgBox("Bağlantı Hatası Detayı:`n" . e.Message . "`n`nUrl: " . url, "Kritik Hata", 16)
        return ""
    }
}


