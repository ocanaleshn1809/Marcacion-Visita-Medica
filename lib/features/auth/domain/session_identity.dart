import 'dart:convert';

class SessionIdentity {
  const SessionIdentity({required this.displayName, this.userId, this.email});

  factory SessionIdentity.fromToken(String token) {
    try {
      final segments = token.split('.');
      if (segments.length != 3) {
        return const SessionIdentity(displayName: 'Visitador');
      }
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(segments[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      final name = _firstText(claims, [
        'full_name',
        'name',
        'username',
        'email',
      ]);
      return SessionIdentity(
        displayName: name ?? 'Visitador',
        userId: _asInt(claims['user_id']),
        email: claims['email'] as String?,
      );
    } catch (_) {
      return const SessionIdentity(displayName: 'Visitador');
    }
  }

  final String displayName;
  final int? userId;
  final String? email;

  static String? _firstText(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
