import 'package:flutter/material.dart';
import '../models/app_feature_info.dart';

class AppFeaturesData {
  static const List<String> categories = [
    'All Features',
    'Voice & Widgets',
    'Banking & Statements',
    'Privacy & Security',
    'Family & Budget',
    'Upcoming Roadmap',
  ];

  static const List<AppFeature> features = [
    // 1. Voice Expense Logging
    AppFeature(
      id: 'voice_logging',
      title: 'Smart Voice Expense Logging',
      shortTagline: 'Speak naturally in Malayalam or English with zero typing',
      icon: Icons.mic_rounded,
      badge: 'New',
      category: 'Voice & Widgets',
      accentColor: Color(0xFF0F766E),
      userOverview:
          'Record daily expenses in seconds by simply talking to the app. You can speak naturally in Malayalam (മലയാളം), Manglish, or English. Manikutti intelligently identifies the amount, shop name or category, and date, saving it right away so you never forget small daily cash spending.',
      keyBenefits: [
        'Recognizes casual spoken phrases like "100 roopakku petrol adichu" or "Auto 60 rupees"',
        'Zero typing required — perfect for quick logging on the go',
        'Works smoothly even with noisy background environments',
        'Instant audio and visual feedback confirming your saved record',
      ],
      tutorialSteps: [
        TutorialStep(
          stepNumber: 1,
          title: 'Tap the Voice Microphone',
          instruction:
              'Tap the glowing emerald microphone icon at the top of your dashboard, or use the floating home screen button.',
          proTip:
              'You can switch between Malayalam and English with one tap inside the voice window.',
          mockupType: MockupType.voiceLogging,
        ),
        TutorialStep(
          stepNumber: 2,
          title: 'Speak Naturally',
          instruction:
              'Say your expense aloud. For example: "ഇന്ന് മീൻ വാങ്ങാൻ 250 രൂപ" or "Grocery 480 rupees".',
          proTip:
              'Mentioning the category or shop helps the app categorize your spending automatically.',
          mockupType: MockupType.voiceLogging,
        ),
        TutorialStep(
          stepNumber: 3,
          title: 'Instant Confirmation',
          instruction:
              'Watch your spoken words instantly turn into a neat transaction card with amount, shop name, and category.',
          proTip:
              'The transaction is saved immediately to your ledger and silently backed up to the cloud.',
          mockupType: MockupType.voiceLogging,
        ),
      ],
      actionLabel: 'Try Voice Logging',
      actionRouteId: 'voice_logging',
    ),

    // 2. Android Home Screen Widget
    AppFeature(
      id: 'home_widget',
      title: 'Home Screen Expense Widget',
      shortTagline:
          'Track spending and upcoming bills right from your home screen',
      icon: Icons.widgets_rounded,
      badge: 'New',
      category: 'Voice & Widgets',
      accentColor: Color(0xFF2563EB),
      userOverview:
          'Place a beautiful, glanceable card directly on your phone’s Android home screen. Check your month-to-date total spending, see upcoming mobile recharge and utility bill alerts, and tap the 1-touch microphone button to record expenses without opening the main app.',
      keyBenefits: [
        'Real-time total monthly expenses at a glance',
        'Early alerts for upcoming bills and expiring mobile validity',
        '1-Tap Voice button launches a quick floating voice overlay',
        'Clean, battery-friendly design matching modern Android themes',
      ],
      tutorialSteps: [
        TutorialStep(
          stepNumber: 1,
          title: 'Long-Press Your Home Screen',
          instruction:
              'Find an empty spot on your Android home screen, press and hold your finger until the wallpaper menu pops up, then tap "Widgets".',
          proTip:
              'Ensure your phone is unlocked and you have space for a 4x2 or 4x1 card.',
          mockupType: MockupType.homeScreenWidget,
        ),
        TutorialStep(
          stepNumber: 2,
          title: 'Select "Manikutti" from the List',
          instruction:
              'Scroll through the widget picker or type "Manikutti" into the search bar. Locate the "Manikutti Smart Expense" widget card.',
          proTip:
              'You can preview the card size before dropping it onto your screen.',
          mockupType: MockupType.homeScreenWidget,
        ),
        TutorialStep(
          stepNumber: 3,
          title: 'Drag & Drop onto Your Screen',
          instruction:
              'Hold and drag the widget onto your favorite screen position. Your live balance and 1-tap voice button are now always at your fingertips!',
          proTip:
              'Tapping the mic icon on the widget lets you speak an expense without opening the full app.',
          mockupType: MockupType.homeScreenWidget,
        ),
      ],
      actionLabel: 'View Home Screen Guide',
      actionRouteId: 'home_widget',
    ),

    // 3. Google Assistant & Quick Settings
    AppFeature(
      id: 'google_assistant',
      title: 'Google Assistant & Quick Shortcuts',
      shortTagline:
          'Log expenses hands-free with "Hey Google" or your notification shade',
      icon: Icons.assistant_rounded,
      badge: 'New',
      category: 'Voice & Widgets',
      accentColor: Color(0xFF7C3AED),
      userOverview:
          'Log transactions completely hands-free while driving, cooking, or multitasking. Simply activate Google Assistant with your voice or pull down your Android notification shade from any screen or lock screen to trigger quick voice recording.',
      keyBenefits: [
        'Works with natural voice commands via Google Assistant',
        'Quick Settings Tile in your notification shade for instant access from any app',
        'Non-intrusive floating dialog appears over your current screen without opening the full app',
        'Saves time when you only have one hand free',
      ],
      tutorialSteps: [
        TutorialStep(
          stepNumber: 1,
          title: 'Say "Hey Google"',
          instruction:
              'Activate Google Assistant on your phone by saying "Hey Google" or pressing and holding your power/home button.',
          proTip:
              'You can speak in English or Malayalam depending on your Google Assistant settings.',
          mockupType: MockupType.googleAssistant,
        ),
        TutorialStep(
          stepNumber: 2,
          title: 'Speak Your Command',
          instruction:
              'Say: "Log 250 rupees for groceries on Manikutti" or "മണിച്ചിട്ടിയിൽ 100 രൂപ പെട്രോൾ കുറിക്കുക".',
          proTip:
              'The app will pop up a subtle floating window, confirm your entry, and close cleanly.',
          mockupType: MockupType.googleAssistant,
        ),
        TutorialStep(
          stepNumber: 3,
          title: 'Add Quick Settings Tile',
          instruction:
              'Swipe down twice from the top of your phone screen to open Quick Settings -> Tap the pencil Edit icon -> Drag "Manikutti Mic" into your active toggles.',
          proTip:
              'Now you can record any expense with 1 tap from your lock screen or while inside any app!',
          mockupType: MockupType.googleAssistant,
        ),
      ],
      actionLabel: 'Test Voice Shortcut',
      actionRouteId: 'voice_logging',
    ),

    // 4. Bank Statement Upload
    AppFeature(
      id: 'bank_statement',
      title: 'Bank Statement Importer (PDF & CSV)',
      shortTagline:
          'Import monthly statements from SBI, Canara & others with duplicate protection',
      icon: Icons.account_balance_wallet_rounded,
      badge: 'New',
      category: 'Banking & Statements',
      accentColor: Color(0xFF059669),
      userOverview:
          'Tired of logging dozens of UPI payments one by one at the end of the month? Simply download your bank e-statement from your mobile banking app (SBI YONO, Canara ai1, HDFC, etc.) and let Manikutti import all debits and credits automatically. Smart duplicate detection ensures no transaction is ever counted twice.',
      keyBenefits: [
        'Supports standard PDF and CSV bank e-statements',
        'Intelligent duplicate detection automatically skips already recorded transactions',
        'Password-protected bank PDFs are decrypted safely on your device',
        'Review and customize categories before confirming the import',
      ],
      tutorialSteps: [
        TutorialStep(
          stepNumber: 1,
          title: 'Download Your e-Statement',
          instruction:
              'Open your bank mobile app (SBI YONO, Canara ai1, etc.) or net banking, and download your monthly account statement as a PDF or CSV file.',
          proTip:
              'Most banking apps let you email the PDF statement to yourself or save it in Downloads.',
          mockupType: MockupType.bankStatement,
        ),
        TutorialStep(
          stepNumber: 2,
          title: 'Select Statement in Manikutti',
          instruction:
              'Open the side menu in Manikutti -> Tap "Bank Statement" -> Tap "Choose Statement File" and pick the downloaded file.',
          proTip:
              'If your bank PDF is password protected (e.g., DOB or mobile digits), enter your password securely.',
          mockupType: MockupType.bankStatement,
        ),
        TutorialStep(
          stepNumber: 3,
          title: 'Review & Import',
          instruction:
              'The smart reader highlights new transactions and displays how many duplicates were safely filtered. Tap "Import Transactions" to add them to your ledger.',
          proTip:
              'You can uncheck individual entries or adjust categories before importing.',
          mockupType: MockupType.bankStatement,
        ),
      ],
      actionLabel: 'Open Bank Statement',
      actionRouteId: 'bank_statement',
    ),

    // 5. Biometric Unlock & App Lock
    AppFeature(
      id: 'biometric_lock',
      title: 'Biometric Fingerprint & Face Unlock',
      shortTagline:
          'Keep your personal finances private with biometric security',
      icon: Icons.fingerprint_rounded,
      badge: 'Privacy',
      category: 'Privacy & Security',
      accentColor: Color(0xFFD97706),
      userOverview:
          'Your family finances are deeply personal. With App Lock enabled, Manikutti requires your phone’s biometric sensor (fingerprint or face unlock) or a secret 4-digit PIN every time the app opens or resumes from the background.',
      keyBenefits: [
        'Instant biometric fingerprint and face recognition',
        'Custom 4-digit fallback PIN for complete peace of mind',
        'Locks automatically when switching between apps or turning screen off',
        'Your security keys remain strictly on your physical phone hardware',
      ],
      tutorialSteps: [
        TutorialStep(
          stepNumber: 1,
          title: 'Navigate to App Lock in Settings',
          instruction:
              'Open Settings from the side drawer and select "App Lock" under the security section.',
          proTip:
              'Make sure you have already registered a fingerprint or face unlock in Android settings.',
          mockupType: MockupType.biometricLock,
        ),
        TutorialStep(
          stepNumber: 2,
          title: 'Set Your 4-Digit Security PIN',
          instruction:
              'Enter a memorable 4-digit PIN and toggle on "Enable Biometrics" for instant one-touch entry.',
          proTip:
              'Choose a PIN different from your phone unlock PIN for an extra layer of privacy.',
          mockupType: MockupType.biometricLock,
        ),
        TutorialStep(
          stepNumber: 3,
          title: 'Enjoy Private Protection',
          instruction:
              'Every time you open Manikutti, you will see a sleek biometric prompt. Touch your fingerprint sensor to enter your ledger.',
          proTip:
              'You can change or disable your PIN at any time from Settings.',
          mockupType: MockupType.biometricLock,
        ),
      ],
      actionLabel: 'Configure App Lock',
      actionRouteId: 'app_lock',
    ),

    // 6. Family Financial Sanctuary
    AppFeature(
      id: 'family_finance',
      title: 'Family Financial Sanctuary',
      shortTagline:
          'Collaborate on household expenses with your partner and family',
      icon: Icons.family_restroom_rounded,
      badge: 'Popular',
      category: 'Family & Budget',
      accentColor: Color(0xFFE11D48),
      userOverview:
          'Run your household smoothly together. Family members can log shared grocery, medical, and household expenses into a single shared family ledger, while keeping personal expenses confidential. See who paid for what and balance family contributions peacefully.',
      keyBenefits: [
        'Shared household dashboard accessible by you and your family members',
        'Clear breakdown of who contributed to each grocery run or utility payment',
        'Monthly family budget tracker preventing unexpected overspending',
        'Private invitation tokens keep your family financial sanctuary secure',
      ],
      tutorialSteps: [
        TutorialStep(
          stepNumber: 1,
          title: 'Generate Family Invitation Code',
          instruction:
              'The primary admin generates a secure Family Sanctuary Code and shares it privately with family members.',
          proTip:
              'Codes are private to your family and cannot be accessed by outsiders.',
          mockupType: MockupType.familySanctuary,
        ),
        TutorialStep(
          stepNumber: 2,
          title: 'Enter Family Code on Secondary Phone',
          instruction:
              'Family members log in and enter the invitation code to link their app to the shared family sanctuary.',
          proTip:
              'Each member uses their own phone and receives instant notifications for shared activities.',
          mockupType: MockupType.familySanctuary,
        ),
        TutorialStep(
          stepNumber: 3,
          title: 'Review Shared Contributions',
          instruction:
              'View visual graphs showing total household monthly spending, categorized expenses, and member balance summaries.',
          proTip:
              'Shared expenses are updated in real time across all family members’ devices.',
          mockupType: MockupType.familySanctuary,
        ),
      ],
      actionLabel: 'Open Family Dashboard',
      actionRouteId: 'dashboard',
    ),

    // 7. Loans & EMIs Manager
    AppFeature(
      id: 'loans_emi',
      title: 'Home Loans & Split EMI Manager',
      shortTagline:
          'Stay on top of bank loans, interest, and monthly installments',
      icon: Icons.real_estate_agent_rounded,
      badge: 'Essential',
      category: 'Family & Budget',
      accentColor: Color(0xFF0284C7),
      userOverview:
          'Keep your home loan, car loan, and monthly EMIs under complete control. Track the principal paid, interest portion, remaining balance, and upcoming due dates so you never incur a late penalty.',
      keyBenefits: [
        'Automatic tracking of paid installments and remaining tenure',
        'Clear breakdown of principal vs. interest components',
        'One-tap "Mark Paid" button registers the payment in your monthly expenses',
        'Timely reminder alerts before the bank debit date',
      ],
      actionLabel: 'View Loans & EMIs',
      actionRouteId: 'loans',
    ),

    // 8. Mobile Recharges & Validity Tracker
    AppFeature(
      id: 'mobile_recharges',
      title: 'Mobile Recharges & SIM Validity Tracker',
      shortTagline: 'Never miss an expiry date across all family SIM cards',
      icon: Icons.phonelink_ring_rounded,
      badge: 'Essential',
      category: 'Family & Budget',
      accentColor: Color(0xFFEA580C),
      userOverview:
          'Managing multiple prepaid mobile plans for family members (Jio, Airtel, Vi, BSNL) is now effortless. Track validity countdowns with color-coded alerts and jump straight to recharge with one tap.',
      keyBenefits: [
        'Color alerts: Green (Safe), Amber (Expiring in 3 days), Red (Expired)',
        'Track operator, phone number, and plan denomination for each family member',
        '1-Tap "Recharge Now" opens UPI or operator portal instantly',
        'Automatically creates an expense entry upon marking recharged',
      ],
      actionLabel: 'View Mobile Recharges',
      actionRouteId: 'recharges',
    ),

    // 9. Offline-First Safe Storage
    AppFeature(
      id: 'offline_vault',
      title: 'Offline-First Vault & Silent Cloud Backup',
      shortTagline:
          'Log expenses anywhere with zero internet — syncs automatically when online',
      icon: Icons.cloud_done_rounded,
      badge: 'Core',
      category: 'Privacy & Security',
      accentColor: Color(0xFF475569),
      userOverview:
          'Never let spotty cellular coverage slow you down. Manikutti stores all your records inside a blazing-fast local phone vault. You can record expenses on flights, in remote hill stations, or inside underground supermarkets. The moment your phone connects to Wi-Fi or mobile data, your records sync silently to your secure cloud backup.',
      keyBenefits: [
        'Zero waiting time: transactions save in less than 50 milliseconds',
        'Full app functionality even in Airplane mode',
        'Automatic conflict resolution keeps your numbers accurate across all devices',
        'Your records remain completely safe even if you switch or reset phones',
      ],
      actionLabel: 'Check Sync Status',
      actionRouteId: 'dashboard',
    ),

    // 10. In-App Expense Calculator
    AppFeature(
      id: 'smart_calculator',
      title: 'In-App Expense Calculator & Splitter',
      shortTagline:
          'Perform instant math and split bills without switching apps',
      icon: Icons.calculate_rounded,
      badge: 'Handy',
      category: 'Privacy & Security',
      accentColor: Color(0xFF0D9488),
      userOverview:
          'No need to jump back and forth between a calculator app and your expense ledger. Tap the calculator button directly inside the transaction screen to add multiple receipt items, calculate discounts, or divide dinner costs evenly between friends.',
      keyBenefits: [
        'Built right into the amount input field',
        'Visual calculation tape showing previous operations',
        'One-tap "Apply" writes the final sum directly into the amount box',
        'Convenient split button for dividing bills among family members',
      ],
      actionLabel: 'Add New Expense',
      actionRouteId: 'add_expense',
    ),

    // 11. Bilingual Experience
    AppFeature(
      id: 'bilingual_experience',
      title: 'Full Malayalam & English Support',
      shortTagline:
          'Designed with love for Kerala families and the global diaspora',
      icon: Icons.translate_rounded,
      badge: 'Regional',
      category: 'Privacy & Security',
      accentColor: Color(0xFF16A34A),
      userOverview:
          'Every button, title, and alert is thoughtfully translated into natural, easy-to-understand Malayalam (മലയാളം) and English. Numbers and amounts are formatted using familiar Indian numbering conventions (Lakhs & Crores) for effortless reading.',
      keyBenefits: [
        'Complete user interface available in pure Malayalam and English',
        'Instant language toggle in Settings without restarting the app',
        'Voice logging understands Manglish, Malayalam, and English seamlessly',
        'Indian Rupee currency formatting throughout',
      ],
      actionLabel: 'Change Language in Settings',
      actionRouteId: 'settings',
    ),

    // 12. Modern Day & Night Themes
    AppFeature(
      id: 'app_theming',
      title: 'Modern Day & Night Themes',
      shortTagline: 'Eye-comfort styling with battery-saving OLED Dark Mode',
      icon: Icons.palette_rounded,
      badge: 'Design',
      category: 'Privacy & Security',
      accentColor: Color(0xFF6366F1),
      userOverview:
          'Enjoy a polished, modern design inspired by Kerala heritage colors — warm teals, ivory accents, and deep obsidian night shades. Toggle freely between Light Mode, Dark Mode, or follow your phone’s system schedule.',
      keyBenefits: [
        'Deep black backgrounds reduce battery consumption on OLED displays',
        'High contrast ratios ensure readability in bright sunlight and low light',
        'Smooth animations and modern rounded card aesthetics',
        'Follows your phone’s automatic day/night schedule',
      ],
      actionLabel: 'Customize Theme in Settings',
      actionRouteId: 'settings',
    ),

    // 13. Upcoming Roadmap Features
    AppFeature(
      id: 'upcoming_roadmap',
      title: 'Upcoming Features & Future Roadmap',
      shortTagline: 'Sneak peek into upcoming tools currently in development',
      icon: Icons.rocket_launch_rounded,
      badge: 'Sneak Peek',
      category: 'Upcoming Roadmap',
      accentColor: Color(0xFFF43F5E),
      userOverview:
          'We are continuously enhancing Manikutti to make your family financial life simpler and stress-free. Here is an exclusive preview of upcoming capabilities coming in upcoming updates:',
      keyBenefits: [
        '📸 Smart Receipt Camera Scanner: Take a photo of any grocery or restaurant bill to extract line items automatically',
        '🏺 Goal Savings Jars: Visual piggy-bank jars for Onam shopping, vacation savings, and emergency funds',
        '🔔 Smart Budget Warnings: Friendly alerts before your weekend dining or shopping exceeds your monthly target',
        '💬 WhatsApp Expense Assistant: Forward transaction SMS or bill photos to a private assistant for automatic record keeping',
      ],
      tutorialSteps: [
        TutorialStep(
          stepNumber: 1,
          title: 'Camera Receipt Scanning (Coming Soon)',
          instruction:
              'Point your phone camera at paper receipts from supermarkets, medical stores, or petrol pumps. The smart scanner will read the total and shop name in 1 second.',
          proTip: 'No more typing long bills after weekend grocery shopping.',
          mockupType: MockupType.upcomingRoadmap,
        ),
        TutorialStep(
          stepNumber: 2,
          title: 'Goal Savings Jars (Coming Soon)',
          instruction:
              'Create custom savings jars (e.g., "Onam Gold Purchase", "Car Insurance", "Kids School Fees") and watch your savings fill up month by month.',
          proTip: 'Set target dates and monthly savings recommendations.',
          mockupType: MockupType.upcomingRoadmap,
        ),
        TutorialStep(
          stepNumber: 3,
          title: 'Vote for Features You Want',
          instruction:
              'Have an idea for a feature that would help your family? Let us know and we will prioritize it in upcoming releases!',
          proTip: 'Family privacy and ease of use always come first.',
          mockupType: MockupType.upcomingRoadmap,
        ),
      ],
      actionLabel: 'Explore All Features',
      actionRouteId: 'dashboard',
      isFuture: true,
    ),
  ];
}
