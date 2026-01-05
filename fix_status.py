#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

file_path = "lib/cart_list_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace status options list
old_list = """final List<String> _statusOptions = [
    'Tümü',
    'Yaş İmalat',
    'Kurutmaya Gitti',
    'Pişirmede',
    'Pişti',
    'Sevkiyat',
  ];"""

new_list = """final List<String> _statusOptions = [
    'Tümü',
    'Yaş İmalat',
    'Kurutmada',
    'Fırında',
  ];"""

content = content.replace(old_list, new_list)

# Replace filter logic
old_filter = """if (_filterStatus != 'Tümü' && record.status != _filterStatus) {
        return false;
      }"""

new_filter = """if (_filterStatus != 'Tümü') {
        final status = record.status.toLowerCase();
        switch (_filterStatus) {
          case 'Yaş İmalat':
            if (status != 'yaş imalat') return false;
            break;
          case 'Kurutmada':
            if (!status.contains('kurut')) return false;
            break;
          case 'Fırında':
            if (!status.contains('fır')) return false;
            break;
        }
      }"""

content = content.replace(old_filter, new_filter)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Dosya başarıyla güncellendi!")
