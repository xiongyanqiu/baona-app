# -*- coding: utf-8 -*-
import io, os, re, json, shutil, datetime

# ============ 1. main.js：删 hangryHint + 默认 topics 去掉'喊饿讨要' ============
p = r'C:\Users\xilisi\AppData\Local\nvyou-desktop\app-1.5.7\resources\app\src\main.js'
s = io.open(p, encoding='utf-8').read()

# 1a. 删掉 hangryHint 整块（含注释那行）
old_hangry = """  const hangryHint = topics.includes('喊饿讨要')
    ? '（这回你主动开口直接要：说想吃他的鸡巴、想他射嘴里、想吞下去——用直白名词说具体，别拿「饿」打比方）'
    : '';
"""
assert old_hangry in s, 'hangry match fail'
s = s.replace(old_hangry, '')

# 1b. 去掉引用 hangryHint 的地方
old_join = "  return '（现在你想主动给他发条消息，心情偏：' + topics.join('、') + '。' + hangryHint +"
new_join = "  return '（现在你想主动给他发条消息，心情偏：' + topics.join('、') + '。' +"
assert old_join in s, 'join match fail'
s = s.replace(old_join, new_join)

# 1c. 默认主题去掉'喊饿讨要'，换成中性的'生活琐事'
old_topics = "  proactiveTopics: ['撒娇黏人', '日常关心', '说想你', '喊饿讨要'],  // 她主动聊的方向（多选）"
new_topics = "  proactiveTopics: ['撒娇黏人', '日常关心', '说想你', '生活琐事'],  // 她主动聊的方向（多选）"
assert old_topics in s, 'topics match fail'
s = s.replace(old_topics, new_topics)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('main.js：hangryHint 已删、默认主题已换')

# ============ 2. daemon.js：timeBasedSeed 去旧大学元素 ============
d = r'C:\Users\xilisi\AppData\Local\nvyou-desktop\app-1.5.7\resources\app\src\daemon.js'
ds = io.open(d, encoding='utf-8').read()

old_time = """  if (h >= 7 && h < 9) return '（早上刚醒，迷迷糊糊的，跟他说句早安或者你醒了想干嘛。）';
  if (h >= 12 && h < 14) return '（中午了，想到吃饭这件事——说你想吃什么，或者吐槽食堂。）';
  if (h >= 15 && h < 17) return '（下午了，有点闲，想起什么说什么——上课困了、室友在干嘛、窗外天气怎么样。）';
  if (h >= 22 && h < 24) return '（晚上了，有点累但还不想睡，黏他一会儿，说点软的。）';"""
new_time = """  if (h >= 7 && h < 9) return '（早上刚醒，迷迷糊糊的，跟他说句早安或者你醒了想干嘛。）';
  if (h >= 12 && h < 14) return '（中午了，想到吃饭这件事——说你想吃什么，或者吐槽今天做饭买菜的事。）';
  if (h >= 15 && h < 17) return '（下午了，有点闲，想起什么说什么——家里的事、他最近在忙什么、窗外天气怎么样。）';
  if (h >= 22 && h < 24) return '（晚上了，有点累但还不想睡，黏他一会儿，说点软的。）';"""
assert old_time in ds, 'daemon time match fail'
ds = ds.replace(old_time, new_time)
io.open(d, 'w', encoding='utf-8', newline='').write(ds)
print('daemon.js：timeBasedSeed 已中性化')

# ============ 3. pet-settings.json：proactiveTopics 去掉'喊饿讨要' + bareMode 关掉 ============
sf = r'C:\Users\xilisi\AppData\Roaming\色情女友桌宠\pet-settings.json'
if os.path.exists(sf):
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    shutil.copy2(sf, sf + '.bak-topic-' + stamp)
    st = json.loads(io.open(sf, encoding='utf-8').read())
    tp = st.get('proactiveTopics') or []
    st['proactiveTopics'] = [x for x in tp if x != '喊饿讨要']
    if '生活琐事' not in st['proactiveTopics']:
        st['proactiveTopics'].append('生活琐事')
    if not st['proactiveTopics']:
        st['proactiveTopics'] = ['撒娇黏人', '日常关心', '说想你']
    st['bareMode'] = False
    io.open(sf, 'w', encoding='utf-8', newline='').write(json.dumps(st, ensure_ascii=False, indent=1))
    print('pet-settings.json：proactiveTopics =', st['proactiveTopics'], '，bareMode =', st['bareMode'], '（备份', sf + '.bak-topic-' + stamp, '）')
else:
    print('pet-settings.json 不存在，跳过')
