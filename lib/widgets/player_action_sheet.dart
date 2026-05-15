import 'package:flutter/material.dart';
import '../models/game_player_model.dart';
import '../utils/app_settings.dart';

/// Bottom sheet for player actions: buy-in, cash-out, undo, transaction history.
class PlayerActionSheet {

  static void show(
    BuildContext context, {
    required GamePlayer gamePlayer,
    required void Function(GamePlayer, int) addBuyIn,
    required void Function(GamePlayer) showCashOutDialog,
    required void Function(GamePlayer) undoBuyIn,
    required void Function(GamePlayer) undoCashOut,
    required void Function(GamePlayer) showCustomBuyIn,
  }) {
    final cs = AppSettings.currencySymbol;
    final rebuyDenoms = AppSettings.rebuyDenominations;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Player header
              Row(
                children: [
                  Text(gamePlayer.player.emoji,
                      style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(gamePlayer.player.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(
                          gamePlayer.hasCashedOut
                              ? 'Cashed out: $cs${gamePlayer.cashOutAmount}'
                              : 'Total buy-in: $cs${gamePlayer.totalBuyIn}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  if (gamePlayer.hasCashedOut)
                    Text(
                      '${gamePlayer.netProfit >= 0 ? '+' : ''}$cs${gamePlayer.netProfit}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: gamePlayer.netProfit >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),

              // Transaction history
              if (gamePlayer.buyIns.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Transactions',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500)),
                ),
                const SizedBox(height: 8),
                ...gamePlayer.buyIns.asMap().entries.map((e) {
                      final isNegative = e.value < 0;
                      final title = isNegative 
                          ? '  Lent Chips' 
                          : (e.key == 0 ? '  Initial Buy-in' : '  Re-buy #${e.key}');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(title),
                            Text(
                              isNegative ? '-$cs${e.value.abs()}' : '+$cs${e.value}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isNegative ? Colors.orangeAccent : Colors.white,
                              )
                            ),
                          ],
                        ),
                      );
                    }),
                const Divider(height: 20),
              ],

              // Action buttons
              if (gamePlayer.hasCashedOut)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo Cash Out'),
                    onPressed: () {
                      undoCashOut(gamePlayer);
                      Navigator.of(ctx).pop();
                    },
                  ),
                )
              else ...[
                // Re-buy buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...rebuyDenoms.map((d) => ElevatedButton(
                          onPressed: () {
                            addBuyIn(gamePlayer, d);
                            Navigator.of(ctx).pop();
                          },
                          child: Text('+$cs$d'),
                        )),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        showCustomBuyIn(gamePlayer);
                      },
                      child: const Text('+Custom'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Cash Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          showCashOutDialog(gamePlayer);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.undo),
                      tooltip: 'Undo Last Buy-in',
                      onPressed: () {
                        undoBuyIn(gamePlayer);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
