import 'package:hive/hive.dart';
import 'player_model.dart';

part 'game_player_model.g.dart';

@HiveType(typeId: 2)
class GamePlayer extends HiveObject {
  @HiveField(0)
  Player player;

  @HiveField(1)
  List<int> buyIns;

  @HiveField(2)
  int? cashOutAmount;

  @HiveField(3)
  bool hasCashedOut;

  @HiveField(4)
  DateTime? joinTime;

  GamePlayer({
    required this.player,
    required this.buyIns,
    this.cashOutAmount,
    this.hasCashedOut = false,
    this.joinTime,
  });

  int get totalBuyIn => buyIns.fold(0, (sum, item) => sum + item);
  int get netProfit => (cashOutAmount ?? 0) - totalBuyIn;

  void addBuyIn(int amount) {
    buyIns.add(amount);
    save();
  }

  void undoLastBuyIn() {
    if (buyIns.length > 1) {
      buyIns.removeLast();
      save();
    }
  }

  void cashOut(int amount) {
    cashOutAmount = amount;
    hasCashedOut = true;
    save();
  }

  // This new method allows reversing a cash-out action.
  void undoCashOut() {
    cashOutAmount = null;
    hasCashedOut = false;
    save();
  }
}
