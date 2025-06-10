import 'dart:convert';

import 'package:crypto/crypto.dart';

/// http://DomainName/FileName?sign=md5hash&t=timestamp
/// https://cloud.tencent.com/document/product/228/41625
String sign({
  required String url,
  required String pkey,
  String signParamName = "sign",
  String timeParamName = "t",
}) {
  Uri? uri = Uri.tryParse(url);
  if (null == uri) {
    return url;
  }
  int time = DateTime.now().millisecondsSinceEpoch;
  String sign = "$pkey${uri.path}$time";
  String result = md5.convert(utf8.encode(sign)).toString();
  Map<String, dynamic> queryParams = Map.from(uri.queryParameters);
  queryParams[signParamName] = result;
  queryParams[timeParamName] = time.toString();
  return uri.replace(queryParameters: queryParams).toString();
}
