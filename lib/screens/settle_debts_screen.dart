import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/player_model.dart';
import '../models/payment_record_model.dart';
import '../models/player_stat.dart';
import '../utils/app_settings.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class SettlementTransaction {
  final Player from;
  final Player to;
  final int amount;

  SettlementTransaction({required this.from, required this.to, required this.amount});
}

class SettleDebtsScreen extends StatefulWidget {
  final List<PlayerStat> playerStats;
  final String? location;
  final DateTime? gameDate;

  const SettleDebtsScreen({super.key, required this.playerStats, this.location, this.gameDate});

  @override
  State<SettleDebtsScreen> createState() => _SettleDebtsScreenState();
}

class _SettleDebtsScreenState extends State<SettleDebtsScreen> {
  List<SettlementTransaction> _transactions = [];
  late final Box<PaymentRecord> _paymentsBox;

  @override
  void initState() {
    super.initState();
    _paymentsBox = Hive.box<PaymentRecord>('payments');
    _calculateSettlements();
  }

  void _calculateSettlements() {
    final debtors = widget.playerStats
        .where((s) => s.totalNetProfit < 0)
        .map((s) => {'player': s.player, 'amount': -s.totalNetProfit})
        .toList();

    final creditors = widget.playerStats
        .where((s) => s.totalNetProfit > 0)
        .map((s) => {'player': s.player, 'amount': s.totalNetProfit})
        .toList();

    final List<SettlementTransaction> calculated = [];

    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      final debtor = debtors.first;
      final creditor = creditors.first;
      final paymentAmount = (debtor['amount'] as int) < (creditor['amount'] as int)
          ? debtor['amount'] as int
          : creditor['amount'] as int;

      calculated.add(SettlementTransaction(
        from: debtor['player'] as Player,
        to: creditor['player'] as Player,
        amount: paymentAmount,
      ));

      debtor['amount'] = (debtor['amount'] as int) - paymentAmount;
      creditor['amount'] = (creditor['amount'] as int) - paymentAmount;
      if (debtor['amount'] == 0) debtors.removeAt(0);
      if (creditor['amount'] == 0) creditors.removeAt(0);
    }

    setState(() => _transactions = calculated);
  }

  /// Get total paid so far for a specific from→to pair
  int _getPaidForPair(String fromName, String toName) {
    return _paymentsBox.values
        .where((p) => p.fromPlayerName == fromName && p.toPlayerName == toName)
        .fold(0, (sum, p) => sum + p.amount);
  }

  /// Get all payment records for a from→to pair
  List<PaymentRecord> _getPaymentsForPair(String fromName, String toName) {
    return _paymentsBox.values
        .where((p) => p.fromPlayerName == fromName && p.toPlayerName == toName)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int get _totalDebt => _transactions.fold(0, (s, t) => s + t.amount);
  int get _totalPaid {
    int paid = 0;
    for (var t in _transactions) {
      paid += _getPaidForPair(t.from.name, t.to.name);
    }
    return paid;
  }
  int get _totalRemaining => _totalDebt - _totalPaid;

  void _recordPayment(SettlementTransaction t) {
    final cs = AppSettings.currencySymbol;
    final remaining = t.amount - _getPaidForPair(t.from.name, t.to.name);
    final amountCtrl = TextEditingController(text: remaining.toString());
    final noteCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('${t.from.emoji} ${t.from.name} pays ${t.to.emoji} ${t.to.name}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Owes: $cs${t.amount}  •  Paid so far: $cs${_getPaidForPair(t.from.name, t.to.name)}  •  Remaining: $cs$remaining',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        const SizedBox(height: 16),
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Payment amount',
            prefixText: '$cs ',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g., UPI, Cash, GPay',
            border: OutlineInputBorder(),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final amt = int.tryParse(amountCtrl.text) ?? 0;
          if (amt <= 0) return;
          final payment = PaymentRecord(
            fromPlayerName: t.from.name,
            toPlayerName: t.to.name,
            amount: amt,
            timestamp: DateTime.now(),
            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          );
          _paymentsBox.add(payment);
          // Fire-and-forget Firestore sync
          if (AuthService().isLoggedIn) {
            FirestoreService().syncPayment(payment);
          }
          Navigator.of(ctx).pop();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Recorded $cs$amt from ${t.from.name} to ${t.to.name}')));
        }, child: const Text('Record Payment')),
      ],
    ));
  }

  void _showPaymentHistory(SettlementTransaction t) {
    final cs = AppSettings.currencySymbol;
    final payments = _getPaymentsForPair(t.from.name, t.to.name);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('${t.from.emoji} ${t.from.name} → ${t.to.emoji} ${t.to.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Total debt: $cs${t.amount}  •  Paid: $cs${_getPaidForPair(t.from.name, t.to.name)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          const Divider(height: 20),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No payments recorded yet.', style: TextStyle(fontStyle: FontStyle.italic))),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.35),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: payments.length,
                itemBuilder: (_, i) {
                  final p = payments[i];
                  final date = '${p.timestamp.day}/${p.timestamp.month} ${p.timestamp.hour}:${p.timestamp.minute.toString().padLeft(2, '0')}';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    title: Text('$cs${p.amount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$date${p.note != null ? '  •  ${p.note}' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Delete payment',
                      onPressed: () {
                        p.delete();
                        Navigator.of(ctx).pop();
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment deleted.')));
                      },
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  void _shareSettlements() {
    final cs = AppSettings.currencySymbol;
    final buf = StringBuffer();
    buf.writeln('🃏 *Poker Night Settlements* 🃏');
    buf.writeln('');

    for (var t in _transactions) {
      final paid = _getPaidForPair(t.from.name, t.to.name);
      final remaining = t.amount - paid;
      if (remaining <= 0) {
        buf.writeln('✅ ${t.from.name} → ${t.to.name} — $cs${t.amount} (SETTLED)');
      } else if (paid > 0) {
        buf.writeln('💸 ${t.from.name} → ${t.to.name} — $cs$remaining remaining (paid $cs$paid)');
      } else {
        buf.writeln('💸 ${t.from.name} → ${t.to.name} — $cs${t.amount}');
      }
    }

    buf.writeln('');
    if (_totalRemaining <= 0) {
      buf.writeln('✅ All settled!');
    } else {
      buf.writeln('$cs$_totalPaid of $cs$_totalDebt paid · $cs$_totalRemaining remaining');
    }

    if (widget.location != null) {
      buf.writeln('📍 ${widget.location}');
    }
    buf.writeln('');
    buf.writeln('— sent from Poker Tracker 🎰');

    Share.share(buf.toString());
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppSettings.currencySymbol;
    final allSettled = _totalRemaining <= 0 && _transactions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location != null ? "Game Debts" : "Outstanding Debts"),
        actions: [
          if (_transactions.isNotEmpty)
            IconButton(icon: const Icon(Icons.share_outlined), onPressed: _shareSettlements, tooltip: 'Share'),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _paymentsBox.listenable(),
        builder: (context, _, __) {
          if (_transactions.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.celebration, size: 80,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text("Nobody owes anything! 🎉", style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
              ]),
            );
          }

          return Column(
            children: [
              // Summary bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: allSettled
                    ? Colors.green.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          allSettled ? '✅ All debts settled!' : '$cs$_totalPaid of $cs$_totalDebt paid',
                          style: TextStyle(fontWeight: FontWeight.bold, color: allSettled ? Colors.green : null),
                        ),
                        if (!allSettled)
                          Text('$cs$_totalRemaining left',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade300)),
                      ],
                    ),
                    if (!allSettled && _totalDebt > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _totalDebt > 0 ? _totalPaid / _totalDebt : 0,
                          backgroundColor: Colors.grey.shade800,
                          color: Colors.tealAccent,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    final paid = _getPaidForPair(t.from.name, t.to.name);
                    final remaining = t.amount - paid;
                    final isFullyPaid = remaining <= 0;
                    final progress = t.amount > 0 ? (paid / t.amount).clamp(0.0, 1.0) : 0.0;

                    return Card(
                      color: isFullyPaid ? Theme.of(context).cardColor.withValues(alpha: 0.5) : null,
                      child: InkWell(
                        onTap: () => _showPaymentHistory(t),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Who pays whom
                              Row(children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style.copyWith(
                                        fontSize: 15,
                                        decoration: isFullyPaid ? TextDecoration.lineThrough : null,
                                        color: isFullyPaid ? Colors.grey : null,
                                      ),
                                      children: [
                                        TextSpan(text: '${t.from.emoji} ${t.from.name}',
                                            style: TextStyle(fontWeight: FontWeight.bold,
                                                color: isFullyPaid ? Colors.grey : Colors.orangeAccent)),
                                        const TextSpan(text: '  →  '),
                                        TextSpan(text: '${t.to.emoji} ${t.to.name}',
                                            style: TextStyle(fontWeight: FontWeight.bold,
                                                color: isFullyPaid ? Colors.grey : Colors.lightGreenAccent)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Amount column
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('$cs${t.amount}',
                                    style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold,
                                      decoration: isFullyPaid ? TextDecoration.lineThrough : null,
                                      color: isFullyPaid ? Colors.grey : null)),
                                  if (paid > 0 && !isFullyPaid)
                                    Text('$cs$remaining left',
                                      style: const TextStyle(fontSize: 11, color: Colors.orange)),
                                ]),
                              ]),
                              // Progress bar + action
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey.shade800,
                                      color: isFullyPaid ? Colors.green : Colors.tealAccent,
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (!isFullyPaid)
                                  SizedBox(
                                    height: 30,
                                    child: FilledButton.tonal(
                                      onPressed: () => _recordPayment(t),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                      child: const Text('Pay'),
                                    ),
                                  )
                                else
                                  const Text('✅', style: TextStyle(fontSize: 18)),
                              ]),
                              // Show payment count
                              if (paid > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    isFullyPaid
                                        ? 'Settled • $cs$paid paid'
                                        : '$cs$paid paid so far • Tap for history',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
