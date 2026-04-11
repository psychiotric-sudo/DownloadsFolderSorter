Set WshShell = CreateObject("WScript.Shell")
' Executing the intent-revealing PowerShell engine silently
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%USERPROFILE%\Documents\DownloadsFolderSorter\bin\Sort-DownloadsFolder.ps1""", 0, False