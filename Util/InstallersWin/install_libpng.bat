@echo off
setlocal

rem BAT script that downloads and installs a ready to use
rem x64 libpng build for CARLA (carla.org).
rem Run it through a cmd with the x64 Visual C++ Toolset enabled.

set LOCAL_PATH=%~dp0
set FILE_N=    -[%~n0]:

rem Print batch params (debug purpose)
echo %FILE_N% [Batch params]: %*

rem ============================================================================
rem -- Parse arguments ---------------------------------------------------------
rem ============================================================================

:arg-parse
if not "%1"=="" (
    rem 判断第一个参数是否为 --build-dir
    if "%1"=="--build-dir" (
        rem 如果是 --build-dir，设置 BUILD_DIR 变量为第二个参数代表的路径相关内容（含盘符、路径、文件名）
        set BUILD_DIR=%~dpn2
        rem 将命令行参数向左移动一位，为处理后续参数做准备
        shift
    )
    rem 判断第一个参数是否为 --zlib-install-dir
    if "%1"=="--zlib-install-dir" (
        rem 如果是 --zlib-install-dir，设置 ZLIB_INST_DIR 变量为第二个参数代表的路径相关内容（含盘符、路径、文件名）
        set ZLIB_INST_DIR=%~dpn2
        rem 将命令行参数向左移动一位，为处理后续参数做准备
        shift
    )
    rem 判断第一个参数是否为 -h（短格式帮助参数）
    if "%1"=="-h" (
        rem 如果是 -h，跳转到 help 标签处显示帮助信息
        goto help
    )
    rem 判断第一个参数是否为 --help（长格式帮助参数）
    if "%1"=="--help" (
        rem 如果是 --help，跳转到 help 标签处显示帮助信息
        goto help
    )
    rem 将命令行参数向左移动一位，为处理后续参数做准备
    shift
    rem 跳转到 :arg-parse 标签处，继续解析下一组参数
    goto :arg-parse
)

:: 这里判断环境变量%ZLIB_INST_DIR%是否为空字符串，如果为空，则进入下面的代码块执行相应操作。
if "%ZLIB_INST_DIR%" == "" (
    echo %FILE_N% You must specify a zlib install directory using [--zlib-install-dir]
    goto bad_exit
)
if not "%ZLIB_INST_DIR:~-1%"=="\" set ZLIB_INST_DIR=%ZLIB_INST_DIR%\

rem If not set set the build dir to the current dir
if "%BUILD_DIR%" == "" set BUILD_DIR=%~dp0
if not "%BUILD_DIR:~-1%"=="\" set BUILD_DIR=%BUILD_DIR%\

rem ============================================================================
rem -- Local Variables ---------------------------------------------------------
rem ============================================================================

set LIBPNG_BASENAME=libpng
set LIBPNG_VERSION=1.2.37

rem libpng-x.x.x
set LIBPNG_TEMP_FOLDER=%LIBPNG_BASENAME%-%LIBPNG_VERSION%
rem libpng-x.x.x-src.zip
set LIBPNG_TEMP_FILE=%LIBPNG_TEMP_FOLDER%-src.zip
rem ../libpng-x.x.x-src.zip
set LIBPNG_TEMP_FILE_DIR=%BUILD_DIR%%LIBPNG_TEMP_FILE%

set LIBPNG_REPO=http://downloads.sourceforge.net/gnuwin32/libpng-%LIBPNG_VERSION%-src.zip

rem ../libpng-x.x.x-source/
set LIBPNG_SRC_DIR=%BUILD_DIR%%LIBPNG_BASENAME%-%LIBPNG_VERSION%-source\
rem ../libpng-x.x.x-install/
set LIBPNG_INSTALL_DIR=%BUILD_DIR%%LIBPNG_BASENAME%-%LIBPNG_VERSION%-install\

rem ============================================================================
rem -- Get libpng --------------------------------------------------------------
rem ============================================================================

if exist "%LIBPNG_INSTALL_DIR%" (
    goto already_build
)

if not exist "%LIBPNG_SRC_DIR%" (
    if not exist "%LIBPNG_TEMP_FILE_DIR%" (
        echo %FILE_N% Retrieving %LIBPNG_BASENAME%.
        powershell -Command "(New-Object System.Net.WebClient).DownloadFile('%LIBPNG_REPO%', '%LIBPNG_TEMP_FILE_DIR%')"
    )
    if not exist "%LIBPNG_TEMP_FILE_DIR%" (
        echo %FILE_N% Using %LIBPNG_BASENAME% from backup.
        powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://carla-releases.s3.us-east-005.backblazeb2.com/Backup/libpng-%LIBPNG_VERSION%-src.zip', '%LIBPNG_TEMP_FILE_DIR%')"
    )
    if %errorlevel% neq 0 goto error_download
    rem Extract the downloaded library
    echo %FILE_N% Extracting libpng from "%LIBPNG_TEMP_FILE%".
    powershell -Command "Expand-Archive '%LIBPNG_TEMP_FILE_DIR%' -DestinationPath '%BUILD_DIR%'"
    if %errorlevel% neq 0 goto error_extracting

    rem Remove unnecessary files and folders
    echo %FILE_N% Removing "%LIBPNG_TEMP_FILE%"
    del "%LIBPNG_TEMP_FILE_DIR%"
    echo %FILE_N% Removing dir "%BUILD_DIR%manifest"
    rmdir /s/q "%BUILD_DIR%manifest"

    rename "%BUILD_DIR%src" "%LIBPNG_BASENAME%-%LIBPNG_VERSION%-source"
) else (
    echo %FILE_N% Not downloading libpng because already exists the folder "%LIBPNG_SRC_DIR%".
)

rem ============================================================================
rem -- Compile libpng ----------------------------------------------------------
rem ============================================================================

#设置一个环境变量LIBPNG_SOURCE_DIR
set LIBPNG_SOURCE_DIR=%LIBPNG_SRC_DIR%libpng\%LIBPNG_VERSION%\libpng-%LIBPNG_VERSION%-src\

#条件判断语句，检查指定的路径是否不存在
if not exist "%LIBPNG_SRC_DIR%build" (
    echo %FILE_N% Creating "%LIBPNG_SRC_DIR%build"
    mkdir "%LIBPNG_SRC_DIR%build"
)

#切换到%LIBPNG_SRC_DIR%build这个目录
cd "%LIBPNG_SRC_DIR%build"

#构建脚本
cl /nologo /c /O2 /MD /Z7 /EHsc /MP /W2 /TP /GR /Gm-^
 #在Windows平台下进行条件编译
 -DWIN32 -DNDEBUG -D_CRT_SECURE_NO_WARNINGS -DPNG_NO_MMX_CODE^
 #头文件的搜索路径
 /I"%ZLIB_INST_DIR%include"^
 #指定要编译的源文件路径
 "%LIBPNG_SOURCE_DIR%*.c"

#用于检查%LIBPNG_INSTALL_DIR%lib这个目录是否存在
if not exist "%LIBPNG_INSTALL_DIR%lib" (
    echo %FILE_N% Creating "%LIBPNG_INSTALL_DIR%lib"
    mkdir "%LIBPNG_INSTALL_DIR%lib"
)

#如果不存在
if not exist "%LIBPNG_INSTALL_DIR%include" (
    echo %FILE_N% Creating "%LIBPNG_INSTALL_DIR%include"
    mkdir "%LIBPNG_INSTALL_DIR%include"
)

#一个预定义的环境变量，表示libpng的安装目录
lib /nologo /MACHINE:X64 /LTCG /OUT:"%LIBPNG_INSTALL_DIR%lib\libpng.lib"^
#指定搜索库文件的路径
 /LIBPATH:"%ZLIB_INST_DIR%lib" "*.obj" "zlibstatic.lib"

#文件复制操作
copy "%LIBPNG_SOURCE_DIR%png.h" "%LIBPNG_INSTALL_DIR%include\png.h"
copy "%LIBPNG_SOURCE_DIR%pngconf.h" "%LIBPNG_INSTALL_DIR%include\pngconf.h"

goto success

rem ============================================================================
rem -- Messages and Errors -----------------------------------------------------
rem ============================================================================

:help
    echo %FILE_N% Download and install a libpng.
    echo "Usage: %FILE_N% [-h^|--help] [--build-dir] [--zlib-install-dir]"
    goto eof

:success
    echo.
    echo %FILE_N% libpng has been successfully installed in "%LIBPNG_INSTALL_DIR%"!
    goto good_exit

:already_build
    echo %FILE_N% A libpng installation already exists.
    echo %FILE_N% Delete "%LIBPNG_INSTALL_DIR%" if you want to force a rebuild.
    goto good_exit

:error_download
    echo.
    echo %FILE_N% [DOWNLOAD ERROR] An error ocurred while downloading libpng.
    echo %FILE_N% [DOWNLOAD ERROR] Possible causes:
    echo %FILE_N%              - Make sure that the following url is valid:
    echo %FILE_N% "%LIBPNG_REPO%"
    echo %FILE_N% [DOWNLOAD ERROR] Workaround:
    echo %FILE_N%              - Download the libpng's source code and
    echo %FILE_N%                extract the content in
    echo %FILE_N%                "%LIBPNG_SRC_DIR%"
    echo %FILE_N%                And re-run the setup script.
    goto bad_exit

:error_extracting
    echo.
    echo %FILE_N% [EXTRACTING ERROR] An error ocurred while extracting the zip.
    echo %FILE_N% [EXTRACTING ERROR] Workaround:
    echo %FILE_N%              - Download the libpng's source code and
    echo %FILE_N%                extract the content manually in
    echo %FILE_N%                "%LIBPNG_SRC_DIR%"
    echo %FILE_N%                And re-run the setup script.
    goto bad_exit

:error_compiling
    echo.
    echo %FILE_N% [COMPILING ERROR] An error ocurred while compiling with cl.exe.
    echo %FILE_N%              Possible causes:
    echo %FILE_N%              - Make sure you have Visual Studio installed.
    echo %FILE_N%              - Make sure you have the "x64 Visual C++ Toolset" in your path.
    echo %FILE_N%                For example, using the "Visual Studio x64 Native Tools Command Prompt",
    echo %FILE_N%                or the "vcvarsall.bat".
    goto bad_exit

:error_generating_lib
    echo.
    echo %FILE_N% [NMAKE ERROR] An error ocurred while compiling and installing using nmake.
    goto bad_exit

:good_exit
    echo %FILE_N% Exiting...
    rem A return value used for checking for errors
    endlocal & set install_libpng=%LIBPNG_INSTALL_DIR%
    exit /b 0

:bad_exit
    if exist "%LIBPNG_INSTALL_DIR%" rd /s /q "%LIBPNG_INSTALL_DIR%"
    echo %FILE_N% Exiting with error...
    endlocal
    exit /b %errorlevel%
