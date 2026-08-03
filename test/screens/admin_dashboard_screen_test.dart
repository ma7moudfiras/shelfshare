import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/company_option.dart';
import 'package:shelf_monitor/models/user_profile.dart';
import 'package:shelf_monitor/screens/admin_dashboard_screen.dart';
import 'package:shelf_monitor/screens/visit_start_screen.dart';
import 'package:shelf_monitor/services/admin_service.dart';

import '../support/fake_services.dart';
import 'auth_gate_test.dart' show FakeAuthService;

class FakeAdminService implements AdminService {
  List<UserProfile> requests;
  List<UserProfile> memberList;
  List<CompanyOption> companyList;

  /// Set to make the next load fail, as an unreachable database would.
  String? failWith;

  final approvals = <({String id, UserRole role})>[];
  final declines = <String>[];
  final activations = <({String id, bool active})>[];
  final createdCompanies = <String>[];

  FakeAdminService({
    this.requests = const [],
    this.memberList = const [],
    this.companyList = const [],
  });

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw AdminFailure(failure);
  }

  @override
  Future<List<UserProfile>> pendingRequests() async {
    _maybeFail();
    return requests;
  }

  @override
  Future<List<UserProfile>> members() async {
    _maybeFail();
    return memberList;
  }

  @override
  Future<List<CompanyOption>> companies() async {
    _maybeFail();
    return companyList;
  }

  @override
  Future<void> approve(String userId, UserRole role) async {
    approvals.add((id: userId, role: role));
    requests = requests.where((r) => r.id != userId).toList();
  }

  @override
  Future<void> decline(String userId) async {
    declines.add(userId);
    requests = requests.where((r) => r.id != userId).toList();
  }

  @override
  Future<void> setActive(String userId, bool isActive) async {
    activations.add((id: userId, active: isActive));
  }

  @override
  Future<void> createCompany(String name) async => createdCompanies.add(name);
}

UserProfile requester(String id, String email, {String? company}) =>
    UserProfile(
      id: id,
      role: UserRole.pending,
      email: email,
      requestedCompanyId: 'c-unipal',
      requestedCompanyName: company ?? 'UniPal',
    );

UserProfile person(
  UserRole role, {
  required String id,
  String? companyId,
  String? companyName,
  String email = 'someone@example.com',
  String? fullName,
  bool isActive = true,
}) => UserProfile(
  id: id,
  role: role,
  companyId: companyId,
  companyName: companyName,
  fullName: fullName,
  email: email,
  isActive: isActive,
);

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<FakeAdminService> pump(
    WidgetTester tester, {
    required UserProfile admin,
    FakeAdminService? service,
    FakeMarketService? markets,
    FakeVisitService? visits,
  }) async {
    final adminService = service ?? FakeAdminService();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          profile: admin,
          authService: FakeAuthService(),
          adminService: adminService,
          marketService: markets ?? FakeMarketService(),
          visitService: visits ?? FakeVisitService(),
        ),
      ),
    );
    await settle(tester);
    return adminService;
  }

  final companyAdmin = person(
    UserRole.companyAdmin,
    id: 'admin-1',
    companyId: 'c-unipal',
    companyName: 'UniPal',
    email: 'admin@unipal.com',
    fullName: 'UniPal Admin',
  );
  final platformAdmin = person(
    UserRole.platformAdmin,
    id: 'admin-0',
    email: 'admin@shelfshare.com',
    fullName: 'Aystro Admin',
  );

  group('access requests', () {
    testWidgets('lists who is waiting, with their email', (tester) async {
      await pump(
        tester,
        admin: companyAdmin,
        service: FakeAdminService(
          requests: [requester('u1', 'rep@unipal.com')],
        ),
      );

      expect(find.text('rep@unipal.com'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('approving asks which role, and reports the choice', (
      tester,
    ) async {
      final service = await pump(
        tester,
        admin: companyAdmin,
        service: FakeAdminService(
          requests: [requester('u1', 'rep@unipal.com')],
        ),
      );

      await tester.tap(find.text('Approve'));
      await settle(tester);

      // Both roles are offered rather than one being assumed.
      expect(find.text('Approve as sales representative'), findsOneWidget);
      expect(find.text('Approve as company admin'), findsOneWidget);

      await tester.tap(find.text('Approve as sales representative'));
      await settle(tester);

      expect(service.approvals, hasLength(1));
      expect(service.approvals.single.id, 'u1');
      expect(service.approvals.single.role, UserRole.salesRep);
    });

    testWidgets('declining asks first, and does nothing if cancelled', (
      tester,
    ) async {
      final service = await pump(
        tester,
        admin: companyAdmin,
        service: FakeAdminService(
          requests: [requester('u1', 'rep@unipal.com')],
        ),
      );

      await tester.tap(find.text('Decline'));
      await settle(tester);
      expect(find.text('Decline this request?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(service.declines, isEmpty);
    });

    testWidgets('confirming a decline calls through', (tester) async {
      final service = await pump(
        tester,
        admin: companyAdmin,
        service: FakeAdminService(
          requests: [requester('u1', 'rep@unipal.com')],
        ),
      );

      await tester.tap(find.text('Decline'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
      await settle(tester);

      expect(service.declines, ['u1']);
    });

    testWidgets('an empty queue explains itself', (tester) async {
      await pump(tester, admin: companyAdmin);
      expect(find.text('No one is waiting'), findsOneWidget);
    });

    testWidgets('a company admin is not shown which company', (tester) async {
      // They only ever see their own, so the label would be noise.
      await pump(
        tester,
        admin: companyAdmin,
        service: FakeAdminService(
          requests: [requester('u1', 'rep@unipal.com')],
        ),
      );
      expect(find.textContaining('Asking to join'), findsNothing);
    });

    testWidgets('a platform admin is shown which company', (tester) async {
      await pump(
        tester,
        admin: platformAdmin,
        service: FakeAdminService(
          requests: [requester('u1', 'rep@unipal.com')],
        ),
      );
      expect(find.textContaining('Asking to join UniPal'), findsOneWidget);
    });
  });

  group('team', () {
    testWidgets('an admin cannot switch off their own account', (tester) async {
      // Doing so would lock them out of the only screen that could undo it.
      await pump(
        tester,
        admin: companyAdmin,
        service: FakeAdminService(memberList: [companyAdmin]),
      );

      await tester.tap(find.text('Team'));
      await settle(tester);

      expect(find.text('(you)'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('deactivating someone else calls through', (tester) async {
      final rep = person(
        UserRole.salesRep,
        id: 'u2',
        companyId: 'c-unipal',
        companyName: 'UniPal',
        email: 'rep@unipal.com',
      );
      final service = await pump(
        tester,
        admin: companyAdmin,
        service: FakeAdminService(memberList: [rep]),
      );

      await tester.tap(find.text('Team'));
      await settle(tester);
      await tester.tap(find.byType(Switch));
      await settle(tester);

      expect(service.activations, hasLength(1));
      expect(service.activations.single.id, 'u2');
      expect(service.activations.single.active, isFalse);
    });
  });

  group('role decides what is offered', () {
    testWidgets('only a platform admin gets the Companies tab', (tester) async {
      await pump(tester, admin: companyAdmin);
      expect(find.text('Companies'), findsNothing);

      await pump(tester, admin: platformAdmin);
      expect(find.text('Companies'), findsOneWidget);
    });

    testWidgets('a platform admin can add a company', (tester) async {
      final service = await pump(
        tester,
        admin: platformAdmin,
        service: FakeAdminService(
          companyList: const [CompanyOption(id: 'c-unipal', name: 'UniPal')],
        ),
      );

      await tester.tap(find.text('Companies'));
      await settle(tester);
      await tester.tap(find.text('Add company'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'NPC');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      expect(service.createdCompanies, ['NPC']);
    });

    testWidgets('adding is disabled until a name is typed', (tester) async {
      await pump(tester, admin: platformAdmin);

      await tester.tap(find.text('Companies'));
      await settle(tester);
      await tester.tap(find.text('Add company'));
      await settle(tester);

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
            .onPressed,
        isNull,
      );
    });
  });

  testWidgets('a failed load explains itself and offers a retry', (
    tester,
  ) async {
    final service = FakeAdminService()..failWith = 'Could not load the team.';
    await pump(tester, admin: companyAdmin, service: service);

    expect(find.text('Could not load the team.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    service.failWith = null;
    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('No one is waiting'), findsOneWidget);
  });

  group('recording a visit', () {
    // The complaint this exists for: the camera button opened a bare capture
    // screen, so an admin photographed a shelf, got a number, and had nowhere
    // to submit it -- the capture had no fridge to belong to.
    testWidgets('the camera button goes through a market, not the camera', (
      tester,
    ) async {
      await pump(
        tester,
        admin: companyAdmin,
        visits: FakeVisitService(marketList: [market()]),
      );

      await tester.tap(find.byTooltip('Record a visit'));
      await settle(tester);

      expect(find.byType(VisitStartScreen), findsOneWidget);
      expect(find.text('Record a visit'), findsWidgets);
      expect(find.text('Carrefour City'), findsOneWidget);
    });

    // Sign-out belongs to the root screen a rep lands on, not to a route
    // pushed on top of a dashboard that already has one.
    testWidgets('the pushed visit screen offers no second sign out', (
      tester,
    ) async {
      await pump(
        tester,
        admin: companyAdmin,
        visits: FakeVisitService(marketList: [market()]),
      );

      await tester.tap(find.byTooltip('Record a visit'));
      await settle(tester);

      expect(find.byTooltip('Sign out'), findsNothing);
    });

    testWidgets('an admin with no markets is told how to make one', (
      tester,
    ) async {
      await pump(tester, admin: companyAdmin, visits: FakeVisitService());

      await tester.tap(find.byTooltip('Record a visit'));
      await settle(tester);

      expect(find.textContaining('Add a market'), findsOneWidget);
    });
  });
}
