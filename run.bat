@echo off & setlocal enabledelayedexpansion

cd %~dp0

hugo -s=.\src   server --theme=bootstrap
