Set ws = CreateObject("Wscript.Shell")
ws.run "PowerShell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File SP_Monitor_UI.ps1", 0