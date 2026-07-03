/// normalizeImageUrl 单元测试
///
/// 守护：图片 URL 的 origin 必须被替换为当前 API base 的 origin，
/// 否则 Web/本机加载旧内网地址会卡几十秒到超时。
/// 同时确保 mock/空串/相对路径不被误改。
///
/// 注意：`AppConfig.apiBaseUrl` 在 `flutter test` 下未注入 `--dart-define`，
/// 取默认值 `http://47.108.190.116:8080/v1`。故这里始终构造一个
/// **与当前 API base host 不同** 的旧 URL 来验证替换行为，
/// 避免命中 no-op 分支（同 host 不改写）。
library;

import "package:flutter_test/flutter_test.dart";
import "package:errorhunter_app/config/app_config.dart";
import "package:errorhunter_app/utils/image_url_helper.dart";

void main() {
  // 当前 API base 的 origin，用作断言基准。
  final apiBase = Uri.parse(AppConfig.apiBaseUrl);
  final apiOrigin = apiBase.origin;

  // 构造一个保证与 apiBase host 不同的旧内网地址。
  // 用一个绝不会与真实 API host 冲突的占位域名。
  const oldHost = "old-internal.invalid";
  String oldUrl(String path) => "http://$oldHost:8080$path";

  group("normalizeImageUrl", () {
    test("替换旧 host 为当前 API base 的 origin，保留 path+query", () {
      final url = oldUrl("/v1/files/questions/17/abc.png?token=x");
      final result = normalizeImageUrl(url);
      expect(result, startsWith(apiOrigin));
      expect(result, endsWith("/v1/files/questions/17/abc.png?token=x"));
      // 不再含旧 host
      expect(result.contains(oldHost), isFalse);
    });

    test("保留 path 与 fragment", () {
      final url = oldUrl("/v1/files/questions/17/abc.png#frag");
      final result = normalizeImageUrl(url);
      expect(result, startsWith(apiOrigin));
      expect(result, contains("/v1/files/questions/17/abc.png"));
      expect(result, contains("#frag"));
    });

    test("mock / 空串 / 相对路径原样返回，不被误改", () {
      expect(normalizeImageUrl(""), "");
      expect(normalizeImageUrl("mock"), "mock");
      expect(normalizeImageUrl("/v1/files/17/abc.png"), "/v1/files/17/abc.png");
      // 本地文件路径（详情页用于 Image.file）不应被改
      expect(normalizeImageUrl("/data/user/0/files/img.png"),
          "/data/user/0/files/img.png");
    });

    test("已是当前 API host+port 时 no-op（不改写）", () {
      final alreadyCorrect = "$apiOrigin/v1/files/questions/17/abc.png";
      expect(normalizeImageUrl(alreadyCorrect), alreadyCorrect);
    });

    test("不同端口的同 host 也会被替换为 API base 端口", () {
      final url = "http://$oldHost:9000/v1/files/17/abc.png";
      final result = normalizeImageUrl(url);
      expect(result, startsWith(apiOrigin));
      expect(result, contains("/v1/files/17/abc.png"));
    });
  });
}
