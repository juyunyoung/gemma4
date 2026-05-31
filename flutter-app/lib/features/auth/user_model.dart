class UserModel {
  final String username;
  final String role;
  final String accessToken;

  const UserModel({
    required this.username,
    required this.role,
    required this.accessToken,
  });

  bool get isReporter => true; // 모든 역할이 보고서 작성 가능
  bool get isTeamLeader =>
      role == 'team_leader' || role == 'department_head' || role == 'admin';
  bool get isDepartmentHead => role == 'department_head' || role == 'admin';
  bool get isAdmin => role == 'admin';
}
