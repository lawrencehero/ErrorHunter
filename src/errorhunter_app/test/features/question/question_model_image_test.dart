/// 回归测试：QuestionModel.fromJson 必须对 image_url 做归一化，
/// 否则后端存的旧 host（如内网 IP）在 web/其它环境不可达，错题本/详情图片不显示。
///
/// 用一个明显不同于任何 apiBaseUrl 的输入 host，断言它被替换掉、path 保留，
/// 以此证明 fromJson 应用了 normalizeImageUrl（与 apiBaseUrl 具体值无关）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:errorhunter_app/features/question/models/question_model.dart';

Map<String, dynamic> _json({required String imageUrl}) => {
      'id': 23,
      'image_url': imageUrl,
      'error_category': 'KNOWLEDGE',
      'status': 'NOT_STARTED',
      'created_at': '2026-06-27T22:33:59.652327+08:00',
    };

void main() {
  test('fromJson 对 image_url 做归一化：任意 host 被替换为当前后端 host，path 保留', () {
    const input = 'http://some-stale-host:9999/v1/files/questions/17/abc.png';
    final q = QuestionModel.fromJson(_json(imageUrl: input));
    // 输入的旧 host 必须被替换掉
    expect(q.imageUrl.contains('some-stale-host'), isFalse,
        reason: 'image_url 的 host 必须被归一化替换');
    expect(q.imageUrl.contains('9999'), isFalse,
        reason: '旧端口必须被替换掉');
    // path 必须保留
    expect(q.imageUrl.endsWith('/v1/files/questions/17/abc.png'), isTrue,
        reason: 'path 必须保留');
    expect(q.imageUrl.startsWith('http://'), isTrue);
  });

  test('fromJson 归一化幂等：已是当前后端 host 的 URL 保持可用（path 不丢）', () {
    // 用一个非默认 host 输入，归一化后统一到 apiBaseUrl host；再 fromJson 一次仍稳定
    const input = 'http://whatever-host:1/v1/files/questions/17/x.png';
    final q1 = QuestionModel.fromJson(_json(imageUrl: input));
    final q2 = QuestionModel.fromJson(_json(imageUrl: q1.imageUrl));
    expect(q2.imageUrl, q1.imageUrl, reason: '对已归一化的 URL 再次解析应幂等');
    expect(q2.imageUrl.endsWith('/v1/files/questions/17/x.png'), isTrue);
  });
}
