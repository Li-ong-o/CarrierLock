@echo off
chcp 65001 >nul
title CarrierLock - Windows 运营商配置锁定助手
cd /d "%~dp0\windows"

set "PYTHON_EXE=C:\Users\抹茶星冰乐\AppData\Local\Programs\Python\Python311\pythonw.exe"
if not exist "%PYTHON_EXE%" (
    set "PYTHON_EXE=pythonw.exe"
)

start "" "%PYTHON_EXE%" gui.py
