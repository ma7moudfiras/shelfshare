import 'package:flutter/material.dart';

import '../models/company_option.dart';
import '../models/user_profile.dart';
import 'empty_state.dart';

/// Aystro's customers, with how many people each one has.
///
/// The count is derived from the already-loaded member list rather than asked
/// for separately: a platform admin can see every profile anyway, so a second
/// round trip would buy nothing.
class CompanyList extends StatelessWidget {
  /// Null while loading.
  final List<CompanyOption>? companies;
  final List<UserProfile>? members;

  const CompanyList({
    super.key,
    required this.companies,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final items = companies;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.apartment_outlined,
        title: 'No companies yet',
        message:
            'Add a customer company before inviting anyone. People request '
            'access to a company, so there has to be one to ask for.',
      );
    }

    final counts = <String, int>{};
    for (final member in members ?? const <UserProfile>[]) {
      final id = member.companyId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final company = items[i];
        final count = counts[company.id] ?? 0;
        final theme = Theme.of(context);

        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.tertiaryContainer,
            child: Icon(
              Icons.apartment,
              size: 19,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          title: Text(
            company.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            count == 1 ? '1 person' : '$count people',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
