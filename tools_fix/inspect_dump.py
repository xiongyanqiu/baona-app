# -*- coding: utf-8 -*-
import json, io

f = r'C:\Users\xilisi\AppData\Local\Hermes Agent CN Desktop\data\hermes-home\profiles\baona\sessions\request_dump_20260929_232924_822c59_20260930_111316_162852.json'
d = json.loads(io.open(f, encoding='utf-8').read())

msgs = d['request']['body']['messages']
print('总消息数:', len(msgs))
roles = {}
for m in msgs:
    roles[m['role']] = roles.get(m['role'], 0) + 1
print('角色分布:', roles)

# 打印最后 12 条历史（不含 system），看最近聊的内容/风格
print('\n=== 最后 12 条消息 ===')
for m in msgs[-12:]:
    c = str(m.get('content') or '')[:200].replace('\n', ' ')
    print(f"[{m['role']}] {c}")

# 找最早的消息看会话龄
print('\n=== 最早 3 条非 system 消息 ===')
non_sys = [m for m in msgs if m['role'] != 'system']
for m in non_sys[:3]:
    c = str(m.get('content') or '')[:150].replace('\n', ' ')
    print(f"[{m['role']}] {c}")
