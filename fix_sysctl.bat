@echo off
REM Скрипт для автоматического исправления sysctl.conf в Windows
REM Использование: скопируй sysctl.conf в папку со скриптом и запусти fix_sysctl.bat

echo ==========================================
echo Исправление sysctl.conf
echo ==========================================
echo.

if not exist sysctl.conf (
    echo ОШИБКА: Файл sysctl.conf не найден!
    echo Скопируй файл /etc/sysctl.conf с eMMC в эту папку
    pause
    exit /b 1
)

echo Создание резервной копии...
copy sysctl.conf sysctl.conf.backup >nul
echo Резервная копия создана: sysctl.conf.backup
echo.

echo Удаление проблемных параметров...
powershell -Command "(Get-Content sysctl.conf) | Where-Object { $_ -notmatch 'Оптимизация для аудио пайплайна' -and $_ -notmatch 'net\.core\.' -and $_ -notmatch 'net\.ipv4\.tcp\.' -and $_ -notmatch 'Оптимизация для реального времени' -and $_ -notmatch 'kernel\.sched_rt_' -and $_ -notmatch 'kernel\.sched_migration' -and $_ -notmatch '^vm\.swappiness=1' -and $_ -notmatch '^vm\.dirty_ratio=10' -and $_ -notmatch '^vm\.dirty_background_ratio=5' } | Set-Content sysctl.conf.fixed"

if exist sysctl.conf.fixed (
    move /Y sysctl.conf.fixed sysctl.conf >nul
    echo Файл исправлен!
    echo.
    echo Теперь скопируй исправленный sysctl.conf обратно на eMMC
) else (
    echo ОШИБКА: Не удалось исправить файл
)

echo.
pause

