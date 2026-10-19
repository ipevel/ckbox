import 'package:ckbox/state.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// 极简 Markdown 渲染（面板公告用）。
///
/// 支持：标题、围栏代码块、行内代码、粗体、斜体、链接、无序/有序列表、
/// 引用块、分隔线。不引第三方包——项目 UI 走 `material_ui` fork，
/// `flutter_markdown` 依赖 `flutter/material`，会有冲突。
class PanelMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? baseStyle;

  const PanelMarkdown(this.data, {super.key, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final base = baseStyle ?? DefaultTextStyle.of(context).style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _blocks(context, base),
    );
  }

  List<Widget> _blocks(BuildContext context, TextStyle base) {
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final out = <Widget>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // 空行
      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 围栏代码块
      if (trimmed.startsWith('```')) {
        final buffer = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buffer.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // 跳过闭合
        out.add(_codeBlock(context, buffer.join('\n')));
        continue;
      }

      // 分隔线
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        out.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1),
        ));
        i++;
        continue;
      }

      // 标题
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final size = switch (level) {
          1 => 20.0,
          2 => 18.0,
          3 => 16.0,
          _ => 15.0,
        };
        out.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text.rich(
            TextSpan(
              children: _inline(
                context,
                heading.group(2)!,
                base.copyWith(fontSize: size, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ));
        i++;
        continue;
      }

      // 无序列表 / 有序列表（连续行合并成一组）
      final bullet = RegExp(r'^([-*+]|\d+\.)\s+(.*)$');
      if (bullet.hasMatch(trimmed)) {
        final items = <String>[];
        while (i < lines.length && bullet.hasMatch(lines[i].trim())) {
          final m = bullet.firstMatch(lines[i].trim())!;
          final marker = m.group(1)!;
          final prefix = RegExp(r'^\d').hasMatch(marker)
              ? '$marker '
              : '• ';
          items.add('$prefix${m.group(2)!}');
          i++;
        }
        for (final item in items) {
          out.add(Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text.rich(
              TextSpan(children: _inline(context, item, base)),
            ),
          ));
        }
        continue;
      }

      // 引用
      if (trimmed.startsWith('>')) {
        final buffer = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          buffer.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        out.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 3,
              ),
            ),
          ),
          child: Text.rich(
            TextSpan(children: _inline(context, buffer.join('\n'), base)),
          ),
        ));
        continue;
      }

      // 普通段落（连续非空行合并）
      final buffer = <String>[];
      while (i < lines.length) {
        final t = lines[i].trim();
        if (t.isEmpty ||
            t.startsWith('```') ||
            t.startsWith('>') ||
            bullet.hasMatch(t) ||
            RegExp(r'^#{1,6}\s').hasMatch(t) ||
            RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(t)) {
          break;
        }
        buffer.add(t);
        i++;
      }
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(children: _inline(context, buffer.join('\n'), base)),
        ),
      ));
    }

    return out;
  }

  Widget _codeBlock(BuildContext context, String code) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          code,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }

  /// 行内解析：行内代码、粗体、斜体、链接。
  List<InlineSpan> _inline(
    BuildContext context,
    String text,
    TextStyle base,
  ) {
    final spans = <InlineSpan>[];
    final linkColor = Theme.of(context).colorScheme.primary;
    final buffer = StringBuffer();

    void flush([TextStyle? style]) {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: style ?? base));
      buffer.clear();
    }

    var i = 0;
    while (i < text.length) {
      final rest = text.substring(i);

      // 行内代码
      if (rest.startsWith('`')) {
        final end = text.indexOf('`', i + 1);
        if (end > i) {
          flush();
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: base.copyWith(
              fontFamily: 'monospace',
              fontSize: (base.fontSize ?? 14) - 1,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ));
          i = end + 1;
          continue;
        }
      }

      // 粗体
      if (rest.startsWith('**')) {
        final end = text.indexOf('**', i + 2);
        if (end > i) {
          flush();
          spans.add(TextSpan(
            text: text.substring(i + 2, end),
            style: base.copyWith(fontWeight: FontWeight.w600),
          ));
          i = end + 2;
          continue;
        }
      }

      // 斜体
      if (rest.startsWith('*') && !rest.startsWith('**')) {
        final end = text.indexOf('*', i + 1);
        if (end > i) {
          flush();
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ));
          i = end + 1;
          continue;
        }
      }

      // 链接
      if (rest.startsWith('[')) {
        final close = text.indexOf(']', i + 1);
        if (close > i && close + 1 < text.length && text[close + 1] == '(') {
          final end = text.indexOf(')', close + 2);
          if (end > close) {
            final label = text.substring(i + 1, close);
            final url = text.substring(close + 2, end);
            flush();
            spans.add(TextSpan(
              text: label,
              style: base.copyWith(
                color: linkColor,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => globalState.openUrl(url, needConfirm: true),
            ));
            i = end + 1;
            continue;
          }
        }
      }

      buffer.write(text[i]);
      i++;
    }

    flush();
    return spans.isEmpty ? [TextSpan(text: '', style: base)] : spans;
  }
}
