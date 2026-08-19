import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_service.dart';
import '../payments/add_payment_sheet.dart';
import '../payments/payments_page.dart';
import '../receivables/add_receivable_sheet.dart';
import '../receivables/receivables_page.dart';

/// Single bottom-nav destination for money — what it shows depends on role:
///
/// - **Patron** sees both Alacaklar (receivables) and Tahsilatlar
///   (payments) as sub-tabs, mirroring the pattern already used by "İşler"
///   (Onay Bekleyen/Aktif/Tamamlanan). Keeps the bottom nav within the
///   5-item guideline instead of adding a 6th top-level tab.
/// - **Personel** only sees Tahsilatlar — alacak tracking (who owes how
///   much) is patron-only; personel can just log a payment they received.
class FinanceShellPage extends ConsumerWidget {
  const FinanceShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPatron =
        ref.watch(currentAppUserProvider).valueOrNull?.isPatron ?? false;
    return isPatron ? const _PatronFinanceView() : const _PersonelFinanceView();
  }
}

class _PersonelFinanceView extends StatelessWidget {
  const _PersonelFinanceView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tahsilat')),
      body: const PaymentsPage(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddPaymentSheet(context),
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
    final onReceivablesTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tahsilat'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Alacaklar'),
            Tab(text: 'Tahsilatlar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ReceivablesPage(), PaymentsPage()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => onReceivablesTab
            ? showAddReceivableSheet(context)
            : showAddPaymentSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
