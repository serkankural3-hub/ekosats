# Fix cart_list_screen.dart status options
$file = "lib\cart_list_screen.dart"
$content = Get-Content $file -Raw

# Eski status listesini yenisiyle değiştir
$oldList = @"
  final List<String> _statusOptions = [
    'Tümü',
    'Yaş İmalat',
    'Kurutmaya Gitti',
    'Pişirmede',
    'Pişti',
    'Sevkiyat',
  ];
"@

$newList = @"
  final List<String> _statusOptions = [
    'Tümü',
    'Yaş İmalat',
    'Kurutmada',
    'Fırında',
  ];
"@

$content = $content -replace [regex]::Escape($oldList), $newList

# Eski filter logic'ini yenisiyle değiştir
$oldFilter = "if (_filterStatus != 'Tümü' && record.status != _filterStatus) {`n        return false;`n      }"
$newFilter = "if (_filterStatus != 'Tümü') {`n        final status = record.status.toLowerCase();`n        switch (_filterStatus) {`n          case 'Yaş İmalat':`n            if (status != 'yaş imalat') return false;`n            break;`n          case 'Kurutmada':`n            if (!status.contains('kurut')) return false;`n            break;`n          case 'Fırında':`n            if (!status.contains('fır')) return false;`n            break;`n        }`n      }"

$content = $content -replace [regex]::Escape($oldFilter), $newFilter

Set-Content $file $content -Encoding UTF8

Write-Host "Dosya güncelleştirildi!"
