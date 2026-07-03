/// 错题猎手 - 图片 URL 归一化工具
///
/// 数据库中 `question.imageUrl` 可能保存的是旧的内网地址（如
/// `http://REDACTED_LAN:8080/v1/files/...`），在公网 / 其他网络环境下不可达，
/// 会导致 `Image.network` 转圈几十秒直到超时。这里统一把图片 URL 的
/// origin（scheme+host+port）替换为当前后端 [AppConfig.apiBaseUrl] 的 origin，
/// 保证图片始终走当前 API 主机，公网/真机均可达。
library;

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// 把 [url] 的 origin 替换为 [AppConfig.apiBaseUrl] 的 origin，
/// 保留原 path + query + fragment。
///
/// - 对 http/https URL：替换 host/port，保留路径与查询串。
///   例：`http://REDACTED_LAN:8080/v1/files/questions/17/abc.png?token=x`
///   在 `apiBaseUrl=http://47.108.190.116:8080/v1` 下变成
///   `http://47.108.190.116:8080/v1/files/questions/17/abc.png?token=x`。
/// - 对非 http(s) URL（空串、`mock`、相对路径 `/v1/files/...` 等）原样返回，
///   避免误伤本地路径或 Mock 标记。
/// - 若 [AppConfig.apiBaseUrl] 本身解析失败，原样返回 [url]。
String normalizeImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return url;
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    // mock、相对路径、本地文件路径等原样返回
    return url;
  }

  final apiBase = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBase == null || apiBase.host.isEmpty) return url;

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || parsed.host.isEmpty) return url;

  // 已是同一 host+port 则 no-op，避免无谓重建
  if (parsed.scheme == apiBase.scheme &&
      parsed.host == apiBase.host &&
      parsed.port == apiBase.port) {
    return url;
  }

  try {
    return parsed
        .replace(scheme: apiBase.scheme, host: apiBase.host, port: apiBase.port)
        .toString();
  } catch (_) {
    return url;
  }
}

@visibleForTesting
String debugApiBaseOrigin() {
  final apiBase = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBase == null) return '';
  return apiBase.origin;
}
