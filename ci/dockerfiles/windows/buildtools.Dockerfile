ARG BASE_IMAGE_URL=containers.deltares.nl/swan-dev/delft3d-buildtools-windows:vs2022-intel2024-ltsc2025

FROM ${BASE_IMAGE_URL} AS buildtools

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]

# Add subversion to the existing Cygwin install (python3, make, git, cmake are
# already installed by the base image). The cache uses long, URL-encoded
# directory names that break the Windows container layer import if they ever
# persist beyond this RUN, so the setup exe and package cache must not be kept.
ADD setup-x86_64.exe C:\\cygwin-setup-x86_64.exe
RUN Start-Process -FilePath 'C:\cygwin-setup-x86_64.exe' -Wait -NoNewWindow -ArgumentList \
    '--quiet-mode', \
    '--no-shortcuts', \
    '--no-startmenu', \
    '--no-desktop', \
    '--no-admin', \
    '--upgrade-also', \
    '--root', 'C:\cygwin64', \
    '--local-package-dir', 'C:\cygwin-packages', \
    '--site', 'https://ftp.snt.utwente.nl/pub/software/cygwin/', \
    '--site', 'https://mirrors.kernel.org/sourceware/cygwin/', \
    '--site', 'https://cygwin.mirror.constant.com/', \
    '--only-site', \
    '--packages', 'subversion'; \
    Remove-Item -Force C:\cygwin-setup-x86_64.exe; \
    Remove-Item -Recurse -Force C:\cygwin-packages

CMD ["cmd", "/S", "/K", "C:\\set-env.cmd"]
