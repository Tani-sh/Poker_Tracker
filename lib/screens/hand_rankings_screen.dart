import 'package:flutter/material.dart';

class _HandRank {
  final String name;
  final String description;
  final String example;
  final List<String> cards;
  final int rank;

  const _HandRank({
    required this.name,
    required this.description,
    required this.example,
    required this.cards,
    required this.rank,
  });
}

class HandRankingsScreen extends StatelessWidget {
  const HandRankingsScreen({super.key});

  static const List<_HandRank> _rankings = [
    _HandRank(
      rank: 1,
      name: 'Royal Flush',
      description: 'A, K, Q, J, 10 — all of the same suit',
      example: 'The best possible hand',
      cards: ['A♠', 'K♠', 'Q♠', 'J♠', '10♠'],
    ),
    _HandRank(
      rank: 2,
      name: 'Straight Flush',
      description: 'Five consecutive cards of the same suit',
      example: 'e.g. 5-6-7-8-9 of hearts',
      cards: ['9♥', '8♥', '7♥', '6♥', '5♥'],
    ),
    _HandRank(
      rank: 3,
      name: 'Four of a Kind',
      description: 'Four cards of the same rank',
      example: 'e.g. four Kings',
      cards: ['K♠', 'K♥', 'K♦', 'K♣', '2♠'],
    ),
    _HandRank(
      rank: 4,
      name: 'Full House',
      description: 'Three of a kind + a pair',
      example: 'e.g. three Aces and two 8s',
      cards: ['A♠', 'A♥', 'A♦', '8♣', '8♠'],
    ),
    _HandRank(
      rank: 5,
      name: 'Flush',
      description: 'Five cards of the same suit, not in sequence',
      example: 'e.g. 2, 5, 7, 10, K of diamonds',
      cards: ['K♦', '10♦', '7♦', '5♦', '2♦'],
    ),
    _HandRank(
      rank: 6,
      name: 'Straight',
      description: 'Five consecutive cards of different suits',
      example: 'e.g. 4-5-6-7-8 mixed suits',
      cards: ['8♣', '7♦', '6♠', '5♥', '4♣'],
    ),
    _HandRank(
      rank: 7,
      name: 'Three of a Kind',
      description: 'Three cards of the same rank',
      example: 'e.g. three Jacks',
      cards: ['J♠', 'J♥', 'J♦', '9♣', '4♠'],
    ),
    _HandRank(
      rank: 8,
      name: 'Two Pair',
      description: 'Two different pairs',
      example: 'e.g. two 10s and two 5s',
      cards: ['10♠', '10♥', '5♦', '5♣', 'K♠'],
    ),
    _HandRank(
      rank: 9,
      name: 'One Pair',
      description: 'Two cards of the same rank',
      example: 'e.g. two Queens',
      cards: ['Q♠', 'Q♥', '9♦', '6♣', '3♠'],
    ),
    _HandRank(
      rank: 10,
      name: 'High Card',
      description: 'No matching cards — highest card plays',
      example: 'Weakest hand — only the highest card matters',
      cards: ['A♠', 'J♦', '8♣', '5♥', '2♠'],
    ),
  ];

  static Color _staticGetRankColor(int rank) {
    if (rank <= 2) return Colors.amber;
    if (rank <= 4) return Colors.deepOrangeAccent;
    if (rank <= 6) return Colors.tealAccent;
    if (rank <= 8) return Colors.blueAccent;
    return Colors.grey;
  }

  Color _getRankColor(int rank) => _staticGetRankColor(rank);

  /// Builds just the rankings list widget (for embedding in bottom sheets).
  static Widget buildRankingsList({ScrollController? scrollController}) {
    return _HandRankingsListView(scrollController: scrollController);
  }

  Color _getCardColor(String card) {
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red.shade400;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hand Rankings"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _rankings.length,
        itemBuilder: (context, index) {
          final hand = _rankings[index];
          final rankColor = _getRankColor(hand.rank);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: hand.rank <= 3 ? 6 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: hand.rank <= 3
                  ? BorderSide(color: rankColor.withValues(alpha: 0.5), width: 1.5)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: rank badge + name
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '#${hand.rank}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: rankColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hand.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hand.rank <= 2 ? rankColor : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Card display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: hand.cards.map((card) {
                      final cardColor = _getCardColor(card);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 52,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(1, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            card,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: cardColor == Colors.white
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : cardColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  // Description
                  Text(
                    hand.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Standalone list view of hand rankings for embedding in bottom sheets.
class _HandRankingsListView extends StatelessWidget {
  final ScrollController? scrollController;
  const _HandRankingsListView({this.scrollController});

  Color _getRankColor(int rank) => HandRankingsScreen._staticGetRankColor(rank);

  Color _getCardColor(String card) {
    if (card.contains('♥') || card.contains('♦')) return Colors.red.shade400;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: HandRankingsScreen._rankings.length,
      itemBuilder: (context, index) {
        final hand = HandRankingsScreen._rankings[index];
        final rankColor = _getRankColor(hand.rank);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: hand.rank <= 3 ? 6 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: hand.rank <= 3 ? BorderSide(color: rankColor.withValues(alpha: 0.5), width: 1.5) : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('#${hand.rank}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: rankColor)))),
                const SizedBox(width: 12),
                Expanded(child: Text(hand.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hand.rank <= 2 ? rankColor : null))),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: hand.cards.map((card) {
                final cardColor = _getCardColor(card);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3), width: 52, height: 72,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(1, 2))],
                  ),
                  child: Center(child: Text(card, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: cardColor == Colors.white ? (isDark ? Colors.white : Colors.black87) : cardColor))),
                );
              }).toList()),
              const SizedBox(height: 10),
              Text(hand.description, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
            ]),
          ),
        );
      },
    );
  }
}
