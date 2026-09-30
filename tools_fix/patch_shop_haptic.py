# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\shop.dart'
s = io.open(p, encoding='utf-8').read()
if 'HapticFeedback' not in s:
    old_imp = "import 'package:flutter/material.dart';"
    new_imp = "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';"
    assert old_imp in s, 'shop services import fail'
    s = s.replace(old_imp, new_imp)
old_buy = """  Future<void> _buy(ShopItem it, bool forHer) async {
    final a = app.api;"""
new_buy = """  Future<void> _buy(ShopItem it, bool forHer) async {
    HapticFeedback.mediumImpact(); // ★2.0 第一波：购买确认触感
    final a = app.api;"""
assert old_buy in s, 'shop buy fail'
s = s.replace(old_buy, new_buy)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('shop.dart 购买触感完成')
