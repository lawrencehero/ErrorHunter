/// 错题猎手 - OCR 识别结果（文本 + 图形区域）
library;

import 'package:equatable/equatable.dart';

/// OCR 识别结果
class OcrResult extends Equatable {
  const OcrResult({required this.text, this.imageUrl = '', this.figures = const []});

  /// 识别出的题目文本（含 LaTeX 公式）
  final String text;

  /// 上传到对象存储后的图片 URL（用于保存为错题的 image_url）
  final String imageUrl;

  /// 识别到的图形区域（相对原图像素坐标），用于从原图裁剪展示
  final List<OcrFigure> figures;

  @override
  List<Object?> get props => [text, imageUrl, figures];
}

/// 图形区域
class OcrFigure extends Equatable {
  const OcrFigure({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String type;
  final int x;
  final int y;
  final int width;
  final int height;

  factory OcrFigure.fromJson(Map<String, dynamic> json) {
    return OcrFigure(
      type: json['type'] as String? ?? '',
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['w'] as num?)?.toInt() ?? 0,
      height: (json['h'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [type, x, y, width, height];
}
