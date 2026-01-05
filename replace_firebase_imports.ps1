# Script to replace Firebase imports with mock imports for Windows build
Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw

    # Replace Firebase imports with mock imports
    $newContent = $content -replace "import 'package:firebase_auth/firebase_auth.dart';", "import 'firebase_mock.dart';"
    $newContent = $newContent -replace "import 'package:cloud_firestore/cloud_firestore.dart';", "// Firebase import replaced with mock"
    $newContent = $newContent -replace "import 'package:firebase_core/firebase_core.dart';", "// Firebase import replaced with mock"
    $newContent = $newContent -replace "import 'firebase_options.dart';", "// Firebase options import disabled"

    if ($content -ne $newContent) {
        Set-Content $_.FullName $newContent
        Write-Host "Updated: $($_.FullName)"
    }
}

Write-Host "Firebase import replacement completed."