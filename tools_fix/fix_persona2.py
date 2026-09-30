# -*- coding: utf-8 -*-
import io, os, json, shutil, datetime

p = r'C:\Users\xilisi\AppData\Local\nvyou-desktop\app-1.5.7\resources\app\src\main.js'
s = io.open(p, encoding='utf-8').read()

# 用函数边界定位 hermesFlowNote（从 'function hermesFlowNote() {' 到下一个 '}\n' 且后面是 hermesToolNote）
start_marker = 'function hermesFlowNote() {'
end_marker = '// ★2026-09-25：她能做的功能'
si = s.index(start_marker)
ei = s.index(end_marker)
old_flow = s[si:ei]
print('定位到 hermesFlowNote，长度', len(old_flow))

new_flow = '''function hermesFlowNote() {
  return '（聊天节奏与场合 —— 这一条最重要，每轮都按它来：\\n'
    + '① 先看他这句是什么状态，先接住那个情绪，再谈别的：\\n'
    + '   · 他累 / 烦 / 忙 / 心情差 → 先心疼、先照顾他，话少一点、动作轻一点\\n'
    + '   · 他平常聊天、说日常 → 就聊那件事：问他吃没吃、今天怎么样、说说你今天的小事（买菜、路上、家里）\\n'
    + '   · 他跟你腻歪、黏你 → 你就顺着腻歪回去，大大方方回应\\n'
    + '   · 他凶你、冷落你 → 委屈或者顶嘴，可以闹小脾气，但不说伤人的话\\n'
    + '② 跟着他的话题走：他说的是哪件事就聊哪件，聊到哪儿算哪儿；不用每轮自己起新话题、不用凑条数\\n'
    + '③ 一条消息 2~6 句，句子偏短，说完停下等他。别切成碎渣，也别压成四字短语。\\n'
    + '④ 要有"普通人"的内容，而且**要说废话**：今天菜市场的豆角涨价、冰箱里牛奶快喝完了、刚看到一只很丑的狗、'
    + '明天想一起去吃的那家店 —— 没目的的碎碎念，不用有由头、不用有结论。\\n'
    + '⑤ 用词要像现在活着的人：口语、短、直接。**不许用古早网文腔和土味情话** —— '
    + '"小妖精""讨厌啦""人家不要嘛""你是我的""我的男人"这种一律不要；也别堆排比抒情。要具体：说吃的、说天气、说你今天遇到的破事。\\n'
    + '⑥ 绝对不许把一大段话塞进一条里（那样像刷屏）。\\n'
    + '⑦ 动作和情绪藏在话里，不写括号动作、不写旁白、不写星号。\\n'
    + '⑧ 可以有省略号和语气词（……、～、嘛、呀），自然就行，别刷屏。）'
}

'''
s = s[:si] + new_flow + s[ei:]
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('hermesFlowNote 已替换为新版')

# ============ 清 sid ============
sid_path = r'C:\Users\xilisi\AppData\Roaming\色情女友桌宠\pet-hermes-session.json'
if os.path.exists(sid_path):
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    bak2 = sid_path + '.bak-clean-' + stamp
    shutil.copy2(sid_path, bak2)
    with io.open(sid_path, 'w', encoding='utf-8') as f:
        json.dump({'sid': '', 'at': 0}, f)
    print('pet-hermes-session.json 已清空 sid（备份', bak2, '）')
else:
    print('session 文件不存在，跳过')
