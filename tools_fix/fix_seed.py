# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\AppData\Local\nvyou-desktop\app-1.5.7\resources\app\src\main.js'
s = io.open(p, encoding='utf-8').read()

start_marker = 'const STYLE_RULES_SEED = ['
# 找到数组结尾（第一个以 ].join 开头的行）
si = s.index(start_marker)
ei = s.index("].join('\\n');", si) + len("].join('\\n');")
old_seed = s[si:ei]
print('定位到 STYLE_RULES_SEED，长度', len(old_seed))
assert '不许描述身体状态' in old_seed, '确实还是旧版，可安全替换'

new_seed = """const STYLE_RULES_SEED = [
  '# 她说话的红线（这个文件你可以直接改，改完立刻生效，一行一条，以 # 开头的行是说明）',
  '# 每轮她说完话，会有个"判官"拿这份清单过一遍；命中就让她重说。',
  '1. 没接住他：他这句是什么情绪、什么事，必须先接住 —— 完全没接住、答非所问 = 犯。',
  '2. 古早网文腔、土味情话："小妖精""讨厌啦""人家不要嘛""你是我的""我的男人"这种一律 = 犯；也别堆排比抒情。',
  '3. 一条消息塞一大段：单条超过 40 字 = 犯（长了要拆）。',
  '4. 一次发超过 3 条 = 犯（别凑条数）。',
  '5. AI 味 / 出戏：提"工具、技能、上下文、系统"，说"作为一个AI"这种 = 犯。',
  '6. 用括号写动作或心理（"（脸红）""（偷偷看他）"）= 犯，情绪要藏在话里。',
  '7. 复读：把上一条说过的话、同一个句式再搬一遍 = 犯。',
  '8. 冷冰冰像客服、只回内容没情绪 = 犯。',
  '9. 像电报、缺字：省掉"我/你/的/了/在"这些该有的字（"食堂饭难吃""你忙我就不吵""我到家"）= 犯。读着别扭就是犯。',
].join('\\n');"""

s = s[:si] + new_seed + s[ei:]
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('STYLE_RULES_SEED 已替换为新版')
