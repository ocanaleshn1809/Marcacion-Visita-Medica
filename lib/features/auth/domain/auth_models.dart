class UnitAccess {
  const UnitAccess({
    required this.unitCode,
    required this.unitName,
    required this.roleCode,
    required this.roleName,
  });

  factory UnitAccess.fromJson(Map<String, dynamic> json) => UnitAccess(
    unitCode: json['unit_code'] as String? ?? '',
    unitName: json['unit_name'] as String? ?? '',
    roleCode: json['role_code'] as String? ?? '',
    roleName: json['role_name'] as String? ?? '',
  );

  final String unitCode;
  final String unitName;
  final String roleCode;
  final String roleName;
}

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.units,
    required this.requiresUnitSelection,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    accessToken: json['access_token'] as String? ?? '',
    units: (json['units'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UnitAccess.fromJson)
        .toList(),
    requiresUnitSelection: json['requires_unit_selection'] as bool? ?? false,
  );

  final String accessToken;
  final List<UnitAccess> units;
  final bool requiresUnitSelection;
}

class SelectedUnitResult {
  const SelectedUnitResult({
    required this.accessToken,
    required this.activeUnit,
    required this.activeRole,
  });

  factory SelectedUnitResult.fromJson(Map<String, dynamic> json) =>
      SelectedUnitResult(
        accessToken: json['access_token'] as String? ?? '',
        activeUnit: json['active_unit'] as String? ?? '',
        activeRole: json['active_role'] as String? ?? '',
      );

  final String accessToken;
  final String activeUnit;
  final String activeRole;
}

class UserSession {
  const UserSession({
    required this.accessToken,
    this.activeUnit,
    this.activeRole,
  });

  final String accessToken;
  final String? activeUnit;
  final String? activeRole;
}
