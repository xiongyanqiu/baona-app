# -*- coding: utf-8 -*-
import io

p = r'C:\Users\xilisi\Doubao\chats\2026-09-27\new-chat\baona-app\lib\chat.dart'
s = io.open(p, encoding='utf-8').read()

# 1. import sheets（openSearch/openSettings/openCtrl）
s = s.replace("import 'stickers.dart';", "import 'sheets.dart';\nimport 'stickers.dart';")

# 2. 类名 ChatPage -> ConversationPage
s = s.replace('class ChatPage extends StatefulWidget {', 'class ConversationPage extends StatefulWidget {')
s = s.replace('  const ChatPage({super.key});', '  const ConversationPage({super.key});')
s = s.replace('  State<ChatPage> createState() => _ChatPageState();',
              '  State<ConversationPage> createState() => _ChatPageState();')

# 3. build 开头：Column -> Scaffold + Wall + 对话页头部
old_head = '    return Column(children: [\n      Expanded('
new_head = '''    // ★2026-09-30 微信式改造：这是点进会话后的全屏对话页 —— 没有底栏，只有返回+消息+输入框
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Wall(
        url: app.bg,
        blur: app.bgBlur,
        opacity: app.bgOpacity,
        child: Column(children: [
      _ConvHeader(
        onBack: () => Navigator.of(context).maybePop(),
        onSearch: () => openSearch(context),
        onSet: () => openSettings(context),
        onCtrl: () => openCtrl(context),
      ),
      Expanded('''
assert old_head in s, 'head match fail'
s = s.replace(old_head, new_head)

# 4. build 结尾：补 Scaffold/Wall 闭合
old_tail = '''        ]),
      ),
    ]);
  }
}'''
new_tail = '''        ]),
      ),
        ]),
      ),
    );
  }
}'''
assert old_tail in s, 'tail match fail'
s = s.replace(old_tail, new_tail)

# 5. 文件末尾追加 _ConvHeader
header = '''

/* ------------------- 对话页头部（微信式：返回 + 头像 + 在线 + 快捷按钮） ------------------- */
class _ConvHeader extends StatelessWidget {
  const _ConvHeader({required this.onBack, required this.onSearch, required this.onSet, required this.onCtrl});
  final VoidCallback onBack, onSearch, onSet, onCtrl;

  @override
  Widget build(BuildContext context) {
    final av = '${app.herSet['herAvatar'] ?? ''}';
    return GlassBar(
      top: true,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
          child: Row(children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19), tooltip: '返回'),
            GestureDetector(
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
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.nick, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: app.online ? const Color(0xFF57D9A3) : kSub, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(app.status, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kSub))),
                  ]),
                ],
              ),
            ),
            IconButton(onPressed: onSearch, icon: const Icon(Icons.search, size: 20), tooltip: '搜聊天'),
            IconButton(onPressed: onCtrl, icon: const Icon(Icons.tune, size: 20), tooltip: '控制器'),
            IconButton(onPressed: onSet, icon: const Icon(Icons.settings_outlined, size: 20), tooltip: '设置'),
          ]),
        ),
      ),
    );
  }
}
'''
s += header
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('chat.dart OK, len', len(s))
