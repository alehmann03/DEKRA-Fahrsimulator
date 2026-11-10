Option Explicit
Dim shell, fso, scriptDir, command, result
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
command = "pythonw.exe -B """ & fso.BuildPath(scriptDir, "scripts\wizard.py") & """ --standalone"
On Error Resume Next
result = shell.Run(command, 0, False)
If Err.Number <> 0 Then
  MsgBox "Der Assistent konnte nicht gestartet werden. Bitte Python 3.10 oder neuer installieren und pythonw.exe im PATH verfügbar machen.", 16, "DEKRA-Herausforderung"
End If
