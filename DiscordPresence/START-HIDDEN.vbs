' Discord Presence - Hidden Startup Script
' Jalankan Discord Presence tanpa menampilkan console window

Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

' Check if node_modules exists, if not install
If Not CreateObject("Scripting.FileSystemObject").FolderExists("node_modules") Then
    WshShell.Run "cmd /c npm install", 0, True
End If

' Run node in hidden mode
WshShell.Run "node presence.js", 0, False
