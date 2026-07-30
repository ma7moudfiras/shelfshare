import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company_option.dart';
import '../models/user_profile.dart';

/// Raised when an administrative action is refused or fails.
class AdminFailure implements Exception {
  final String message;
  const AdminFailure(this.message);

  @override
  String toString() => message;
}

/// Everything an administrator can do to people and companies.
///
/// Separate from [AuthService], which is about the *current* user. This is
/// about everyone else, and only ever succeeds for callers the database is
/// willing to let through -- nothing here is trusted to be an admin because
/// the UI said so.
abstract class AdminService {
  /// People who have asked to join a company and are still waiting.
  ///
  /// Scoped by RLS: a company admin sees only requests addressed to their own
  /// company, a platform admin sees all of them.
  Future<List<UserProfile>> pendingRequests();

  /// Everyone already granted access, within whatever scope the caller has.
  Future<List<UserProfile>> members();

  /// Companies. A company admin sees only their own.
  Future<List<CompanyOption>> companies();

  /// Grants access, attaching the user to the company they asked for.
  ///
  /// The company is never passed in: it comes from the request itself, so
  /// approving cannot move somebody into a different tenant.
  Future<void> approve(String userId, UserRole role);

  /// Refuses a request, returning the user to the state they were in before
  /// asking. They keep their account and can request again.
  Future<void> decline(String userId);

  /// Turns access on or off without changing anyone's role.
  Future<void> setActive(String userId, bool isActive);

  /// Adds a customer company. Platform admins only.
  Future<void> createCompany(String name);
}

class SupabaseAdminService implements AdminService {
  final SupabaseClient _client;

  SupabaseAdminService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Columns needed to render a person, including both company joins.
  ///
  /// The two joins are disambiguated by constraint name because `profiles` has
  /// two foreign keys to `companies` and PostgREST cannot guess which is meant.
  static const _profileColumns =
      'id, role, company_id, full_name, email, is_active, '
      'requested_company_id, requested_at, '
      'companies!profiles_company_id_fkey(name), '
      'requested_company:companies!profiles_requested_company_id_fkey(name)';

  Future<T> _guard<T>(Future<T> Function() action, String whatFailed) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      // The database's own message is the honest one here: it is what actually
      // refused, and it distinguishes "not allowed" from "no longer pending".
      throw AdminFailure(e.message);
    } catch (_) {
      throw AdminFailure('$whatFailed Check your connection and try again.');
    }
  }

  @override
  Future<List<UserProfile>> pendingRequests() => _guard(() async {
    final rows = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('role', 'pending')
        .not('requested_company_id', 'is', null)
        .order('requested_at');
    return rows.map(UserProfile.fromJson).toList();
  }, 'Could not load access requests.');

  @override
  Future<List<UserProfile>> members() => _guard(() async {
    final rows = await _client
        .from('profiles')
        .select(_profileColumns)
        .neq('role', 'pending')
        .order('role')
        .order('email');
    return rows.map(UserProfile.fromJson).toList();
  }, 'Could not load the team.');

  @override
  Future<List<CompanyOption>> companies() => _guard(() async {
    final rows = await _client
        .from('companies')
        .select('id, name')
        .order('name');
    return rows.map(CompanyOption.fromJson).toList();
  }, 'Could not load companies.');

  @override
  Future<void> approve(String userId, UserRole role) => _guard(
    () => _client.rpc<void>(
      'approve_access_request',
      params: {'target_user': userId, 'granted_role': role.dbValue},
    ),
    'Could not approve that request.',
  );

  @override
  Future<void> decline(String userId) => _guard(
    () => _client.rpc<void>(
      'decline_access_request',
      params: {'target_user': userId},
    ),
    'Could not decline that request.',
  );

  @override
  Future<void> setActive(String userId, bool isActive) => _guard(
    () => _client.from('profiles').update({'is_active': isActive}).eq(
      'id',
      userId,
    ),
    'Could not change that account.',
  );

  @override
  Future<void> createCompany(String name) => _guard(
    () => _client.from('companies').insert({'name': name.trim()}),
    'Could not add that company.',
  );
}
