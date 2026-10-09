// novel.dart — ★27.0.16.9 番茄阅读器（符合软件设计：iOS 27 深色玻璃风格）
// 书架（收藏/最近阅读）→ 搜索 → 书籍详情+目录 → 章节阅读
// 书源走 novel_api（可配置地址，失效换源）；章节缓存本地，重复读不重复请求。
import 'dart:convert';

import 'package:flutter/material.dart';

import 'api.dart';
import 'novel_api.dart';
import 'theme.dart';

/// 书架页（入口页）
class NovelPage extends StatefulWidget {
  const NovelPage({super.key});
  @override
  State<NovelPage> createState() => _NovelPageState();
}

class _NovelPageState extends State<NovelPage> {
  final TextEditingController _kw = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final shelf = Store.novelShelf;
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        GlassBar(
          top: true,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0x1AFFFFFF), width: 0.8),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 17, color: kText),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('番茄小说',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                ),
                GestureDetector(
                  onTap: _openSourceSettings,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0x1AFFFFFF), width: 0.8),
                    ),
                    child: const Icon(Icons.tune, size: 18, color: kText),
                  ),
                ),
              ]),
            ),
          ),
        ),
        // 搜索框
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NovelSearchPage())),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x14FFFFFF), width: 0.8),
              ),
              child: const Row(children: [
                Icon(Icons.search, size: 19, color: kSub),
                SizedBox(width: 8),
                Text('搜索番茄小说书名 / 作者', style: TextStyle(fontSize: 14.5, color: kSub)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: shelf.isEmpty
              ? const _ShelfEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                  itemCount: shelf.length,
                  itemBuilder: (_, i) {
                    final b = shelf[i];
                    return _ShelfCard(
                      book: b,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => NovelDetailPage(book: b))),
                      onRemove: () {
                        final l = Store.novelShelf;
                        l.removeWhere((x) => x['book_id'] == b['book_id']);
                        Store.setNovelShelf(l);
                        setState(() {});
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }

  /// 书源地址设置（失效时可换）
  void _openSourceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('书源地址', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('番茄官方没有开放接口，正文内容由社区代理服务解密提供。'
                '地址失效时在这里换新地址即可。',
                style: TextStyle(fontSize: 13, color: kSub, height: 1.4)),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: Store.novelBase),
              style: const TextStyle(fontSize: 14.5, color: kText),
              decoration: InputDecoration(
                hintText: 'http://ip:port',
                hintStyle: const TextStyle(fontSize: 14, color: kSub),
                filled: true,
                fillColor: const Color(0x0FFFFFFF),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (v) {
                final s = v.trim();
                if (s.isNotEmpty) {
                  Store.setNovelBase(s);
                  Navigator.pop(c);
                }
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Store.setNovelBase('http://101.35.133.34:5000');
                  Navigator.pop(c);
                },
                child: const Text('恢复默认地址', style: TextStyle(fontSize: 14, color: kAccent)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 搜索页
class NovelSearchPage extends StatefulWidget {
  const NovelSearchPage({super.key});
  @override
  State<NovelSearchPage> createState() => _NovelSearchPageState();
}

class _NovelSearchPageState extends State<NovelSearchPage> {
  final TextEditingController _kw = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  String _err = '';

  Future<void> _search() async {
    final k = _kw.text.trim();
    if (k.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _err = '';
    });
    final r = await NovelApi.search(k);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r['ok'] == true) {
        final data = r['data'];
        _results = (data is Map ? (data['results'] as List?) ?? [] : []) as List<dynamic>;
        if (_results.isEmpty) _err = '没搜到「$k」，换个关键词试试';
      } else {
        _err = '${r['error'] ?? '搜索失败'}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        GlassBar(
          top: true,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0x1AFFFFFF), width: 0.8),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 17, color: kText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0x0FFFFFFF),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0x14FFFFFF), width: 0.8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.search, size: 18, color: kSub),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _kw,
                          autofocus: true,
                          style: const TextStyle(fontSize: 15, color: kText),
                          decoration: const InputDecoration(
                            hintText: '书名 / 作者',
                            hintStyle: TextStyle(fontSize: 14.5, color: kSub),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                    ]),
                  ),
                ),
                GestureDetector(
                  onTap: _search,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(_loading ? '…' : '搜索',
                        style: const TextStyle(fontSize: 15, color: kAccent, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kAccent))
              : _err.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(_err,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: kSub, height: 1.5)),
                      ),
                    )
                  : _results.isEmpty
                      ? const Center(
                          child: Text('搜索你想看的小说', style: TextStyle(fontSize: 14, color: kSub)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final b = _results[i] as Map;
                            return _SearchCard(
                              book: b,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => NovelDetailPage(book: b))),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}

/// 书籍详情 + 目录
class NovelDetailPage extends StatefulWidget {
  const NovelDetailPage({super.key, required this.book});
  final Map<String, dynamic> book;
  @override
  State<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends State<NovelDetailPage> {
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _chapters = [];
  bool _loading = true;
  String _err = '';
  String _bookId = '';
  String _bookName = '';

  @override
  void initState() {
    super.initState();
    _bookId = '${widget.book['book_id'] ?? widget.book['bookId'] ?? ''}';
    _bookName = '${widget.book['book_name'] ?? widget.book['bookName'] ?? '未知书名'}';
    _load();
  }

  Future<void> _load() async {
    if (_bookId.isEmpty) {
      setState(() {
        _loading = false;
        _err = '没有书籍 ID，无法获取内容';
      });
      return;
    }
    final d = await NovelApi.detail(_bookId);
    final dir = await NovelApi.directory(_bookId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (d['ok'] == true) _detail = (d['data'] as Map?)?.cast<String, dynamic>();
      if (dir['ok'] == true) {
        final dd = dir['data'];
        if (dd is Map) {
          final list = dd['chapter_list'] ?? dd['list'] ?? dd['chapters'];
          if (list is List) {
            _chapters = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } else {
        _err = '${dir['error'] ?? '目录获取失败'}';
      }
    });
  }

  void _openChapter(Map<String, dynamic> ch, int idx) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => NovelReaderPage(bookId: _bookId, bookName: _bookName, chapters: _chapters, index: idx)));
  }

  @override
  Widget build(BuildContext context) {
    final cover = '${_detail?['cover'] ?? widget.book['cover'] ?? ''}';
    final author = '${_detail?['author'] ?? widget.book['author'] ?? '未知作者'}';
    final abstract = '${_detail?['abstract'] ?? widget.book['abstract'] ?? ''}';
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        GlassBar(
          top: true,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0x1AFFFFFF), width: 0.8),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 17, color: kText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_bookName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kAccent))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  children: [
                    // 封面 + 简介
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x0FFFFFFF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x14FFFFFF), width: 0.8),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Cover(url: cover, size: 104),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_bookName,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
                            const SizedBox(height: 4),
                            Text(author, style: const TextStyle(fontSize: 13, color: kSub)),
                            const SizedBox(height: 8),
                            Text(abstract.isEmpty ? '（暂无简介）' : abstract,
                                maxLines: 5, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: kSub, height: 1.45)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final shelf = Store.novelShelf;
                            if (!shelf.any((x) => x['book_id'] == _bookId)) {
                              shelf.add({'book_id': _bookId, 'book_name': _bookName, 'author': author, 'cover': cover, 'abstract': abstract});
                              Store.setNovelShelf(shelf);
                            }
                            if (_chapters.isNotEmpty) _openChapter(_chapters.first, 0);
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: kAccent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: const Text('开始阅读',
                                style: TextStyle(fontSize: 15.5, color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    if (_err.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_err, style: const TextStyle(fontSize: 12.5, color: kBad)),
                      ),
                    if (_chapters.isNotEmpty) ...[
                      Text('目录 · ${_chapters.length}章',
                          style: const TextStyle(fontSize: 13, color: kSub, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ..._chapters.asMap().entries.map((e) => Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x0FFFFFFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x0FFFFFFF), width: 0.8),
                            ),
                            child: InkWell(
                              onTap: () => _openChapter(e.value, e.key),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                child: Row(children: [
                                  Expanded(
                                    child: Text('${e.value['title'] ?? '第${e.key + 1}章'}',
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14.5)),
                                  ),
                                  const Icon(Icons.chevron_right, size: 17, color: kSub),
                                ]),
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }
}

/// 阅读页
class NovelReaderPage extends StatefulWidget {
  const NovelReaderPage({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.chapters,
    required this.index,
  });
  final String bookId;
  final String bookName;
  final List<Map<String, dynamic>> chapters;
  final int index;
  @override
  State<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends State<NovelReaderPage> {
  late int _idx = widget.index;
  String _content = '';
  String _title = '';
  bool _loading = true;
  String _err = '';
  double _fontSize = 17.5;

  Map<String, dynamic>? get _cur =>
      _idx >= 0 && _idx < widget.chapters.length ? widget.chapters[_idx] : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ch = _cur;
    if (ch == null) {
      setState(() {
        _loading = false;
        _err = '没有章节';
      });
      return;
    }
    final itemId = '${ch['item_id'] ?? ch['id'] ?? ''}';
    final title = '${ch['title'] ?? ''}';
    setState(() {
      _loading = true;
      _err = '';
      _title = title;
    });
    // 缓存优先
    String? cached;
    try {
      final c = jsonDecode(Store.novelCache);
      if (c is Map) {
        final book = c[widget.bookId];
        if (book is Map && book[itemId] is String) cached = book[itemId];
      }
    } catch (_) {}
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _content = cached!;
        _loading = false;
      });
      return;
    }
    final r = await NovelApi.chapter(itemId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r['ok'] == true) {
        final data = r['data'];
        final c = data is Map ? '${data['content'] ?? ''}' : '${data ?? ''}';
        _content = c;
        _title = title.isEmpty ? '${data is Map ? data['title'] ?? '' : ''}' : title;
        // 缓存（只保留最近 5 章，防 SP 膨胀）
        try {
          final old = jsonDecode(Store.novelCache);
          final m = old is Map ? Map<String, dynamic>.from(old) : <String, dynamic>{};
          final book = m[widget.bookId] is Map ? Map<String, dynamic>.from(m[widget.bookId] as Map) : <String, dynamic>{};
          book[itemId] = c;
          if (book.length > 5) book.remove(book.keys.first);
          m[widget.bookId] = book;
          Store.setNovelCache(jsonEncode(m));
        } catch (_) {}
      } else {
        _err = '${r['error'] ?? '加载失败'}';
      }
    });
  }

  void _go(int delta) {
    final n = _idx + delta;
    if (n < 0 || n >= widget.chapters.length) return;
    setState(() => _idx = n);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      body: Column(children: [
        GlassBar(
          top: true,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0x1AFFFFFF), width: 0.8),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 17, color: kText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_title.isEmpty ? widget.bookName : _title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                ),
                Text('${_idx + 1}/${widget.chapters.length}',
                    style: const TextStyle(fontSize: 12.5, color: kSub)),
                const SizedBox(width: 8),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kAccent))
              : _err.isNotEmpty && _content.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(_err,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: kSub, height: 1.5)),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(_title,
                                style: TextStyle(fontSize: _fontSize + 3, fontWeight: FontWeight.w700, height: 1.4)),
                          ),
                        Text(_content.isEmpty ? '（章节内容为空）' : _content,
                            style: TextStyle(
                                fontSize: _fontSize,
                                color: const Color(0xFFE6E6EB),
                                height: 1.75,
                                letterSpacing: 0.1)),
                      ]),
                    ),
        ),
        // 底部工具栏：上一章 / 字号 / 下一章
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: GlassSurface(
              radius: 18,
              blur: kBlur,
              pad: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _go(-1),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _idx > 0 ? const Color(0x14FFFFFF) : const Color(0x08FFFFFF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text('上一章', style: TextStyle(fontSize: 13.5, color: _idx > 0 ? kText : kSub)),
                    ),
                  ),
                ),
                Expanded(
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GestureDetector(
                      onTap: () => setState(() => _fontSize = (_fontSize - 1.5).clamp(13.0, 26.0)),
                      child: Container(
                        width: 38, height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Text('A-', style: TextStyle(fontSize: 13.5, color: kText)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _fontSize = (_fontSize + 1.5).clamp(13.0, 26.0)),
                      child: Container(
                        width: 38, height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Text('A+', style: TextStyle(fontSize: 13.5, color: kText)),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _go(1),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _idx < widget.chapters.length - 1 ? const Color(0x14FFFFFF) : const Color(0x08FFFFFF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text('下一章',
                          style: TextStyle(fontSize: 13.5, color: _idx < widget.chapters.length - 1 ? kText : kSub)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------- 小组件 ----------

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.size});
  final String url;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.35,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.8),
      ),
      child: url.isEmpty
          ? const Icon(Icons.menu_book_outlined, size: 30, color: kSub)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.menu_book_outlined, size: 30, color: kSub),
            ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.book, required this.onTap, required this.onRemove});
  final Map<String, dynamic> book;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            _Cover(url: '${book['cover'] ?? ''}', size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${book['book_name'] ?? '未知书名'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${book['author'] ?? '未知作者'}',
                    style: const TextStyle(fontSize: 12.5, color: kSub)),
              ]),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: const Color(0x14FF3B30), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF6B66)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.book, required this.onTap});
  final Map<dynamic, dynamic> book;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            _Cover(url: '${book['cover'] ?? ''}', size: 62),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${book['book_name'] ?? '未知书名'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${book['author'] ?? ''}',
                    style: const TextStyle(fontSize: 12.5, color: kSub)),
                if ('${book['abstract'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('${book['abstract']}',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: kSub, height: 1.4)),
                ],
              ]),
            ),
            const Icon(Icons.chevron_right, size: 18, color: kSub),
          ]),
        ),
      ),
    );
  }
}

class _ShelfEmpty extends StatelessWidget {
  const _ShelfEmpty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 74, height: 74,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.menu_book_outlined, size: 34, color: kAccent),
        ),
        const SizedBox(height: 14),
        const Text('书架还空着', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('顶部搜索框搜番茄小说\n搜到后点进来看详情，就能加入书架', 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kSub, height: 1.5)),
      ]),
    );
  }
}
