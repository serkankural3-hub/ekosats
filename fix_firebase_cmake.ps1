# Build hook to patch Firebase SDK CMakeLists.txt
# This script fixes the cmake_minimum_required version issue

$firebaseCMakePath = "build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"

function PatchFirebaseCMake {
    if (Test-Path $firebaseCMakePath) {
        Write-Host "Patching Firebase SDK CMakeLists.txt..."
        
        $content = Get-Content $firebaseCMakePath -Raw
        
        # Replace old cmake_minimum_required
        $newContent = $content -replace 'cmake_minimum_required\(VERSION 3\.1\)', 'cmake_minimum_required(VERSION 3.15)'
        
        if ($content -ne $newContent) {
            Set-Content $firebaseCMakePath $newContent -Encoding UTF8
            Write-Host "Successfully patched $firebaseCMakePath"
        } else {
            Write-Host "No changes needed in $firebaseCMakePath"
        }
    } else {
        Write-Host "Firebase CMakeLists.txt not found yet. It will be patched during first build."
    }
}

# Run patch immediately
PatchFirebaseCMake

# Also create a wrapper that patches before cmake
$wrapperScript = @"
# Auto-patch Firebase CMakeLists.txt on every build attempt
`$firebasePath = "build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"
if (Test-Path `$firebasePath) {
    `$content = Get-Content `$firebasePath -Raw
    if (`$content -match 'cmake_minimum_required\(VERSION 3\.1\)') {
        (Get-Content `$firebasePath -Raw) -replace 'cmake_minimum_required\(VERSION 3\.1\)', 'cmake_minimum_required(VERSION 3.15)' | Set-Content `$firebasePath -Encoding UTF8
    }
}
"@

$wrapperScript | Out-File -FilePath ".dart_tool\flutter_build_wrapper.ps1" -Encoding UTF8 -Force

