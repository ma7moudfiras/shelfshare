/// Who a signed-in user is, and therefore what they may do.
///
/// Mirrors the `user_role` enum and `profiles` table in Postgres. The database
/// is the authority -- this type only reflects it. Nothing here grants access:
/// Row Level Security decides that server-side, so a tampered client sees
/// nothing extra.
enum UserRole {
  /// Signed in but not yet assigned to a company. Can read nothing.
  ///
  /// Anyone can sign in with Google, so this is the correct landing state:
  /// authentication is not authorisation.
  pending,

  /// Aystro staff. Not scoped to a company -- that is the point.
  platformAdmin,

  /// Manages one tenant: its users, stores, fridges and dashboards.
  companyAdmin,

  /// Visits assigned stores and records captures. No dashboards.
  salesRep;

  /// Parses the Postgres enum value, defaulting to the least-privileged role.
  ///
  /// An unrecognised role must never fall through to something permissive.
  static UserRole fromDb(String? value) => switch (value) {
    'platform_admin' => UserRole.platformAdmin,
    'company_admin' => UserRole.companyAdmin,
    'sales_rep' => UserRole.salesRep,
    _ => UserRole.pending,
  };

  String get dbValue => switch (this) {
    UserRole.platformAdmin => 'platform_admin',
    UserRole.companyAdmin => 'company_admin',
    UserRole.salesRep => 'sales_rep',
    UserRole.pending => 'pending',
  };

  String get label => switch (this) {
    UserRole.platformAdmin => 'Platform admin',
    UserRole.companyAdmin => 'Company admin',
    UserRole.salesRep => 'Sales representative',
    UserRole.pending => 'Awaiting access',
  };

  /// Whether this role can see anything at all yet.
  bool get hasAccess => this != UserRole.pending;

  bool get canManageCompany =>
      this == UserRole.companyAdmin || this == UserRole.platformAdmin;
}

/// A row from `profiles`, joined with its company name.
class UserProfile {
  final String id;
  final UserRole role;

  /// Null for platform admins (deliberately unscoped) and for pending users
  /// (not yet assigned).
  final String? companyId;
  final String? companyName;

  final String? fullName;
  final String? email;
  final bool isActive;

  /// Company this user has *asked* to join, while still pending.
  ///
  /// Deliberately separate from [companyId], which means granted. Reusing one
  /// field for both would make an unapproved request indistinguishable from
  /// membership.
  final String? requestedCompanyId;
  final String? requestedCompanyName;

  const UserProfile({
    required this.id,
    required this.role,
    this.companyId,
    this.companyName,
    this.fullName,
    this.email,
    this.isActive = true,
    this.requestedCompanyId,
    this.requestedCompanyName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // `companies` arrives as a nested object from the PostgREST join, or is
    // absent when the caller did not request it.
    final company = json['companies'];
    final requested = json['requested_company'];
    return UserProfile(
      id: json['id'] as String,
      role: UserRole.fromDb(json['role'] as String?),
      companyId: json['company_id'] as String?,
      companyName: company is Map ? company['name'] as String? : null,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      requestedCompanyId: json['requested_company_id'] as String?,
      requestedCompanyName: requested is Map
          ? requested['name'] as String?
          : null,
    );
  }

  /// Best available name for display, never null.
  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final address = email?.trim();
    if (address != null && address.isNotEmpty) return address.split('@').first;
    return 'User';
  }

  /// A deactivated user is treated as having no access regardless of role, so
  /// revoking someone does not require also changing their role.
  bool get canUseApp => isActive && role.hasAccess;

  /// Waiting on an admin, having already said which company they belong to.
  bool get hasRequestedAccess => requestedCompanyId != null;

  @override
  String toString() => 'UserProfile(${role.dbValue}, company: $companyName)';
}
