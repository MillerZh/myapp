import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_analysis.dart';
import '../models/app_settings.dart';
import '../models/candle.dart';
import '../models/rule.dart';
import '../models/signal.dart';
import '../models/stock.dart';

class LlmService {
  LlmService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> testConnection(LlmConfig config, String token) async {
    _validateConfig(config, token);
    await _chat(
      config,
      token,
      system: '你是连接测试助手，只回复 JSON。',
      user: '{"task":"请返回 {\\"ok\\":true}"}',
    );
  }

  Future<AiStockAnalysis> analyzeStock({
    required LlmConfig config,
    required String token,
    required StockQuote quote,
    required List<Candle> dailyCandles,
    required List<Candle> intradayBars,
    required List<TradeSignal> signals,
    Holding? holding,
  }) async {
    _validateConfig(config, token);
    final recent = dailyCandles.length > 20
        ? dailyCandles.sublist(dailyCandles.length - 20)
        : dailyCandles;
    final payload = {
      'stock': {
        'code': quote.code,
        'name': quote.name,
        'price': quote.price,
        'changePct': quote.changePct,
        'sector': quote.sector,
      },
      'holding': holding == null
          ? null
          : {
              'shares': holding.shares,
              'costPrice': holding.costPrice,
              'floatingPct': holding.costPrice == 0
                  ? 0
                  : (quote.price - holding.costPrice) / holding.costPrice * 100,
            },
      'daily': recent
          .map(
            (bar) => {
              'date': bar.date.toIso8601String(),
              'open': bar.open,
              'high': bar.high,
              'low': bar.low,
              'close': bar.close,
              'volume': bar.volume,
            },
          )
          .toList(),
      'intradaySummary': intradayBars.isEmpty
          ? null
          : {
              'dataAt': intradayBars.last.date.toIso8601String(),
              'open': intradayBars.first.open,
              'last': intradayBars.last.close,
              'high': intradayBars
                  .map((bar) => bar.high)
                  .reduce((a, b) => a > b ? a : b),
              'low': intradayBars
                  .map((bar) => bar.low)
                  .reduce((a, b) => a < b ? a : b),
            },
      'signals': signals
          .map(
            (signal) => {
              'rule': signal.disciplineName,
              'version': signal.ruleVersion,
              'title': signal.title,
              'reason': signal.reason,
              'advice': signal.advice,
              'score': signal.score,
              'dataAt': signal.dataAt?.toIso8601String(),
            },
          )
          .toList(),
    };
    final raw = await _chat(
      config,
      token,
      system: '''
你是A股交易纪律解释助手。你只能基于输入数据解释已存在的纪律信号，
不得编造行情、不得承诺收益、不得替用户做确定性买卖决定。
仅返回一个JSON对象，字段必须为：
summary字符串、riskLevel字符串（低/中/高/极高）、
disciplineExplanation字符串数组、conflicts字符串数组、
observations字符串数组、disclaimer字符串。
''',
      user: jsonEncode(payload),
    );
    return AiStockAnalysis.fromJson(_decodeJsonObject(raw));
  }

  Future<RuleOptimizationDraft> optimizeRule({
    required LlmConfig config,
    required String token,
    required RuleDefinition rule,
  }) async {
    _validateConfig(config, token);
    final raw = await _chat(
      config,
      token,
      system: '''
你是量化纪律文案与参数审查助手。只输出JSON，不得增加输入中不存在的参数键，
参数建议必须在每个参数的min和max之间。输出字段：
optimizedSummary字符串、optimizedDescription字符串、
parameterSuggestions对象、reasons字符串数组。
这是草稿，不得声称已自动生效。
''',
      user: jsonEncode(rule.toJson()),
    );
    final draft = RuleOptimizationDraft.fromJson(_decodeJsonObject(raw));
    final schema = {for (final item in rule.parameters) item.key: item};
    final safeValues = <String, double>{};
    for (final entry in draft.parameterSuggestions.entries) {
      final parameter = schema[entry.key];
      if (parameter == null) continue;
      if (entry.value >= parameter.min && entry.value <= parameter.max) {
        safeValues[entry.key] = entry.value;
      }
    }
    return RuleOptimizationDraft(
      optimizedSummary: draft.optimizedSummary,
      optimizedDescription: draft.optimizedDescription,
      parameterSuggestions: safeValues,
      reasons: draft.reasons,
    );
  }

  Future<String> _chat(
    LlmConfig config,
    String token, {
    required String system,
    required String user,
  }) async {
    final uri = _chatUri(config.baseUrl);
    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${token.trim()}',
            },
            body: jsonEncode({
              'model': config.model.trim(),
              'temperature': 0.2,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
            }),
          )
          .timeout(Duration(seconds: config.timeoutSeconds.clamp(10, 120)));
    } catch (error) {
      throw LlmException('大模型请求失败：$error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(
        '大模型服务返回 HTTP ${response.statusCode}。请检查 Base URL、模型名和 Token。',
      );
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final choices = body['choices'] as List;
      final message = choices.first['message'] as Map<String, dynamic>;
      final content = message['content'];
      if (content is String && content.trim().isNotEmpty) return content;
      throw const FormatException('content为空');
    } catch (_) {
      throw const LlmException('大模型响应格式不兼容 OpenAI Chat Completions。');
    }
  }

  Uri _chatUri(String rawBaseUrl) {
    var base = rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.endsWith('/chat/completions')) return Uri.parse(base);
    if (base.endsWith('/v1')) return Uri.parse('$base/chat/completions');
    return Uri.parse('$base/v1/chat/completions');
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final first = text.indexOf('{');
    final last = text.lastIndexOf('}');
    if (first < 0 || last <= first) {
      throw const LlmException('大模型没有返回可解析的 JSON。');
    }
    try {
      return Map<String, dynamic>.from(
        jsonDecode(text.substring(first, last + 1)) as Map,
      );
    } catch (_) {
      throw const LlmException('大模型返回的 JSON 格式无效，请重试。');
    }
  }

  void _validateConfig(LlmConfig config, String token) {
    final uri = Uri.tryParse(config.baseUrl.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const LlmException('Base URL 格式不正确。');
    }
    if (uri.scheme != 'https' &&
        uri.host != 'localhost' &&
        uri.host != '127.0.0.1') {
      throw const LlmException('为保护 Token，远程 Base URL 必须使用 HTTPS。');
    }
    if (config.model.trim().isEmpty) throw const LlmException('模型名不能为空。');
    if (token.trim().isEmpty) throw const LlmException('Token 不能为空。');
  }
}

class LlmException implements Exception {
  const LlmException(this.message);

  final String message;

  @override
  String toString() => message;
}
