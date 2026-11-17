class Member {
  const Member({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.joinDate,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final DateTime? joinDate;

  factory Member.fromMap(Map<String, dynamic> m) => Member(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Miembro',
        email: m['email'] as String?,
        phone: m['phone'] as String?,
        joinDate: m['join_date'] == null
            ? null
            : DateTime.parse(m['join_date'] as String),
      );
}
