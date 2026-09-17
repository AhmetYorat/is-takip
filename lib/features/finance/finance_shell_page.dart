import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_service.dart';
import '../expenses/add_expense_sheet.dart';
import '../expenses/expenses_page.dart';
import '../payments/add_payment_sheet.dart';
import '../payments/payments_page.dart';
import '../receivables/add_receivable_sheet.dart';
import '../receivables/receivables_page.dart';

/// Single bottom-nav destination for money — what it shows depends on role:
///
/// - **Patron** sees Alacaklar (receivables), Tahsilatlar (payments) and
///   Giderler (expenses) as sub-tabs, mirroring the pattern already used by
///   "İşler" (Onay Bekleyen/Aktif/Tamamlanan). Keeps the bottom nav within
///   the 5-item guideline instead of adding more top-level tabs.
/// - **Personel** only sees Tahsilatlar and Giderler — alacak tracking (who
///   owes how much) is patron-only; personel can log a payment they
///   received and their own expenses.
class FinanceShellPage extends ConsumerWidget {
  const FinanceShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPatron =
        ref.watch(currentAppUserProvider).valueOrNull?.isPatron ?? false;
    return isPatron ? const _PatronFinanceView() : const _PersonelFinanceView();
  }
}

class _PersonelFinanceView extends StatefulWidget {
  const _PersonelFinanceView();

  @override
  State<_PersonelFinanceView> createState() => _PersonelFinanceViewState();
}

class _PersonelFinanceViewState extends State<_PersonelFinanceView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onPaymentsTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finans'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tahsilatlar'),
            Tab(text: 'Giderler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [PaymentsPage(), ExpensesPage()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => onPaymentsTab
            ? showAddPaymentSheet(context)
            : showAddExpenseSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PatronFinanceView extends StatefulWidget {
  const _PatronFinanceView();

  @override
  State<_PatronFinanceView> createState() => _PatronFinanceViewState();
}

class _PatronFinanceViewState extends State<_PatronFinanceView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finans'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Alacaklar'),
            Tab(text: 'Tahsilatlar'),
            Tab(text: 'Giderler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ReceivablesPage(), PaymentsPage(), ExpensesPage()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => switch (_tabController.index) {
          0 => showAddReceivableSheet(context),
          1 => showAddPaymentSheet(context),
          _ => showAddExpenseSheet(context),
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
