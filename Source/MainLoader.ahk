#Requires AutoHotkey v2.0
#SingleInstance Force

; --- AYARLAR ---
AppName := "Hukuk Asistanı Pro"
CurrentVersion := "1.0.5"

; ÖNEMLİ: Buraya kendi config.ini dosyanızın RAW (Ham) linkini yapıştırın.
; Test aşamasında yerel dosya yolu da verebilirsiniz (örn: "C:\Temp\config.ini")
; Satış yaparken burası "https://raw.githubusercontent.com/..." gibi olmalı.
ServerConfigURL := "https://raw.githubusercontent.com/gamebizstore-cloud/LegalFlow/refs/heads/main/ServerFiles/config.ini" 

; Uygulamanın çalışacağı ve dosyaları indireceği klasör
LocalMacroDir := A_AppData . "\HukukAsistani\Makrolar"

; Klasör yoksa oluştur
if !DirExist(LocalMacroDir)
    DirCreate(LocalMacroDir)

; --- 1. ADIM: HWID ALMA VE SUNUCU BAĞLANTISI ---
MsgBox("Lisans ve güncellemeler kontrol ediliyor...", AppName, "T1")

MyHWID := GetHWID()
ServerDataFile := GetServerConfig(ServerConfigURL)

if (ServerDataFile = "") {
    MsgBox("Sunucu bağlantısı sağlanamadı! İnternet bağlantınızı kontrol edin.", "Bağlantı Hatası", 16)
    ExitApp
}

; --- 2. ADIM: YÖNETİCİ KİLİDİ KONTROLÜ ---
ForceStop := IniRead(ServerDataFile, "GenelAyarlar", "ForceStop", "0")
if (ForceStop = "1") {
    AdminMsg := IniRead(ServerDataFile, "GenelAyarlar", "AdminMessage", "Sistem kapalı.")
    MsgBox("SİSTEM YÖNETİCİSİ HATASI:`n" . AdminMsg, "Erişim Engellendi", 16)
    ExitApp
}

; --- 3. ADIM: LİSANS KONTROLÜ ---
LicDate := IniRead(ServerDataFile, "Lisanslar", MyHWID, "YOK")

if (LicDate = "YOK") {
    ; -- DÜZELTME: AHK v2'de A_Clipboard kullanılır --
    A_Clipboard := MyHWID 
    
    MsgBox("Bu bilgisayarın lisansı sistemde bulunamadı!`n`nHWID Numaranız otomatik olarak kopyalandı.`n(Yöneticiye göndermek için CTRL+V yapabilirsiniz)`n`nID: " . MyHWID . "`n`nProgram kapatılıyor.", "Lisanssız Kullanım", 48)
    ExitApp
}

; Tarih kontrolü (YYYYMMDD formatında)
Bugun := FormatTime(, "yyyyMMdd")
if (LicDate < Bugun) {
    MsgBox("Lisans süreniz dolmuş! (" . LicDate . ")`nYenilemek için yönetici ile iletişime geçin.", "Süre Doldu", 48)
    ExitApp
}

; --- 4. ADIM: ARAYÜZ VE GÜNCELLEME ---
MainGui := Gui(, AppName . " - " . CurrentVersion)
MainGui.Opt("+Resize")
MainGui.SetFont("s10", "Segoe UI")
MainGui.OnEvent("Close", (*) => ExitApp()) ; Pencere kapanınca script tamamen kapansın

MainGui.Add("Text", "xm w400", "Lisanslı Kullanıcı ID: " . MyHWID)
MainGui.Add("Text", "xm y+5 w400 cGreen", "Lisans Bitiş Tarihi: " . FormatTime(LicDate, "dd.MM.yyyy"))

MainGui.Add("Text", "xm y+20", "Modül Durumları:")
LV := MainGui.Add("ListView", "w600 h300 Grid", ["Makro Adı", "Sunucu Ver.", "Durum", "İşlem"])

; Modül sütun genişliklerini ayarla
LV.ModifyCol(1, 150)
LV.ModifyCol(2, 100)
LV.ModifyCol(3, 150)
LV.ModifyCol(4, 150)

; --- 5. ADIM: MODÜLLERİ İŞLEME ---
try {
    Section := IniRead(ServerDataFile, "Moduller")
} catch {
    Section := ""
}

if (Section = "") {
    LV.Add(, "Veri Yok", "-", "Sunucuda modül tanımı yok", "-")
} else {
    Loop Parse, Section, "`n", "`r" {
        if (A_LoopField = "")
            continue
            
        ModuleName := A_LoopField
        RawData := IniRead(ServerDataFile, "Moduller", ModuleName, "")
        
        ; INI Formatı: Versiyon|Aktiflik|Link
        Split := StrSplit(RawData, "|")
        
        if (Split.Length >= 3) {
            ServerVer := Split[1]
            IsActive := Split[2]
            DownloadUrl := Split[3]
            
            Status := "Hazır"
            LocalPath := LocalMacroDir . "\" . ModuleName . ".ahk"
            
            if (IsActive = "0") {
                Status := "DEAKTİF (Yönetici)"
                ; Güvenlik gereği, deaktif modül yerelde varsa bile çalıştırılmaz.
            } else {
                ; Güncelleme Gerekli mi?
                NeedUpdate := true
                if FileExist(LocalPath) {
                    try {
                        LocalContent := FileRead(LocalPath)
                        ; İndirilen dosyanın içinde "; VER:1.2" gibi bir satır arar
                        if InStr(LocalContent, "; VER:" . ServerVer)
                            NeedUpdate := false
                    }
                }
                
                if (NeedUpdate) {
                    Status := "İndiriliyor..."
                    LV.Modify(LV.GetCount() + 1, , ModuleName, ServerVer, Status, "Bekleniyor") 
                    try {
                        Download(DownloadUrl, LocalPath)
                        Status := "Güncellendi & Hazır"
                    } catch as e {
                        Status := "İndirme Başarısız"
                    }
                } else {
                    Status := "Güncel"
                }
                
                ; Scripti Çalıştır
                if (Status = "Güncel" || Status = "Güncellendi & Hazır") {
                    if FileExist(LocalPath) {
                        try {
                            Run(LocalPath)
                            Status .= " (Çalışıyor)"
                        } catch {
                            Status .= " (Başlatılamadı)"
                        }
                    }
                }
            }
            
            LV.Add(, ModuleName, ServerVer, Status, "Otomatik")
        }
    }
}

MainGui.Show()

; Geçici dosyayı temizle
if FileExist(ServerDataFile)
    try FileDelete(ServerDataFile)

; --- FONKSİYONLAR ---

GetHWID() {
    ; CPU ProcessorId tabanlı basit HWID
    hwid := "BILINMIYOR"
    try {
        objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
        colItems := objWMIService.ExecQuery("Select ProcessorId From Win32_Processor")
        for objItem in colItems {
            hwid := objItem.ProcessorId
        }
    }
    ; CPU ID alınamazsa (sanal makine vb.) Bilgisayar Adını kullan
    if (hwid == "" || hwid == "BILINMIYOR") {
        hwid := A_ComputerName
    }
    return hwid
}

GetServerConfig(url) {
    TempFile := A_Temp . "\temp_hukuk_config.ini"
    
    ; Önceki kalıntıyı temizle
    if FileExist(TempFile)
        try FileDelete(TempFile)
        
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        
        ; --- HİLE BURADA: ---
        ; Linkin sonuna "?t=" ve bilgisayarın çalışma süresini (milisaniye) ekliyoruz.
        ; Böylece GitHub "Bu yeni bir istek" diyerek en güncel dosyayı veriyor.
        req.Open("GET", url . "?t=" . A_TickCount, true)
        
        req.Send()
        req.WaitForResponse()
        
        if (req.Status != 200)
            return ""
            
        ResponseText := req.ResponseText
        FileAppend(ResponseText, TempFile, "UTF-8") 
        return TempFile
    } catch {
        return ""
    }
}
