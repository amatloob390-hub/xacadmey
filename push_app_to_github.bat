@echo off
title Xacademy App - GitHub Push
cd /d "C:\dev\xacademy\build\web"
echo ============================================================
echo   App ko GitHub par bhej rahe hain...
echo   Agar GitHub sign-in window khule to sign IN / Authorize karein.
echo ============================================================
echo.
git push -u origin main --force
echo.
echo ============================================================
echo   Agar upar "main -^> main" ya "branch 'main' set up" likha hai
echo   to KAMYAB. Ab is window ko band kar dein.
echo ============================================================
pause
