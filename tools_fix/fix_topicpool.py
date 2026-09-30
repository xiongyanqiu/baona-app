# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\AppData\Local\nvyou-desktop\app-1.5.7\resources\app\src\main.js'
s = io.open(p, encoding='utf-8').read()

old = "const TOPIC_POOL = ['撒娇黏人', '说想你', '喊饿讨要', '俏皮调侃', '小抱怨吃醋', '催他回家', '求夸奖'];"
new = "const TOPIC_POOL = ['撒娇黏人', '说想你', '生活琐事', '俏皮调侃', '小抱怨吃醋', '催他回家', '求夸奖'];"
assert old in s, 'topic_pool match fail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('TOPIC_POOL 已替换')

# 兜底：万一设置面板曾存过'喊饿讨要'（TOPIC_POOL 校验会拦掉新勾选，但老存盘可能还有）
import os, json, datetime, shutil
sf = r'C:\Users\xilisi\AppData\Roaming\色情女友桌宠\pet-settings.json'
if os.path.exists(sf):
    st = json.loads(io.open(sf, encoding='utf-8').read())
    if '喊饿讨要' in (st.get('proactiveTopics') or []):
        stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
        shutil.copy2(sf, sf + '.bak2-' + stamp)
        st['proactiveTopics'] = [x for x in st.get('proactiveTopics', []) if x != '喊饿讨要']
        io.open(sf, 'w', encoding='utf-8', newline='').write(json.dumps(st, ensure_ascii=False, indent=1))
        print('pet-settings.json 再次清理' + str(st['proactiveTopics']))
    else:
        print('pet-settings.json 无残留')
