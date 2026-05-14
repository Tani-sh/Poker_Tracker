# 🃏 Poker Tracker

A professional-grade, **100% offline** Flutter app for tracking home poker cash games. Manage buy-ins, settle debts with partial payments, analyze your poker career with graphs & achievements, and run tournaments — all on your phone with zero accounts required.

> **[📥 Download APK](./PokerTracker.apk)** — Install directly on any Android device.

---

## ✨ Feature Overview

### 🎮 Live Game Tracking
- **Round Table UI** — Immersive circular poker table with player avatars around a green felt, live pot total and elapsed timer in the center
- **List View Toggle** — Switch between table and card-based list view (preference saved)
- **Admin/Banker Lock** — 🔒 Hides buy-in/cash-out buttons when passing the phone around
- **Buy-in Management** — Track initial buy-ins, re-buys, and cash-outs per player
- **Custom Amounts** — Configurable default buy-in and re-buy button denominations
- **Mid-game Additions** — Add or create new players during an active game
- **Undo Support** — Undo buy-ins and cash-outs with one tap
- **Game Resume** — Close the app and resume your game later (persisted via Hive)
- **Overextension Warnings** — ⚠️ Red border + warning icon when a player's total buy-in exceeds 3× the default

### 📋 Activity Log (Audit Trail)
- **Timestamped feed** of every game action — buy-ins, rebuys, cash-outs, player joins, pot expenses
- Newest-first scrollable bottom sheet, accessible from the live game toolbar
- Resolves every "I only bought in once!" dispute instantly

### 🍕 Pot Expenses (Pizza Fund)
- Deduct communal expenses (pizza, drinks, dealer tips) from the pot during the game
- Final Chip Count balance calculation **accounts for deductions** — no more "₹500 missing" when money was pulled for food
- Logged in the activity log with timestamps

### 📊 Final Chip Count Sheet
- **Spreadsheet-style screen** when ending a game with columns: Player | Initial Buy-in | Re-buys | Total In | Final Chips
- **Live balance check** — status bar turns green when Total Out = Total In (balanced), orange/red if unbalanced
- **Already-cashed players** shown in grey rows with their amounts pre-filled
- **Pot expenses** shown in the totals row

### 💸 Game Status Overlay
- **DEEPEST IN** (red) — Players with the most money invested (highest risk, not "winning")
- **SAFEST POSITION** (green) — Players with the least invested (lowest risk)
- **CONFIRMED** — Players who already cashed out with actual +/- profit shown

### 📍 GPS Auto-Location
- **One-tap location detection** during game setup via GPS
- **Reverse geocoding** — Converts coordinates to readable addresses
- **Location history** — Previously used locations auto-suggested

---

## 💰 Financial Settlement System

### Debt Settlement (Who Owes Whom)
- **Smart algorithm** — Minimizes the number of transactions needed to settle all debts
- **Correct math**: `netProfit = cashOutAmount - totalBuyIn`
  - Negative profit = lost money = **debtor** (owes others)
  - Positive profit = won money = **creditor** (is owed)
  - Transactions flow FROM losers TO winners
- **Per-game** — Tap "Settle" on any game in history to see debts for that specific session
- **All-time** — "Outstanding Debts" on the home screen shows cumulative balance across all games

### Partial Payment Tracking
- **Record partial payments** — "Raj owes ₹500 → pays ₹100 now" → remaining shows ₹400
- **Persistent** — Payments survive app restarts (stored in Hive)
- **Payment notes** — Tag payments as "UPI", "Cash", "GPay" etc.
- **Payment history** — Tap any debt to see all recorded payments with timestamps and delete option
- **Progress bars** — Visual tracking per-debt and overall with a global progress bar
- **Smart sharing** — WhatsApp message includes partial payment status

### 🔒 Buy-in Limit (House Rules)
- Set a **maximum total buy-in** per player per game (e.g., ₹2000 max per night)
- App **blocks re-buys** with a red snackbar when a player would exceed the limit
- Configurable in Settings → House Rules

---

## 📈 Analytics & Stats

### 🏆 Home Screen Leaderboard
- **Top 5 rankings** — Horizontal scrolling cards with 🥇🥈🥉 medals
- **Cumulative sparklines** — Mini graphs showing each player's profit trend over time
- **Tap to drill down** — Tap any card to open their full Player Detail screen
- **Reactive** — Updates instantly when a game is saved

### Player Detail Screen
- **Profit Over Time graph** — Cumulative profit line chart across all games
- **Career statistics** — Games played, win rate %, avg profit/game, biggest win, biggest loss
- **🏅 Achievements** — Auto-awarded badges:
  - 🔥 **Hot Streak** — Won 3+ games in a row
  - 🦈 **Shark** — 60%+ win rate over 10+ games
  - 👑 **Dominator** — 80%+ win rate over 5+ games
  - 💰 **Big Score** — Won 5× the default buy-in in one game
  - 🐢 **Comeback King** — Biggest recovery after rebuying
  - 🎖️ **Veteran** — 20+ games played
  - 🎰 **Gambler** — Keeps playing despite <30% win rate
- **📊 Head-to-Head Stats** — See cumulative win/loss vs every opponent:
  ```
  🎭 Raj vs 🌟 Priya: 6 games · You: +₹1200 · Them: -₹800
  ```

### Stats Dashboard
- Total games, average duration, biggest wins/losses
- Most frequent players, favourite locations
- End-game player stats with historical context

### Player Ledger
- Lifetime leaderboard ranked by net profit
- Win rates and average profit per player
- CSV export with one tap

---

## 🔄 Recurring Group Presets

- **Save groups** — Create named presets (e.g., "Friday Boys") with a fixed player list, default buy-in, and location
- **Two-tap game start** — Select a preset and go, no setup needed
- **Stored in Hive** — Persists across app restarts

---

## 🏆 Tournament Timer

- **Blind timer** — Configurable level durations (10/15/20/30 min)
- **11 blind levels** — From 25/50 to 1000/2000
- **Auto-advance** — Automatically moves to the next level with audio cues

---

## 🃏 Hand Rankings Reference

- **Visual card display** — All 10 poker hand rankings with realistic card UI
- **Color-coded tiers** — Gold for premium hands, teal for mid-tier, grey for low-tier
- **Accessible everywhere** — Full-screen from the home dashboard, or as a bottom sheet during live games

---

## 📥📤 CSV Import & Export

- **Prominent action bar** at the top of Game History with large Import/Export buttons
- **Export game history** — Full history as CSV via the share sheet
- **Export player ledger** — Leaderboard stats as CSV
- **Export single game** — Share a single session's results
- **Smart CSV Import** — Fuzzy header matching supports varied column names (e.g., "Name", "Player Name", "Buy In", "Cashout", "Payout" all map correctly)
- **Import preview** — Shows resolved column mapping before importing
- **Auto player creation** — Players not in your roster are created automatically

---

## 👤 Player Management

- **Random emoji avatars** — 32 poker-themed options (🐺🦈🔥💎🐉👑 etc.)
- **Emoji customization** — Tap to change any player's avatar
- **Player rename** — Long-press to rename (with duplicate detection)
- **Archive/Unarchive** — Soft-delete without losing historical data
- **Game notes** — Record memorable hands per session

---

## ⚙️ Customization

| Setting | Options |
|---------|---------|
| Currency | ₹, $, €, £, ¥, ฿, chips |
| Default buy-in | Any amount |
| Re-buy buttons | Up to 4 custom denominations |
| Max buy-in/player | Unlimited or capped (e.g., ₹2000) |
| Theme | Dark / Light mode |
| View mode | Round table / List view |

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.x (Material 3) |
| Local Database | Hive (with code-gen adapters) |
| Charts | fl_chart |
| CSV | csv package |
| Location | geolocator + geocoding |
| Sharing | share_plus |
| File Import | file_picker |

---

## 📁 Project Structure

```
lib/
├── main.dart                        # App entry, Hive init, theme config
├── models/
│   ├── player_model.dart            # Player with name, emoji, archive
│   ├── game_player_model.dart       # In-game player: buy-ins, cash-out
│   ├── game_session_model.dart      # Completed game session
│   ├── group_preset_model.dart      # Recurring game group presets
│   ├── player_stat.dart             # Unified stat calculations (all-time + single-game)
│   └── payment_record_model.dart    # Persistent partial payment records
├── screens/
│   ├── home_screen.dart             # Dashboard + leaderboard
│   ├── game_setup_screen.dart       # Player selection, location, GPS
│   ├── live_game_screen.dart        # Round table + list, activity log, pot expenses
│   ├── end_game_screen.dart         # Results, split pot, export
│   ├── history_screen.dart          # Past games, CSV import/export bar
│   ├── manage_players_screen.dart   # CRUD + archive + emoji + rename
│   ├── player_ledger_screen.dart    # Lifetime leaderboard
│   ├── player_detail_screen.dart    # Stats, graph, achievements, H2H
│   ├── stats_dashboard_screen.dart  # Aggregate analytics
│   ├── settle_debts_screen.dart     # Debt settlement + partial payments
│   ├── blind_timer_screen.dart      # Tournament timer
│   ├── hand_rankings_screen.dart    # Poker hand hierarchy
│   └── settings_screen.dart         # Currency, buy-in, theme, house rules
├── widgets/
│   ├── poker_table_view.dart        # Circular table layout
│   └── player_action_sheet.dart     # Bottom sheet for player actions
└── utils/
    ├── app_settings.dart            # Settings, activity log, pot expenses
    └── csv_helper.dart              # CSV import/export with fuzzy matching
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Dart SDK (included with Flutter)
- Android SDK (for APK builds)

### Installation

```bash
git clone https://github.com/Tani-sh/Poker_Tracker.git
cd Poker_Tracker

flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Build APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Direct Install
Download the pre-built APK from `PokerTracker.apk` in the repo root.

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
