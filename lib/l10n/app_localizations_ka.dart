// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Georgian (`ka`).
class AppLocalizationsKa extends AppLocalizations {
  AppLocalizationsKa([String locale = 'ka']) : super(locale);

  @override
  String get appName => 'სამანტა';

  @override
  String get tabRepository => 'რეპოზიტორია';

  @override
  String get tabSession => 'სესია';

  @override
  String get newSession => 'ახალი სესია';

  @override
  String get failedToLoadData => 'მონაცემების ჩატვირთვა ვერ მოხერხდა';

  @override
  String get retry => 'გამეორება';

  @override
  String get backToSettings => 'პარამეტრებში დაბრუნება';

  @override
  String get noRepositoriesFound => 'რეპოზიტორიები ვერ მოიძებნა';

  @override
  String get noRepositoriesDescription =>
      'დარწმუნდით, რომ opencode გაშვებულია და აღმოაჩინა\nთქვენი git რეპოზიტორიები.';

  @override
  String get refresh => 'განახლება';

  @override
  String get noPreviousSessions => 'წინა სესიები არ არის';

  @override
  String get noSessionsDescription =>
      'თქვენი opencode სერვერის სესიები\nაქ გამოჩნდება.';

  @override
  String get connectionSettings => 'კავშირის პარამეტრები';

  @override
  String get hostTailscaleIp => 'ჰოსტი / Tailscale IP';

  @override
  String get hostHint => '100.101.102.103 ან laptop.tailnet.ts.net';

  @override
  String get authToken => 'ავტორიზაციის ტოკენი';

  @override
  String get authTokenHint => 'იყენებს BRIDGE_AUTH_TOKEN გარემოს ცვლადს';

  @override
  String get testConnection => 'კავშირის შემოწმება';

  @override
  String get saveAndConnect => 'შენახვა და დაკავშირება';

  @override
  String get connectionSuccessful => 'კავშირი წარმატებით დამყარდა';

  @override
  String get permissionRequired => 'ნებართვაა საჭირო';

  @override
  String get allowThisAction => 'დაუშვათ ეს მოქმედება?';

  @override
  String get deny => 'უარყოფა';

  @override
  String get allow => 'დაშვება';

  @override
  String get chat => 'ჩატი';

  @override
  String get messageHint => 'შეტყობინება…';

  @override
  String get selectModel => 'მოდელის არჩევა';

  @override
  String get searchModels => 'მოდელების ძიება…';

  @override
  String get noModelsFound => 'მოდელები ვერ მოიძებნა';

  @override
  String get statusConnected => 'დაკავშირებულია';

  @override
  String get statusStreaming => 'სტრიმინგი';

  @override
  String get statusConnecting => 'მიმდინარეობს დაკავშირება';

  @override
  String get statusOffline => 'ოფლაინ';

  @override
  String get retryButton => 'გამეორება';

  @override
  String get thinking => 'ფიქრი…';

  @override
  String get thought => 'აზრი';

  @override
  String thoughtWithDuration(String duration) {
    return 'ფიქრობდა $duration';
  }

  @override
  String get copy => 'კოპირება';

  @override
  String get copied => 'დაკოპირდა';

  @override
  String todosDone(int doneCount, int totalCount) {
    return '$doneCount/$totalCount შესრულებულია';
  }

  @override
  String get jumpToLatest => 'ბოლოზე გადასვლა';

  @override
  String get errorCouldNotReachServer => 'სერვერთან დაკავშირება ვერ მოხერხდა';

  @override
  String get errorServerDidNotRespond => 'სერვერმა დროულად არ უპასუხა';

  @override
  String get errorInvalidAuthToken => 'არასწორი ავტორიზაციის ტოკენი';

  @override
  String get errorEnterConnectionDetails =>
      'გთხოვთ, შეიყვანოთ კავშირის მონაცემები';

  @override
  String get errorCouldNotEstablishConnection =>
      'კავშირის დამყარება ვერ მოხერხდა';

  @override
  String get errorInvalidResponseFromServer =>
      'სერვერიდან მიღებულ იქნა არასწორი პასუხი';

  @override
  String get errorConnectionLost => 'კავშირი დაიკარგა';

  @override
  String get errorSomethingWentWrong =>
      'რაღაც არასწორად წავიდა. გთხოვთ, სცადოთ თავიდან.';

  @override
  String get minutesAgo => 'წთ წინ';

  @override
  String get hoursAgo => 'სთ წინ';

  @override
  String get daysAgo => 'დ წინ';

  @override
  String get code => 'კოდი';

  @override
  String get selectModelFallback => 'მოდელის არჩევა';

  @override
  String get fallbackSessionTitle => 'ჩატი';

  @override
  String get messageActionsRetry => 'გამეორება';

  @override
  String get messageActionsEdit => 'რედაქტირება';

  @override
  String get messageActionsCopyCode => 'კოდის კოპირება';

  @override
  String get messageActionsBranch => 'აქიდან განშტოება';

  @override
  String get editMessageTitle => 'შეტყობინების რედაქტირება';

  @override
  String get editMessageSave => 'შენახვა და ხელახლა გაგზავნა';

  @override
  String get editMessageCancel => 'გაუქმება';

  @override
  String get searchSessions => 'სესიების ძიება…';

  @override
  String get searchProjects => 'რეპოზიტორიების ძიება…';

  @override
  String get noResultsFound => 'შედეგები ვერ მოიძებნა';

  @override
  String get codeCopied => 'კოდი კოპირებულია ბუფერში';
}
