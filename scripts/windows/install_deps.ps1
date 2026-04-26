# scripts/windows/install_deps.ps1

# 1. Install Chocolatey if not present (run as Admin)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.WebRequest]::DefaultWebProxy.Credentials = `
    [System.Net.CredentialCache]::DefaultCredentials
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# 2. Install tools
choco install -y cmake git python opencv visualstudio2022buildtools

# 3. Set OpenCV environment variable so CMake finds it
[System.Environment]::SetEnvironmentVariable(
    "OpenCV_DIR",
    "C:\tools\opencv\build",
    "User"
)
