/// A company a pending user can request access to.
///
/// Only id and name: the picker needs nothing more, and this list is readable
/// by anyone who has signed in, so it carries the minimum.
class CompanyOption {
  final String id;
  final String name;

  const CompanyOption({required this.id, required this.name});

  factory CompanyOption.fromJson(Map<String, dynamic> json) => CompanyOption(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Unnamed company',
  );
}
