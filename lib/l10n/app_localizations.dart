import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ml.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ml'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Manikutti Finance'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @bills.
  ///
  /// In en, this message translates to:
  /// **'Bills & Utilities'**
  String get bills;

  /// No description provided for @homeLoan.
  ///
  /// In en, this message translates to:
  /// **'Home Loan'**
  String get homeLoan;

  /// No description provided for @smartScan.
  ///
  /// In en, this message translates to:
  /// **'Smart Scan'**
  String get smartScan;

  /// No description provided for @screenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshots;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get addTransaction;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @scanReceipt.
  ///
  /// In en, this message translates to:
  /// **'Scan Receipt'**
  String get scanReceipt;

  /// No description provided for @recharge.
  ///
  /// In en, this message translates to:
  /// **'Recharge'**
  String get recharge;

  /// No description provided for @electricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get electricity;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @internet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get internet;

  /// No description provided for @grocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get grocery;

  /// No description provided for @shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// No description provided for @fuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get fuel;

  /// No description provided for @medical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get medical;

  /// No description provided for @entertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get entertainment;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @loansAndEmi.
  ///
  /// In en, this message translates to:
  /// **'Loans & EMI'**
  String get loansAndEmi;

  /// No description provided for @loans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get loans;

  /// No description provided for @emis.
  ///
  /// In en, this message translates to:
  /// **'EMIs & Commitments'**
  String get emis;

  /// No description provided for @activeEmis.
  ///
  /// In en, this message translates to:
  /// **'Active EMIs'**
  String get activeEmis;

  /// No description provided for @familyLoans.
  ///
  /// In en, this message translates to:
  /// **'Family Loans'**
  String get familyLoans;

  /// No description provided for @addLoan.
  ///
  /// In en, this message translates to:
  /// **'Add Loan'**
  String get addLoan;

  /// No description provided for @addEmi.
  ///
  /// In en, this message translates to:
  /// **'Add EMI'**
  String get addEmi;

  /// No description provided for @repaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Repayment History'**
  String get repaymentHistory;

  /// No description provided for @addRepayment.
  ///
  /// In en, this message translates to:
  /// **'Add Repayment'**
  String get addRepayment;

  /// No description provided for @principalPaid.
  ///
  /// In en, this message translates to:
  /// **'Principal Paid'**
  String get principalPaid;

  /// No description provided for @interestPaid.
  ///
  /// In en, this message translates to:
  /// **'Interest Paid'**
  String get interestPaid;

  /// No description provided for @remainingBalance.
  ///
  /// In en, this message translates to:
  /// **'Remaining Balance'**
  String get remainingBalance;

  /// No description provided for @noRepaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No repayments logged yet'**
  String get noRepaymentsYet;

  /// No description provided for @mobileRecharges.
  ///
  /// In en, this message translates to:
  /// **'Mobile Recharges'**
  String get mobileRecharges;

  /// No description provided for @mobileRecharge.
  ///
  /// In en, this message translates to:
  /// **'Mobile Recharge'**
  String get mobileRecharge;

  /// No description provided for @addMobileRecharge.
  ///
  /// In en, this message translates to:
  /// **'Add Mobile Recharge'**
  String get addMobileRecharge;

  /// No description provided for @editMobileRecharge.
  ///
  /// In en, this message translates to:
  /// **'Edit Mobile Recharge'**
  String get editMobileRecharge;

  /// No description provided for @validityTill.
  ///
  /// In en, this message translates to:
  /// **'Validity Till'**
  String get validityTill;

  /// No description provided for @planLastRecharged.
  ///
  /// In en, this message translates to:
  /// **'Plan Last Recharged'**
  String get planLastRecharged;

  /// No description provided for @operator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get operator;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @personName.
  ///
  /// In en, this message translates to:
  /// **'Contact / SIM Name'**
  String get personName;

  /// No description provided for @rechargeNow.
  ///
  /// In en, this message translates to:
  /// **'Recharge Now'**
  String get rechargeNow;

  /// No description provided for @rechargedToday.
  ///
  /// In en, this message translates to:
  /// **'Recharged Today'**
  String get rechargedToday;

  /// No description provided for @markRecharged.
  ///
  /// In en, this message translates to:
  /// **'Mark Recharged'**
  String get markRecharged;

  /// No description provided for @bankStatement.
  ///
  /// In en, this message translates to:
  /// **'Bank Statement'**
  String get bankStatement;

  /// No description provided for @uploadBankStatement.
  ///
  /// In en, this message translates to:
  /// **'Upload Bank Statement'**
  String get uploadBankStatement;

  /// No description provided for @noStatementSelected.
  ///
  /// In en, this message translates to:
  /// **'Please select a bank statement (.pdf, .csv)'**
  String get noStatementSelected;

  /// No description provided for @transactionsFound.
  ///
  /// In en, this message translates to:
  /// **'Transactions Found'**
  String get transactionsFound;

  /// No description provided for @duplicatesFiltered.
  ///
  /// In en, this message translates to:
  /// **'Duplicates Filtered'**
  String get duplicatesFiltered;

  /// No description provided for @readyToImport.
  ///
  /// In en, this message translates to:
  /// **'Ready to Import'**
  String get readyToImport;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @importTransactions.
  ///
  /// In en, this message translates to:
  /// **'Import Transactions'**
  String get importTransactions;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About This App'**
  String get aboutApp;

  /// No description provided for @featuresGuide.
  ///
  /// In en, this message translates to:
  /// **'Features & Guides'**
  String get featuresGuide;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get whatsNew;

  /// No description provided for @viewTutorial.
  ///
  /// In en, this message translates to:
  /// **'View Tutorial'**
  String get viewTutorial;

  /// No description provided for @tryFeatureNow.
  ///
  /// In en, this message translates to:
  /// **'Try Feature Now'**
  String get tryFeatureNow;

  /// No description provided for @appInformation.
  ///
  /// In en, this message translates to:
  /// **'App Information'**
  String get appInformation;

  /// No description provided for @aboutAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore every feature, screenshot guides & upcoming tools'**
  String get aboutAppSubtitle;

  /// No description provided for @whatsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latest features and improvements'**
  String get whatsNewSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ml'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ml':
      return AppLocalizationsMl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
