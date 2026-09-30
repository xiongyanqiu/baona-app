# -*- coding: utf-8 -*-
import io

# ============ 1. main.js buildProactiveSeed 重写：去条框、带上下文、自然由头 ============
p = r'C:\Users\xilisi\AppData\Local\nvyou-desktop\app-1.5.7\resources\app\src\main.js'
s = io.open(p, encoding='utf-8').read()

start_marker = 'function buildProactiveSeed() {'
end_marker = '// ---------- 早安联动：休息时段一结束（sleepEnd）她醒来主动说早安，每天一次 ----------'
si = s.index(start_marker)
ei = s.index(end_marker)
print('定位 buildProactiveSeed 长度', ei - si)

new_seed = '''function buildProactiveSeed() {
  const nick = (settings.nickName || '包娜').trim();
  // ★2026-09-30 老公要的：不要条框、不要话题清单 —— 让她按上下文自然开口
  //   只给她：最近的对话（接着话头）+ 一个"想他"的由头（随机自然，不定话题）
  const tail = chatMirror.slice(-4).map((m) =>
    (m.role === 'user' ? '他' : nick) + '：' + String(m.content || '').slice(0, 50)).join(' ｜ ');
  const moods = [
    '你有点想他了',
    '你刚想到他，心里软软的',
    '你闲下来，脑子里全是他',
    '你拿起手机，就是想跟他说句话',
    '你想起他刚才说的话，忍不住想接一句',
  ];
  const pick = moods[Math.floor(Math.random() * moods.length)];
  return '（' + pick + '。' +
    (tail ? '你们刚聊到：「' + tail + '」，顺着这个话头自然说，或者你自己想说什么就说什么。' : '')
    + '就像拿着手机给他发微信一样，说一句你最想说的就行。'
    + '别说你在干什么（"我躺床上""我在发呆"这种），别解释这是系统让你说的。）';
}

'''
s = s[:si] + new_seed + s[ei:]
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('buildProactiveSeed 已重写')

# ============ 2. daemon.js timeBasedSeed 简化（去具体指导） ============
d = r'C:\Users\xilisi\AppData\Local\nvyou-desktop\app-1.5.7\resources\app\src\daemon.js'
ds = io.open(d, encoding='utf-8').read()

old_time = """  if (h >= 7 && h < 9) return '（早上刚醒，迷迷糊糊的，跟他说句早安或者你醒了想干嘛。）';
  if (h >= 12 && h < 14) return '（中午了，想到吃饭这件事——说你想吃什么，或者吐槽今天做饭买菜的事。）';
  if (h >= 15 && h < 17) return '（下午了，有点闲，想起什么说什么——家里的事、他最近在忙什么、窗外天气怎么样。）';
  if (h >= 22 && h < 24) return '（晚上了，有点累但还不想睡，黏他一会儿，说点软的。）';"""
new_time = """  if (h >= 7 && h < 9) return '（你刚醒，想跟他说句话。）';
  if (h >= 12 && h < 14) return '（中午了，你想到他，想发句消息。）';
  if (h >= 15 && h < 17) return '（下午有点闲，你拿起手机想跟他说点什么。）';
  if (h >= 22 && h < 24) return '（晚上，你黏着他，想说点软的。）';"""
assert old_time in ds, 'daemon time match fail'
ds = ds.replace(old_time, new_time)
io.open(d, 'w', encoding='utf-8', newline='').write(ds)
print('daemon.js timeBasedSeed 已简化')

# ============ 3. 校验 ============
import subprocess
r1 = subprocess.run(['node', '--check', p], capture_output=True, text=True)
r2 = subprocess.run(['node', '--check', d], capture_output=True, text=True)
print('main.js 语法:', 'OK' if r1.returncode == 0 else r1.stderr[:200])
print('daemon.js 语法:', 'OK' if r2.returncode == 0 else r2.stderr[:200])
