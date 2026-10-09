// novel_api.dart — ★27.0.16.9 番茄书源客户端（阅读器专用）
// 社区代理协议（与 mcp-server-fanqie 一致）：{base}/api/search|detail|book|directory|content
// 返回统一 {code:200, data:{...}}；地址可在阅读器设置里改（失效可换源）。
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api.dart';

class NovelApi {
  /// 搜索书籍（tab_type: 3=小说）
  /// data: {keyword, results:[{book_id, book_name, author, cover, abstract, total_words}]}
  static Future<Map<String, dynamic>> search(String key, {int offset = 0}) async {
    final base = Store.novelBase;
    try {
      final r = await http
          .get(Uri.parse('$base/api/search?key=${Uri.encodeQueryComponent(key)}&tab_type=3&offset=$offset'))
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if ((j['code'] as num?)?.toInt() == 200) return {'ok': true, 'data': j['data']};
      return {'ok': false, 'error': '${j['message'] ?? '搜索失败'} (${j['code']})'};
    } catch (e) {
      return {'ok': false, 'error': '网络错误：$e'};
    }
  }

  /// 书籍详情：data {book_id, book_name, author, abstract, cover, total_words, ...}
  static Future<Map<String, dynamic>> detail(String bookId) async {
    final base = Store.novelBase;
    try {
      final r = await http
          .get(Uri.parse('$base/api/detail?book_id=$bookId'))
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if ((j['code'] as num?)?.toInt() == 200) return {'ok': true, 'data': j['data']};
      return {'ok': false, 'error': '${j['message'] ?? '获取详情失败'} (${j['code']})'};
    } catch (e) {
      return {'ok': false, 'error': '网络错误：$e'};
    }
  }

  /// 简化目录：data {chapter_list:[{item_id, title}]} 或 {list:[...]}
  static Future<Map<String, dynamic>> directory(String bookId) async {
    final base = Store.novelBase;
    try {
      final r = await http
          .get(Uri.parse('$base/api/directory?book_id=$bookId'))
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if ((j['code'] as num?)?.toInt() == 200) return {'ok': true, 'data': j['data']};
      return {'ok': false, 'error': '${j['message'] ?? '获取目录失败'} (${j['code']})'};
    } catch (e) {
      return {'ok': false, 'error': '网络错误：$e'};
    }
  }

  /// 章节正文：data {content, title, ...}
  static Future<Map<String, dynamic>> chapter(String itemId) async {
    final base = Store.novelBase;
    try {
      final r = await http
          .get(Uri.parse('$base/api/content?tab=${Uri.encodeQueryComponent('小说')}&item_id=$itemId'))
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if ((j['code'] as num?)?.toInt() == 200) return {'ok': true, 'data': j['data']};
      return {'ok': false, 'error': '${j['message'] ?? '获取章节失败'} (${j['code']})'};
    } catch (e) {
      return {'ok': false, 'error': '网络错误：$e'};
    }
  }
}
