# -*- coding: utf-8 -*-
import io

# ============ main.dart 加 dart:convert（按实际 import 块） ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\main.dart'
s = io.open(p, encoding='utf-8').read()
old = """// 包娜 · 手机端 App 主入口：连电脑 → 登录 → 主界面（聊天/商城/游戏/我们）
import 'package:flutter/material.dart';"""
new = """// 包娜 · 手机端 App 主入口：连电脑 → 登录 → 主界面（聊天/商城/游戏/我们）
import 'dart:convert';

import 'package:flutter/material.dart';"""
assert old in s, 'main convert fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('main.dart 加 dart:convert OK')

# ============ chat.dart _ConvHeader 头像缓存 ============
p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()

old_hdr = """            GestureDetector(
              onTap: onSet,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                  image: avatarOf(av) == null ? null : DecorationImage(image: avatarOf(av)!, fit: BoxFit.cover),
                ),
                child: av.isEmpty ? const Center(child: Text('娜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))) : null,
              ),
            ),"""
new_hdr = """            GestureDetector(
              onTap: onSet,
              child: av.isEmpty
                  ? Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kAccent, kAccent2])),
                      child: const Center(child: Text('娜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                    )
                  : FutureBuilder<ImageProvider>(
                      future: ImgCache.provider(avatarOf(av)!.toString()),
                      builder: (c, s) => Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [kAccent, kAccent2]),
                          image: s.data == null ? null : DecorationImage(image: s.data!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
            ),"""
assert old_hdr in s, 'conv header avatar fail'
s = s.replace(old_hdr, new_hdr)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart _ConvHeader 头像缓存完成')
