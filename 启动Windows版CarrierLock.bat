@echo off
chcp 65001 >nul
title CarrierLock - Windows 运营商配置锁定助手
cd /d "%~dp0"

if exist "%~dp0CarrierLock_v1.0.4.exe" (
    start "" "%~dp0CarrierLock_v1.0.4.exe"
    exit /b
)

if exist "%~dp0CarrierLock.exe" (
    start "" "%~dp0CarrierLock.exe"
    exit /b
)

set "PYTHON_EXE=C:\Users\抹茶星冰乐\AppData\Local\Programs\Python\Python311\pythonw.exe"
if not exist "%PYTHON_EXE%" (
    set "PYTHON_EXE=pythonw.exe"
)
start "" "%PYTHON_EXE%" "%~dp0windows\gui.py"
