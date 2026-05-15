import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_player_model.dart';
import '../utils/app_settings.dart';

class PokerTableView extends StatelessWidget {
  final List<MapEntry<dynamic, GamePlayer>> players;
  final Duration elapsed;
  final String location;
  final bool isAdmin;
  final int defaultBuyIn;
  final void Function(GamePlayer) onPlayerTap;

  const PokerTableView({
    super.key,
    required this.players,
    required this.elapsed,
    required this.location,
    required this.isAdmin,
    required this.defaultBuyIn,
    required this.onPlayerTap,
  });

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppSettings.currencySymbol;
    final totalPot = players.fold<int>(0, (sum, e) => sum + e.value.totalBuyIn);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth - 24, constraints.maxHeight * 0.85); // 24px horizontal padding
        final tableRadius = size * 0.30;
        final seatRadius = size * 0.42;
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight * 0.45;

        return Stack(
          children: [
            // Table felt
            Positioned(
              left: centerX - tableRadius,
              top: centerY - tableRadius,
              child: Container(
                width: tableRadius * 2,
                height: tableRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF1B5E20).withValues(alpha: 0.9),
                      const Color(0xFF0D3B0E),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF5D4037), width: 8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('⏱ ${_formatElapsed(elapsed)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('$cs$totalPot',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('in play', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                    const SizedBox(height: 4),
                    const Text('📍', style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 1),
                    SizedBox(
                      width: tableRadius * 1.2,
                      child: Text(location, style: const TextStyle(color: Colors.white60, fontSize: 10),
                        overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, maxLines: 1),
                    ),
                  ],
                ),
              ),
            ),
            // Player seats
            ...players.asMap().entries.map((indexed) {
              final i = indexed.key;
              final entry = indexed.value;
              final gp = entry.value;
              final count = players.length;
              final angle = (2 * pi * i / count) - (pi / 2);
              final x = centerX + seatRadius * cos(angle);
              final y = centerY + seatRadius * sin(angle);
              final isOverextended = gp.totalBuyIn >= defaultBuyIn * 3 && !gp.hasCashedOut;

              return Positioned(
                left: (x - 36).clamp(4, constraints.maxWidth - 76),
                top: (y - 40).clamp(4, constraints.maxHeight - 90),
                child: GestureDetector(
                  onTap: isAdmin ? () => onPlayerTap(gp) : null,
                  child: _PlayerSeat(gamePlayer: gp, cs: cs, isOverextended: isOverextended),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _PlayerSeat extends StatelessWidget {
  final GamePlayer gamePlayer;
  final String cs;
  final bool isOverextended;

  const _PlayerSeat({required this.gamePlayer, required this.cs, required this.isOverextended});

  @override
  Widget build(BuildContext context) {
    final isCashedOut = gamePlayer.hasCashedOut;
    final profit = gamePlayer.netProfit;

    Color borderColor;
    if (isCashedOut) {
      borderColor = Colors.grey;
    } else if (isOverextended) {
      borderColor = Colors.red;
    } else {
      borderColor = profit >= 0 ? Colors.greenAccent : Colors.orangeAccent;
    }

    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCashedOut
                  ? Colors.grey.shade800
                  : Theme.of(context).colorScheme.primaryContainer,
              border: Border.all(color: borderColor, width: isOverextended ? 3.5 : 2.5),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: isOverextended ? 0.6 : 0.3),
                  blurRadius: isOverextended ? 12 : 8,
                ),
              ],
            ),
            child: Center(
              child: Text(gamePlayer.player.emoji,
                  style: TextStyle(fontSize: 24, color: isCashedOut ? Colors.grey : null)),
            ),
          ),
          const SizedBox(height: 4),
          Text(gamePlayer.player.name,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
              color: isCashedOut ? Colors.grey : Colors.white,
              decoration: isCashedOut ? TextDecoration.lineThrough : null),
            overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          if (isOverextended)
            Text('⚠️ $cs${gamePlayer.totalBuyIn}',
              style: const TextStyle(fontSize: 10, color: Colors.red), textAlign: TextAlign.center)
          else
            Text(isCashedOut ? 'Out' : '$cs${gamePlayer.totalBuyIn}',
              style: TextStyle(fontSize: 10, color: isCashedOut ? Colors.grey : Colors.tealAccent),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
