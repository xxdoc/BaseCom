VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "Win32ApiDialogsEx"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
Option Explicit

'==================================================================================================
'� 2000 Klaus Prinz Software Consulting
'       Schnittstelle zu comdlg32-Dialogen und SHBrowseForFolder
'==================================================================================================
'Methoden:
'--------------------------------------------------------------------------------------------------
'   GetColor
'       Farbdialog erzeugen und Auswahl zur�ckgeben
'   GetOpenFileName
'       GetOpenFileName-Dialog erzeugen und Auswahl zur�ckgeben
'   GetSaveFileName
'       GetSaveFileName-Dialog erzeugen und Auswahl zur�ckgeben
'   GetPath
'       SHBrowseForFolder-Dialog erzeugen und Auswahl zur�ckgeben
'==================================================================================================
'Eigenschaften:
'--------------------------------------------------------------------------------------------------
'   CustomizedColor
'       Schreib- und Lesezugriff auf Array der benutzerdefinierten Farben
'==================================================================================================
'Private Methoden:
'--------------------------------------------------------------------------------------------------
'   ClearAPIString
'       �bergebenen String bis vor ersten Chr$(0) abschneiden
'   ComposeFileFilter
'       Filterausdruck f�r OPENFILENAME.lpstrFilter zusammenstellen
'==================================================================================================

Private cSysReg           As New Win32ApiRegistry   'Instanz auf Registry-Klasse
Private lngCustColors(15) As Long       'Array f�r die 16 benutzerdefinierte Farben

'Enumeration zur Unterscheidung von GetOpen- und GetSaveFileName-Dialog
Private Enum enumSaveOpenFileName
    enumOpenFileName = 1
    enumSaveFileName = 2
End Enum

'Struktur f�r OpenFile und SaveFile
Private Type OpenFilename

    lStructSize As Long
    hwndOwner As Long
    hInstance As Long
    lpstrFilter As String
    lpstrCustomFilter As String
    nMaxCustFilter As Long
    nFilterIndex As Long
    lpstrFile As String
    nMaxFile As Long
    lpstrFileTitle As String
    nMaxFileTitle As Long
    lpstrInitialDir As String
    lpstrTitle As String
    Flags As Long
    nFileOffset As Integer
    nFileExtension As Integer
    lpstrDefExt As String
    lCustData As Long
    lpfnHook As Long
    lpTemplateName As String

End Type

'Struktur f�r APIChooseColor
Private Type CHOOSECOLOR

    lStructSize As Long
    hwndOwner As Long
    hInstance As Long
    RgbResult As Long
    lpCustColors As Long
    Flags As Long
    lCustData As Long
    lpfnHook As Long
    lpTemplateName As String

End Type

'Konstanten f�r CHOOSECOLOR.flags
Private Const CC_ANYCOLOR = &H100
Private Const CC_FULLOPEN = &H2
Private Const CC_PREVENTFULLOPEN = &H4
Private Const CC_RGBINIT = &H1
Private Const CC_SOLIDCOLOR = &H80
'Konstanten f�r BROWSEINFO.ulFlags
Private Const BIF_RETURNONLYFSDIRS = 1  'nur Auswahl von Verzeichnissen erm�glichen
Private Const BIF_DONTGOBELOWDOMAIN = 2 'keine Domainenmitglieder zeigen
'Konstanten f�r FileInUse
Private Const GENERIC_READ = &H80000000
Private Const OPEN_EXISTING = 3
Private Const FILE_ATTRIBUTE_NORMAL = &H80
Private Const INVALID_HANDLE_VALUE = -1
Private Const ERROR_SHARING_VIOLATION = &H20
Private Const FORMAT_MESSAGE_FROM_SYSTEM = &H1000
Private Const OFN_ALLOWMULTISELECT = &H200
Private Const OFN_EXPLORER = &H80000 '  new look commdlg



'Type zur Parametrierung der SHBrowseForFolder
Private Type BROWSEINFO

    hwndOwner      As Long
    pIDLRoot       As Long
    pszDisplayName As Long
    lpszTitle      As String
    ulFlags        As Long
    lpfnCallback   As Long
    lParam         As Long
    iImage         As Long

End Type

'Verwendete APIs
Private Declare Function APIChooseColor _
                Lib "comdlg32.dll" _
                Alias "ChooseColorA" (pCHOOSECOLOR As CHOOSECOLOR) As Long
Private Declare Function APIGetOpenFileName _
                Lib "comdlg32.dll" _
                Alias "GetOpenFileNameA" (pOpenfilename As OpenFilename) As Long
Private Declare Function APIGetSaveFileName _
                Lib "comdlg32.dll" _
                Alias "GetSaveFileNameA" (pOpenfilename As OpenFilename) As Long
Private Declare Function SHBrowseForFolder Lib "shell32" (lpbi As BROWSEINFO) As Long
Private Declare Function SHGetPathFromIDList _
                Lib "shell32" (ByVal pidList As Long, _
                               ByVal lpBuffer As String) As Long
'Verwendete APIs f�r FileInUse
Private Declare Function CreateFile _
                Lib "kernel32" _
                Alias "CreateFileA" (ByVal lpFileName As String, _
                                     ByVal dwDesiredAccess As Long, _
                                     ByVal dwShareMode As Long, _
                                     ByVal lpSecurityAttributes As Long, _
                                     ByVal dwCreationDisposition As Long, _
                                     ByVal dwFlagsAndAttributes As Long, _
                                     ByVal hTemplateFile As Long) As Long
Private Declare Function CloseHandle Lib "kernel32" (ByVal hObject As Long) As Long
Private Declare Function FormatMessage _
                Lib "kernel32" _
                Alias "FormatMessageA" (ByVal dwFlags As Long, _
                                        ByVal lpSource As Long, _
                                        ByVal dwMessageId As Long, _
                                        ByVal dwLanguageId As Long, _
                                        ByVal lpBuffer As String, _
                                        nSize As Long, _
                                        Arguments As Long) As Long

'**************************************************************************************************
'Datei �ffnen- und Speichern-Dialoge
'**************************************************************************************************
Public Function GetOpenFileName(ByVal initialPath As String, _
                                ByVal filename As String, _
                                ByVal FileTypes As String, _
                                Optional ByVal title As String, _
                                Optional ByVal hwndOwner As Long) As String
    GetOpenFileName = GetFileName(enumOpenFileName, initialPath, filename, FileTypes, title, hwndOwner)
End Function

Public Function GetOpenFileNamesEx(ByVal strInitialPath As String, _
                                  ByVal strFileName As String, _
                                  ByVal strFileTypes As String, _
                                  Optional ByVal strDialogTitle As String, _
                                  Optional ByVal hwndOwner As Long) As String
    Dim fso
    Dim Temp As String

    On Error GoTo Fehler

    '{Auf das richtige Trennzeichen setzen}
    strFileTypes = Replace(strFileTypes, ".", "")
    strFileTypes = Replace(strFileTypes, ",", ";")
    strFileTypes = Replace(strFileTypes, " ", ";")
    strFileTypes = Replace(strFileTypes, "#", ";")
    GetOpenFileNamesEx = ""
    Temp = strFileName
    strFileName = GetFileName(enumOpenFileName, strInitialPath, strFileName, strFileTypes, strDialogTitle, hwndOwner, True)

    If Temp = strFileName Then   '{Abbrechen wurde gew�hlt}
        Exit Function
    End If

'    Set fso = CreateObject("Scripting.FileSystemObject")
'
'    'Pr�fen ob Datei bereits existiert
'    If Not fso.FileExists(strFileName) Then
'        MsgBox "Datei '" & strFileName & "' existiert nicht!", 48, "Datei nicht vorhanden"
'
'        Exit Function
'
'    End If
'
'    If FileInUse(strFileName) Then
'        MsgBox "Datei '" & strFileName & "' gerade in Benutzung." & Chr$(13) & "Die Datei kann nicht ge�ffnet werden", 48, "Datei in Benutzung"
'
'        Exit Function
'
'    End If

    GetOpenFileNamesEx = strFileName

    Exit Function

Fehler:
    MsgBox "(" & Err.number & ") " & Err.description, 16, "Fehler"
    Exit Function
End Function


Public Function GetOpenFileNameEx(ByVal strInitialPath As String, _
                                  ByVal strFileName As String, _
                                  ByVal strFileTypes As String, _
                                  Optional ByVal strDialogTitle As String, _
                                  Optional ByVal hwndOwner As Long) As String
    Dim fso
    Dim Temp As String

    On Error GoTo Fehler

    '{Auf das richtige Trennzeichen setzen}
    strFileTypes = Replace(strFileTypes, ".", "")
    strFileTypes = Replace(strFileTypes, ",", ";")
    strFileTypes = Replace(strFileTypes, " ", ";")
    strFileTypes = Replace(strFileTypes, "#", ";")
    GetOpenFileNameEx = ""
    Temp = strFileName
    strFileName = GetFileName(enumOpenFileName, strInitialPath, strFileName, strFileTypes, strDialogTitle, hwndOwner)

    If Temp = strFileName Then   '{Abbrechen wurde gew�hlt}
        Exit Function
    End If

    Set fso = CreateObject("Scripting.FileSystemObject")

    'Pr�fen ob Datei bereits existiert
    If Not fso.FileExists(strFileName) Then
        MsgBox "Datei '" & strFileName & "' existiert nicht!", 48, "Datei nicht vorhanden"

        Exit Function

    End If

    If FileInUse(strFileName) Then
        MsgBox "Datei '" & strFileName & "' gerade in Benutzung." & Chr$(13) & "Die Datei kann nicht ge�ffnet werden", 48, "Datei in Benutzung"

        Exit Function

    End If

    GetOpenFileNameEx = strFileName

    Exit Function

Fehler:
    MsgBox "(" & Err.number & ") " & Err.description, 16, "Fehler"

    Exit Function

End Function

Public Function GetSaveFileName(ByVal initialPath As String, _
                                ByVal filename As String, _
                                ByVal FileTypes As String, _
                                Optional ByVal title As String, _
                                Optional ByVal hwndOwner As Long) As String
    GetSaveFileName = GetFileName(enumSaveFileName, initialPath, filename, FileTypes, title, hwndOwner)
End Function

Private Function GetErrorMessage(ByVal lngMessageID As Long) As String
    '====================================================================================
    '2000-08-23, Klaus Prinz
    '   Fehlertext ermitteln
    '------------------------------------------------------------------------------------
    'Argumente:
    '   lngMessageID:  FehlerCode in System Message Table
    '====================================================================================
    Dim strError  As String * 256    'Fehlertext
    Dim lngResult As Long           'R�ckgabe
    Dim nSize     As Long               'L�nge von strError [IN]

    On Error GoTo errHandler

    nSize = 256
    lngResult = FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, 0, lngMessageID, 0, strError, nSize, 0)

    If lngResult = 0 Then
        Err.Raise 9999
    Else
        GetErrorMessage = Left$(strError, lngResult - 1)
    End If

    Exit Function

errHandler:
    Err.Raise 9999, , "Der Fehlertext zu ReturnCode " & lngResult & " konnte nicht ermittelt werden."
End Function

Private Property Get FileInUse(ByVal strFile As String) As Boolean
    '====================================================================================
    '2000-09-18, Klaus Prinz
    '   Pr�fen, ob �bergebene Datei bereits ge�ffnet ist
    '------------------------------------------------------------------------------------
    'Argumente:
    '   strFile:    zu pr�fende Datei
    '====================================================================================
    Dim hFile    As Long               'Datei-Handle
    Dim lngError As Long            'Fehler-Code

    On Error GoTo errHandler

    hFile = CreateFile(strFile, GENERIC_READ, 0, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)

    If hFile = INVALID_HANDLE_VALUE Then
        lngError = Err.LastDllError

        If lngError = ERROR_SHARING_VIOLATION Then
            FileInUse = True
        Else
            Err.Raise 10000 + lngError, , GetErrorMessage(lngError)
        End If

    Else
        CloseHandle hFile
    End If

    Exit Property

errHandler:

    If hFile = INVALID_HANDLE_VALUE Then CloseHandle hFile
    Err.Raise Err.number, "clsFiles:FileInUse"
End Property

Public Function GetSaveFileNamesEx(ByVal strInitialPath As String, _
                                  ByVal strFileName As String, _
                                  ByVal strFileTypes As String, _
                                  Optional ByVal strDefaultExt As String = "", _
                                  Optional ByVal strDialogTitle As String, _
                                  Optional ByVal hwndOwner As Long) As String
    Dim astrFileTypes() As String
    Dim Temp            As String
    Dim fso             As Object
    Dim aFile           As Object

    On Error GoTo Fehler

    '{Auf das richtige Trennzeichen setzen}
    strFileTypes = Replace(strFileTypes, ".", "")
    strFileTypes = Replace(strFileTypes, ",", ";")
    strFileTypes = Replace(strFileTypes, " ", ";")
    strFileTypes = Replace(strFileTypes, "#", ";")

    '{Wurde Standarderweiterung angegeben}
    If strDefaultExt = "" Then
        '{Setze Standarderweiterung auf die erste Ext von strFileTypes}
        astrFileTypes = Split(strFileTypes, ";")
        strDefaultExt = astrFileTypes(0)
    Else
        '{Entferne ggf. den Punkt und *}
        strDefaultExt = Replace(strDefaultExt, ".", "")
    End If

    GetSaveFileNamesEx = ""
    Temp = GetFileName(enumSaveFileName, strInitialPath, strFileName, strFileTypes, strDialogTitle, hwndOwner, True)

    'Pr�fen ob Cancel gew�hlt wurde
    If strFileName = Temp Then Exit Function
    strFileName = Temp
    Set fso = CreateObject("Scripting.FileSystemObject")

    '{Defaulterweiterung anh�ngen}
    If fso.GetExtensionName(strFileName) = "" Then
        strFileName = strFileName & "." & strDefaultExt
    End If

    GetSaveFileNamesEx = strFileName

    Exit Function

Fehler:
    MsgBox "(" & Err.number & ") " & Err.description, 16, "Fehler"
    Exit Function
End Function

Public Function GetSaveFileNameEx(ByVal strInitialPath As String, _
                                  ByVal strFileName As String, _
                                  ByVal strFileTypes As String, _
                                  Optional ByVal strDefaultExt As String = "", _
                                  Optional ByVal strDialogTitle As String, _
                                  Optional ByVal hwndOwner As Long) As String
    Dim astrFileTypes() As String
    Dim Temp            As String
    Dim fso             As Object
    Dim aFile           As Object

    On Error GoTo Fehler

    '{Auf das richtige Trennzeichen setzen}
    strFileTypes = Replace(strFileTypes, ".", "")
    strFileTypes = Replace(strFileTypes, ",", ";")
    strFileTypes = Replace(strFileTypes, " ", ";")
    strFileTypes = Replace(strFileTypes, "#", ";")

    '{Wurde Standarderweiterung angegeben}
    If strDefaultExt = "" Then
        '{Setze Standarderweiterung auf die erste Ext von strFileTypes}
        astrFileTypes = Split(strFileTypes, ";")
        strDefaultExt = astrFileTypes(0)
    Else
        '{Entferne ggf. den Punkt und *}
        strDefaultExt = Replace(strDefaultExt, ".", "")
    End If

    GetSaveFileNameEx = ""
    Temp = GetFileName(enumSaveFileName, strInitialPath, strFileName, strFileTypes, strDialogTitle, hwndOwner)

    'Pr�fen ob Cancel gew�hlt wurde
    If strFileName = Temp Then Exit Function
    strFileName = Temp
    Set fso = CreateObject("Scripting.FileSystemObject")

    '{Defaulterweiterung anh�ngen}
    If fso.GetExtensionName(strFileName) = "" Then
        strFileName = strFileName & "." & strDefaultExt
    End If

    'Pr�fen ob Datei bereits existiert
    If fso.FileExists(strFileName) Then

        '{Fragen ob �berschrieben werden soll}
        If MsgBox("Datei existiert bereits!" & Chr$(13) & "Soll bestehende Datei '" & strFileName & "' �berschrieben werden?", 36, "Datei vorhanden") = vbNo Then Exit Function

        '{Pr�fen ob Datei in Gebrauch}
        If FileInUse(strFileName) Then
            MsgBox "Datei '" & strFileName & "' gerade in Benutzung." & Chr$(13) & "Die Datei kann nicht gespeichert werden", 48, "Datei in Benutzung"

            Exit Function

        End If

        '{Pr�fen ob Datei schreibgesch�tzt}
        Set aFile = fso.GetFile(strFileName)

        '{Schreibschutz �berpr�fen               }
        '{Schreibschutz hat den Wert 1           }
        '{Wenn Attributes ungerade dann entfernen}
        Select Case aFile.Attributes Mod 2

            Case 1 '{Schreibschutz}

                If MsgBox("Die Datei '" & strFileName & "' ist schreibgesch�tzt." & Chr$(13) & "Soll der Schreibschutz entfernt werden?", 36, "Datei schreibgesch�tzt") = vbNo Then Exit Function
                aFile.Attributes = aFile.Attributes - 1
        End Select

    End If

    GetSaveFileNameEx = strFileName

    Exit Function

Fehler:
    MsgBox "(" & Err.number & ") " & Err.description, 16, "Fehler"

    Exit Function

End Function

Private Function GetFileName(ByVal lngMode As enumSaveOpenFileName, _
                             ByVal strInitialPath As String, _
                             ByVal strFileName As String, _
                             ByVal strFileTypes As String, _
                             Optional ByVal strTitle As String, _
                             Optional ByVal hwndOwner As Long, _
                             Optional ByVal MultiSelect As Boolean = False) As String
    '====================================================================================
    '2000-04-20, Klaus Prinz
    '   GetOpenFileName- oder GetSaveFileName-Dialog erzeugen und Auswahl zur�ckgeben
    '------------------------------------------------------------------------------------
    'Argumente:
    '   lngMode:            Modus (Datei �ffnen oder Speichern)
    '   strInitialPath:     Startverzeichnis
    '   strFileName:        vorgeschlagener Dateiname
    '   strFileTypes:       Dateitypen, Semikolon-getrennt (z.B. "xls" oder "doc;txt")
    '   strTitle:           Dialogtitel, wenn "", dann wird "�ffnen" angezeigt
    '   hWndOwner:          Handle des Owner-Fensters
    '------------------------------------------------------------------------------------
    'R�ckgabe:              vollst�ndiger Name der ausgew�hlten Datei oder "" bei Abbruch
    '====================================================================================
    Dim OpenFile As OpenFilename    'Datenstruktur f�r APIGetOpenFileName

    On Error GoTo errHandler

    OpenFile.hwndOwner = hwndOwner
    OpenFile.lStructSize = Len(OpenFile)
    OpenFile.lpstrFilter = ComposeFileFilter(strFileTypes)
    OpenFile.nFilterIndex = 1
    OpenFile.lpstrFile = strFileName & String$(260 - Len(strFileName), 0)
    OpenFile.nMaxFile = Len(OpenFile.lpstrFile) - 1
    OpenFile.lpstrFileTitle = OpenFile.lpstrFile
    OpenFile.nMaxFileTitle = OpenFile.nMaxFile
    OpenFile.lpstrInitialDir = strInitialPath

    If MultiSelect Then
        OpenFile.Flags = OpenFile.Flags Or OFN_EXPLORER Or OFN_ALLOWMULTISELECT
    End If

    If strTitle <> "" Then
      OpenFile.lpstrTitle = strTitle
    End If

    If lngMode = enumOpenFileName Then
      APIGetOpenFileName OpenFile
    Else
      APIGetSaveFileName OpenFile
    End If


    Dim ar As Variant
    ar = Split(OpenFile.lpstrFile, Chr$(0))

    If MultiSelect Then
      GetFileName = ClearAPIStringMultiSelect(OpenFile.lpstrFile)
    Else
      GetFileName = ClearAPIString(OpenFile.lpstrFile)
    End If
    Exit Function

errHandler:

    If InStr(1, Err.source, ":") = 0 Then Err.source = "cSysDialogs:GetOpenFileName"
    Err.Raise Err.number
End Function

Private Function ClearAPIStringMultiSelect(ByVal strAPIString As String) As String
    
    Dim ar As Variant
    ar = Split(strAPIString, Chr$(0))
    
    Dim Data As Collection: Set Data = New Collection
    Dim files As String
    Dim i As Integer
    For i = 1 To UBound(ar)
      If Trim(ar(i)) <> "" Then
        Data.Add CStr(Trim(ar(0))) & CStr(Trim(ar(i)))
      End If
    Next i
    
    If Data.count = 0 Then
      ClearAPIStringMultiSelect = ClearAPIString(strAPIString)
    Else
      Dim conv As Convert: Set conv = New Convert
      ClearAPIStringMultiSelect = conv.JoinCollection(Data, "|")
      Set conv = Nothing
    End If
End Function

Private Function ClearAPIString(ByVal strAPIString As String) As String

    '====================================================================================
    '2000-04-20, Klaus Prinz
    '   �bergebenen String bis vor ersten Chr$(0) abschneiden
    '------------------------------------------------------------------------------------
    'Argumente:
    '   strAPIString:   API-String
    '====================================================================================
    On Error GoTo errHandler

    If InStr(1, strAPIString, Chr$(0)) > 0 Then
        ClearAPIString = Left$(strAPIString, InStr(1, strAPIString, Chr$(0)) - 1)
    Else
        ClearAPIString = strAPIString
    End If

    Exit Function

errHandler:
    Err.Raise Err.number, "cSysDialogs:ClearAPIString"
End Function

Private Function ComposeFileFilter(ByVal strExtensions As String) As String
    '====================================================================================
    '2000-04-20, Klaus Prinz
    '   Filterausdruck f�r OPENFILENAME.lpstrFilter zusammenstellen
    '------------------------------------------------------------------------------------
    'Argumente:
    '   strExtension:   Dateierweiterungen, Semikolon-getrennt
    '====================================================================================
    Dim strExt() As String          'Array zur Aufnahme der �bergebenen Dateierweiterungen
    Dim iExt     As Long                'Zeiger in strExt()

    On Error GoTo errHandler

    If strExtensions = "" Then
        ComposeFileFilter = ""
    Else
        strExt = Split(strExtensions, ";")

        For iExt = 0 To UBound(strExt)

            If InStr(1, strExt(iExt), ".") = 0 Then
                'nur Dateierweiterung, z. B. "xml"
                ComposeFileFilter = ComposeFileFilter & cSysReg.ExtensionToFileType(strExt(iExt)) & " (*." & strExt(iExt) & ")" & Chr$(0) & "*." & strExt(iExt) & Chr$(0)
            Else
                'Dateimaske, z. B. "Import*.xml"
                ComposeFileFilter = ComposeFileFilter & strExt(iExt) & Chr$(0) & strExt(iExt) & Chr$(0)
            End If

        Next

    End If

    If UBound(strExt) > 0 Then
        'mit einem weiteren NULL anschlie�en, wenn mehrere Einzelfilter
        ComposeFileFilter = ComposeFileFilter & Chr$(0)
    End If

    Exit Function

errHandler:

    If InStr(1, Err.source, ":") = 0 Then Err.source = "cSysDialogs:ComposeFileFilter"
    Err.Raise Err.number
End Function

'**************************************************************************************************
'Verzeichnisdialog
'**************************************************************************************************
Public Function GetPath(Optional ByVal hwndOwner As Long) As String
    '====================================================================================
    '2000-02-24, Klaus Prinz
    '   Verzeichnis ermitteln und zur�ckgeben
    '------------------------------------------------------------------------------------
    'Argumente:
    '   hWndOwner:   Handle des aufrufenden Fensters
    '------------------------------------------------------------------------------------
    'R�ckgabe:       vollst�ndiger Name des ausgew�hlten Verzeichnisse oder "" bei Abbruch
    '====================================================================================
    Dim lngIDList   As Long       'Zeiger auf das ausgesuchte Verzeichnis
    Dim strTitle    As String      'Titel des Dialogs
    Dim tBrowseInfo As BROWSEINFO

    On Error GoTo errHandler

    tBrowseInfo.hwndOwner = hwndOwner
    strTitle = "Bitte w�hlen Sie ein Verzeichnis aus"
    tBrowseInfo.lpszTitle = strTitle
    tBrowseInfo.ulFlags = BIF_RETURNONLYFSDIRS + BIF_DONTGOBELOWDOMAIN
    lngIDList = SHBrowseForFolder(tBrowseInfo)

    If lngIDList <> 0 Then
        GetPath = Space$(260)
        SHGetPathFromIDList lngIDList, GetPath
        GetPath = Left$(GetPath, InStr(GetPath, vbNullChar) - 1)
    End If

    Exit Function

errHandler:
    Err.Raise Err.number + vbObjectError, "clsRegistry:GetPath"
End Function

'**************************************************************************************************
'Farbdialog
'**************************************************************************************************
Public Property Let CustomizedColor(ByVal Index As Long, ByVal NewColor As Long)

    If Index < 1 Or Index > 16 Then
        Err.Raise 9, "Der Index muss zwischen 1 und 16 liegen."
    End If

    lngCustColors(Index - 1) = NewColor
End Property

Public Property Get CustomizedColor(ByVal Index As Long) As Long

    If Index < 1 Or Index > 16 Then
        Err.Raise 9, "Der Index muss zwischen 1 und 16 liegen."
    End If

    CustomizedColor = lngCustColors(Index - 1)
End Property

Public Function GetColor(Optional InitColor As Long = -1, _
                         Optional ByVal hwndOwner As Long) As Long
    '====================================================================================
    '2000-02-24, Klaus Prinz
    '   Farbdialog anzeigen und ausgew�hlte Farbe zur�ckgeben
    '------------------------------------------------------------------------------------
    'Argumente:
    '   Initcolor:   Initalisierungsfarbe oder -1 f�r keine Initialisierung
    '   hWndOwner:      Handle des aufrufenden Fensters
    '------------------------------------------------------------------------------------
    'R�ckgabe:          RGB-Farbe oder -1, wenn Dialog �ber Abbrechen geschlossen wurde
    '====================================================================================
    Dim tChooseColor As CHOOSECOLOR 'Datenstruktur f�r APIChooseColor
    Dim lngReturn    As Long           'R�ckgabe aus Funktion

    On Error GoTo errHandler

    tChooseColor.lStructSize = Len(tChooseColor)
    tChooseColor.hwndOwner = hwndOwner
    tChooseColor.lpCustColors = VarPtr(lngCustColors(0))

    If InitColor = -1 Then
        tChooseColor.Flags = CC_SOLIDCOLOR + CC_FULLOPEN
    Else
        tChooseColor.Flags = CC_SOLIDCOLOR + CC_FULLOPEN + CC_RGBINIT
        tChooseColor.RgbResult = InitColor
    End If

    lngReturn = APIChooseColor(tChooseColor)

    If lngReturn = 0 Then
        GetColor = -1
    Else
        GetColor = tChooseColor.RgbResult
    End If

    Exit Function

errHandler:

    If InStr(1, Err.source, ":") = 0 Then Err.source = "cSysDialogs:GetColor"
    Err.Raise Err.number
End Function


