Windows build (local install)

What I packaged:
- build/windows/x64/install — contains ekosatsss.exe, required DLLs and flutter assets.
- Packaged to: build/ekosatsss-windows-release.zip

How to run:
1. Unzip `build/ekosatsss-windows-release.zip` to a folder (e.g. `C:\Users\<you>\Apps\ekosatsss`).
2. Double-click `ekosatsss.exe` inside the extracted folder to run the app.

Notes:
- This build is non-destructive and does not modify Program Files.
- If you want a proper installer (MSIX or signed installer), I can create one — this requires signing certificates or additional config.
- If you want me to commit the lightweight CMake fixes I made (`windows/CMakeLists.txt`), tell me and I will create a commit.
