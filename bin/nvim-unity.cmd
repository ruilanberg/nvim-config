@echo off
rem Ponte para o pacote com.maneuver.nvim: Unity > Preferences > Vim > Vim Client Path = este arquivo
start "" /b pwsh -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0nvim-unity.ps1" %*
