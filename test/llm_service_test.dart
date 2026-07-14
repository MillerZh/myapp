import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/disciplines/default_rules.dart';
import 'package:stock/models/app_settings.dart';
import 'package:stock/services/llm_service.dart';

void main() {
  const config = LlmConfig(
    baseUrl: 'https://llm.example.com/v1',
    model: 'test-model',
    enabled: true,
  );

  test('规则优化只接受已声明且范围内的参数', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer secret');
      expect(request.url.path, '/v1/chat/completions');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'optimizedSummary': '优化摘要',
                    'optimizedDescription': '优化说明',
                    'parameterSuggestions': {
                      'maDays': 10,
                      'hugeVolumeRatio': 99,
                      'unknown': 1,
                    },
                    'reasons': ['降低噪声'],
                  }),
                },
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = LlmService(client: client);

    final draft = await service.optimizeRule(
      config: config,
      token: 'secret',
      rule: DefaultRules.create().first,
    );

    expect(draft.parameterSuggestions, {'maDays': 10});
    expect(draft.optimizedSummary, '优化摘要');
  });

  test('远程HTTP地址会被拒绝以保护Token', () {
    final service = LlmService(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(
      () => service.testConnection(
        const LlmConfig(
          baseUrl: 'http://unsafe.example.com',
          model: 'test',
          enabled: true,
        ),
        'secret',
      ),
      throwsA(isA<LlmException>()),
    );
  });
}
