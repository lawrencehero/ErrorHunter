/// 错题猎手 - 含 LaTeX 公式的文本渲染组件
///
/// OCR 识别结果中可能含 LaTeX 公式（如 \frac{3}{4}），普通 Text 无法渲染。
/// 按行渲染：每行用正则切出文本段与公式段，文本段用 Text、公式段用 Math.tex，
/// 在 Wrap 中内联混排；单行公式解析失败时回退为纯文本。
library;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// 归一化 OCR/公式文本中的度数符号。
///
/// 部分 OCR 引擎把角度符号 ° 误识别为 `^{。}`（上标 + 中文句号）或 `^。`，
/// 既非合法 LaTeX（无法被 Math.tex 渲染）也不是真正的度数符号，显示成 `^{。}`。
/// 这里统一还原为 °（U+00B0），由 Text 段正常渲染为右上角小圈。
/// 同时处理合法但本组件无法内联渲染的 `^{\circ}`，避免被公式切分拆散。
String normalizeMathText(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'\^\s*\{\s*(?:。|°|\\circ)\s*\}'),
        (_) => '°',
      )
      .replaceAllMapped(
        RegExp(r'\^。'),
        (_) => '°',
      );
}

class MathText extends StatelessWidget {
  const MathText(
    this.text, {
    super.key,
    this.style,
    this.mathStyle,
    this.textAlign = TextAlign.left,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? mathStyle;
  final TextAlign textAlign;
  /// 最大显示行数（超出截断，主要用于列表预览）；null 表示全部显示
  final int? maxLines;

  /// 匹配一个 LaTeX 表达式：命令 + 后续花括号组（允许空格），如 \frac { 3 } { 4 }
  static final _latexExpr = RegExp(r'\\[a-zA-Z]+(?:\s*\{[^}]*\})*');

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    var lines = normalizeMathText(text).split('\n');
    bool truncated = false;
    if (maxLines != null && lines.length > maxLines!) {
      lines = lines.sublist(0, maxLines!);
      truncated = true;
    }
    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < lines.length; i++) _buildLine(lines[i].trimRight()),
        if (truncated)
          Text('…', style: style, textAlign: textAlign),
      ],
    );
  }

  Widget _buildLine(String line) {
    if (line.isEmpty) return const SizedBox(height: 4);
    final matches = _latexExpr.allMatches(line).toList();
    if (matches.isEmpty) {
      return Text(
        line,
        style: style,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    // 内联混排：文本段 + 公式段
    final segments = <Widget>[];
    int last = 0;
    for (final m in matches) {
      if (m.start > last) {
        segments.add(Text(line.substring(last, m.start), style: style));
      }
      final tex = m.group(0)!;
      try {
        segments.add(Math.tex(tex, textStyle: mathStyle ?? style));
      } catch (_) {
        segments.add(Text(tex, style: style));
      }
      last = m.end;
    }
    if (last < line.length) {
      segments.add(Text(line.substring(last), style: style));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: segments,
    );
  }
}
