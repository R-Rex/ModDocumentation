@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =========================
REM CONFIG
REM =========================
set "OWNER=R-Rex"
set "REPO=ModDocumentation"
set "BRANCH=main"
set "REMOTE_PATH=Mods"
set "API_URL=https://api.github.com/repos/%OWNER%/%REPO%/contents/%REMOTE_PATH%?ref=%BRANCH%"

REM =========================
REM VERIFS
REM =========================
where curl >nul 2>nul
if errorlevel 1 (
    echo Erreur : curl n'est pas disponible sur ce Windows.
    pause
    exit /b 1
)

set "TMP_JSON=%temp%\github_mods_%random%.json"
set "TMP_LIST=%temp%\github_mods_%random%.txt"

if exist "%TMP_JSON%" del /f /q "%TMP_JSON%" >nul 2>nul
if exist "%TMP_LIST%" del /f /q "%TMP_LIST%" >nul 2>nul

REM =========================
REM RECUP JSON GITHUB
REM =========================
echo Recuperation de la liste des mods depuis GitHub...
curl --globoff -L -s "%API_URL%" -o "%TMP_JSON%"

if not exist "%TMP_JSON%" (
    echo Erreur : impossible de recuperer la liste GitHub.
    pause
    exit /b 1
)

findstr /i "\"name\"" "%TMP_JSON%" >nul
if errorlevel 1 (
    echo Erreur : reponse GitHub invalide ou dossier introuvable.
    echo Verifie OWNER / REPO / BRANCH / REMOTE_PATH
    del /f /q "%TMP_JSON%" >nul 2>nul
    pause
    exit /b 1
)

REM =========================
REM EXTRACTION DES NOMS .jar
REM =========================
for /f "tokens=2 delims=:" %%A in ('findstr /i "\"name\"" "%TMP_JSON%"') do (
    set "LINE=%%A"
    if defined LINE (
        set "LINE=!LINE:,=!"
        set "LINE=!LINE:"=!"
        call :Trim LINE
        if /I "!LINE:~-4!"==".jar" (
            >>"%TMP_LIST%" echo(!LINE!
        )
    )
)

if not exist "%TMP_LIST%" (
    echo Aucun fichier .jar trouve dans le dossier GitHub "%REMOTE_PATH%".
    del /f /q "%TMP_JSON%" >nul 2>nul
    pause
    exit /b 1
)

REM =========================
REM TELECHARGEMENT DES MANQUANTS
REM =========================
echo.
echo ===== TELECHARGEMENT DES MODS MANQUANTS =====
for /f "usebackq delims=" %%F in ("%TMP_LIST%") do (
    set "FN=%%F"
    call :Trim FN

    if exist "!FN!" (
        echo [OK] !FN! deja present
    ) else (
        set "FILE_URL=https://raw.githubusercontent.com/%OWNER%/%REPO%/%BRANCH%/%REMOTE_PATH%/!FN!"
        set "FILE_URL=!FILE_URL: =%%20!"
        echo [DL] !FN!
        curl --globoff -L --fail -o "!FN!" "!FILE_URL!"
        if exist "!FN!" (
            echo [OK] !FN! telecharge
        ) else (
            echo [ERREUR] Echec du telechargement de !FN!
        )
    )
)

REM =========================
REM SUPPRESSION DES LOCAUX ABSENTS DE GITHUB
REM =========================
echo.
echo ===== SUPPRESSION DES MODS ABSENTS DU GITHUB =====
for %%L in (*.jar) do (
    set "LOCAL_FILE=%%L"
    call :Trim LOCAL_FILE

    findstr /i /x /c:"!LOCAL_FILE!" "%TMP_LIST%" >nul
    if errorlevel 1 (
        echo [DEL] !LOCAL_FILE!
        del /f /q "!LOCAL_FILE!"
    ) else (
        echo [KEEP] !LOCAL_FILE!
    )
)

REM =========================
REM NETTOYAGE
REM =========================
del /f /q "%TMP_JSON%" >nul 2>nul
del /f /q "%TMP_LIST%" >nul 2>nul

echo.
echo Synchronisation terminee.
pause
exit /b

REM =========================
REM FONCTION TRIM
REM =========================
:Trim
setlocal EnableDelayedExpansion
set "s=!%~1!"
if not defined s (
    endlocal & set "%~1=" & exit /b
)
:trim_loop
if "!s:~0,1!"==" " set "s=!s:~1!" & goto trim_loop
:trim_loop_end
if "!s:~-1!"==" " set "s=!s:~0,-1!" & goto trim_loop_end
endlocal & set "%~1=%s%"
exit /b