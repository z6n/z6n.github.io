@echo off & setlocal enabledelayedexpansion

cd %~dp0

hugo -s=.\src -d=..  --theme=bootstrap --baseUrl="https://z6n.github.io"

pause
