mkdir -Force build | Out-Null
cd build
cmake .. -G "Visual Studio 17 2022" -A x64 `
    -DOpenCV_DIR="C:\tools\opencv\build"
cmake --build . --config Release