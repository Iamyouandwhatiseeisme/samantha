import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ka.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ka'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Samantha'**
  String get appName;

  /// No description provided for @tabRepository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get tabRepository;

  /// No description provided for @tabSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get tabSession;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get newSession;

  /// No description provided for @failedToLoadData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get failedToLoadData;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @backToSettings.
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get backToSettings;

  /// No description provided for @noRepositoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No repositories found'**
  String get noRepositoriesFound;

  /// No description provided for @noRepositoriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Make sure opencode is running and has discovered\nyour git repositories.'**
  String get noRepositoriesDescription;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noPreviousSessions.
  ///
  /// In en, this message translates to:
  /// **'No previous sessions'**
  String get noPreviousSessions;

  /// No description provided for @noSessionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sessions from your opencode server\nwill appear here.'**
  String get noSessionsDescription;

  /// No description provided for @connectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection Settings'**
  String get connectionSettings;

  /// No description provided for @hostTailscaleIp.
  ///
  /// In en, this message translates to:
  /// **'Host / Tailscale IP'**
  String get hostTailscaleIp;

  /// No description provided for @hostHint.
  ///
  /// In en, this message translates to:
  /// **'100.101.102.103 or laptop.tailnet.ts.net'**
  String get hostHint;

  /// No description provided for @authToken.
  ///
  /// In en, this message translates to:
  /// **'Auth Token'**
  String get authToken;

  /// No description provided for @authTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Set by BRIDGE_AUTH_TOKEN env var'**
  String get authTokenHint;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @saveAndConnect.
  ///
  /// In en, this message translates to:
  /// **'Save & Connect'**
  String get saveAndConnect;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccessful;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// No description provided for @allowThisAction.
  ///
  /// In en, this message translates to:
  /// **'Allow this action?'**
  String get allowThisAction;

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get messageHint;

  /// No description provided for @selectModel.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get selectModel;

  /// No description provided for @searchModels.
  ///
  /// In en, this message translates to:
  /// **'Search models…'**
  String get searchModels;

  /// No description provided for @noModelsFound.
  ///
  /// In en, this message translates to:
  /// **'No models found'**
  String get noModelsFound;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get statusConnected;

  /// No description provided for @statusStreaming.
  ///
  /// In en, this message translates to:
  /// **'streaming'**
  String get statusStreaming;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'connecting'**
  String get statusConnecting;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get statusOffline;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get retryButton;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// No description provided for @thought.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get thought;

  /// No description provided for @thoughtWithDuration.
  ///
  /// In en, this message translates to:
  /// **'Thought for {duration}'**
  String thoughtWithDuration(String duration);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @todosDone.
  ///
  /// In en, this message translates to:
  /// **'{doneCount}/{totalCount} done'**
  String todosDone(int doneCount, int totalCount);

  /// No description provided for @jumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get jumpToLatest;

  /// No description provided for @errorCouldNotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server'**
  String get errorCouldNotReachServer;

  /// No description provided for @errorServerDidNotRespond.
  ///
  /// In en, this message translates to:
  /// **'Server did not respond in time'**
  String get errorServerDidNotRespond;

  /// No description provided for @errorInvalidAuthToken.
  ///
  /// In en, this message translates to:
  /// **'Invalid auth token'**
  String get errorInvalidAuthToken;

  /// No description provided for @errorEnterConnectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Please enter your connection details'**
  String get errorEnterConnectionDetails;

  /// No description provided for @errorCouldNotEstablishConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not establish connection'**
  String get errorCouldNotEstablishConnection;

  /// No description provided for @errorInvalidResponseFromServer.
  ///
  /// In en, this message translates to:
  /// **'Received invalid response from server'**
  String get errorInvalidResponseFromServer;

  /// No description provided for @errorConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get errorConnectionLost;

  /// No description provided for @errorSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorSomethingWentWrong;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'m ago'**
  String get minutesAgo;

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'h ago'**
  String get hoursAgo;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'d ago'**
  String get daysAgo;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'code'**
  String get code;

  /// No description provided for @selectModelFallback.
  ///
  /// In en, this message translates to:
  /// **'Select model'**
  String get selectModelFallback;

  /// No description provided for @fallbackSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get fallbackSessionTitle;

  /// No description provided for @messageActionsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get messageActionsRetry;

  /// No description provided for @messageActionsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get messageActionsEdit;

  /// No description provided for @messageActionsCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get messageActionsCopyCode;

  /// No description provided for @messageActionsBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch from Here'**
  String get messageActionsBranch;

  /// No description provided for @editMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Message'**
  String get editMessageTitle;

  /// No description provided for @editMessageSave.
  ///
  /// In en, this message translates to:
  /// **'Save & Resend'**
  String get editMessageSave;

  /// No description provided for @editMessageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editMessageCancel;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard'**
  String get codeCopied;
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
      <String>['en', 'ka'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ka':
      return AppLocalizationsKa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
