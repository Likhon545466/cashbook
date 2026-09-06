# 🚀 CashBook Release Notes - v1.7.3 (Build 77)

**Release Date:** September 6, 2026  
**Build Target:** Android (Release APK `CashBook-v1.7.3-build77.apk`)

---

## 🌟 What's New in v1.7.3

### 1. ☁️ Google Cloud Sync & Automatic Backup
- **Google Drive Integration**: Sync your data privately and securely using Google Drive AppData folder storage.
- **Auto-Sync & Manual Trigger**: Automatically backup after adding or modifying transactions, or trigger on-demand backups anytime.
- **Account Management**: View connected account details (Name, Email, Profile Avatar) with 1-tap connect and disconnect options.

### 2. 🔁 Recurring & Fixed Transactions
- **Automated Templates**: Set up recurring income and expense items (Salary, House Rent, Utility Bills, Subscriptions, WiFi).
- **Due Alerts & Batch Processing**: Smart due banner alerts you when scheduled items are ready with 1-tap **"Apply All"** or individual **"Apply Entry"**.
- **Full Undo Support**: Easily undo applied recurring entries directly from the 3-dots menu or instant SnackBar action. Undoing automatically removes the recorded transaction from the ledger and restores the template's due status.

### 3. 📅 Granular Month & Custom Book Deletion
- **Safe Reset Options**: Reset specific months or custom project books without affecting your complete historical data.
- **Clear Confirmation Protection**: Double-check dialogs ensure no accidental data loss while giving you fine-grained control over your books.

### 4. 📄 PDF & Excel Statement Export
- **Professional PDF Reports**: Generate beautifully formatted PDF statements featuring summary totals, category breakdowns, and chronological transaction tables.
- **Spreadsheet / CSV Export**: One-tap export to CSV/Excel format for spreadsheet analysis and sharing.

### 5. ⏰ Smart Daily Expense Reminder
- **Scheduled Notifications**: Daily reminder (configurable time, default 9:00 PM) to help you build the habit of recording daily cashflow.

### 6. 🎨 Redesigned Quick Filter Chips
- **Semantic Theme Tints**: Soft pastel and vibrant tints tailored for `Income` (emerald green), `Expense` (rose red), `Book/Month` (theme primary), and `All` (neutral surface).
- **Polished Aesthetics**: Eliminated stark plain white backgrounds and harsh white borders in both Light and Dark modes with smooth micro-animations.

---

## 🛠 Quality & Performance Improvements
- 🧪 **100% Test Coverage**: All 61 unit, service, model, and widget tests passing.
- ⚡ **Zero Static Analysis Warnings**: Clean pass on `flutter analyze`.
- 🔒 **Enhanced Data Integrity**: Safe database transactions and isolated monthly ledgers.
