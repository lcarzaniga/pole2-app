import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

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
    Locale('it'),
  ];

  /// No description provided for @appName.
  ///
  /// In it, this message translates to:
  /// **'Pole²'**
  String get appName;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Una casa serena per le tue cose'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Tutto ciò a cui tieni può vivere qui — al sicuro, e solo su questo dispositivo.'**
  String get homeEmptyBody;

  /// No description provided for @homeEmptyCta.
  ///
  /// In it, this message translates to:
  /// **'Tocca per iniziare'**
  String get homeEmptyCta;

  /// No description provided for @privacyLine.
  ///
  /// In it, this message translates to:
  /// **'Tutto resta su questo dispositivo'**
  String get privacyLine;

  /// No description provided for @a11yKeepSomething.
  ///
  /// In it, this message translates to:
  /// **'Conserva qualcosa'**
  String get a11yKeepSomething;

  /// No description provided for @a11yClose.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get a11yClose;

  /// No description provided for @actionObject.
  ///
  /// In it, this message translates to:
  /// **'Un oggetto'**
  String get actionObject;

  /// No description provided for @actionPhoto.
  ///
  /// In it, this message translates to:
  /// **'Una foto'**
  String get actionPhoto;

  /// No description provided for @actionDocument.
  ///
  /// In it, this message translates to:
  /// **'Un documento'**
  String get actionDocument;

  /// No description provided for @actionReminder.
  ///
  /// In it, this message translates to:
  /// **'Un promemoria'**
  String get actionReminder;

  /// No description provided for @actionNote.
  ///
  /// In it, this message translates to:
  /// **'Una nota'**
  String get actionNote;

  /// No description provided for @actionDetail.
  ///
  /// In it, this message translates to:
  /// **'Un dettaglio'**
  String get actionDetail;

  /// No description provided for @quickActionSoon.
  ///
  /// In it, this message translates to:
  /// **'Presto. Per ora, inizia conservando un oggetto.'**
  String get quickActionSoon;

  /// No description provided for @photoSourceTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una foto'**
  String get photoSourceTitle;

  /// No description provided for @photoTakePhoto.
  ///
  /// In it, this message translates to:
  /// **'Scatta una foto'**
  String get photoTakePhoto;

  /// No description provided for @photoChooseGallery.
  ///
  /// In it, this message translates to:
  /// **'Scegli dalla galleria'**
  String get photoChooseGallery;

  /// No description provided for @cameraDeniedSnack.
  ///
  /// In it, this message translates to:
  /// **'Pole² non può ancora usare la fotocamera. Puoi autorizzarla dalle impostazioni.'**
  String get cameraDeniedSnack;

  /// No description provided for @captureFailedSnack.
  ///
  /// In it, this message translates to:
  /// **'Nulla è andato perso. Riprova quando vuoi.'**
  String get captureFailedSnack;

  /// No description provided for @createTitle.
  ///
  /// In it, this message translates to:
  /// **'Conserva qualcosa'**
  String get createTitle;

  /// No description provided for @whatIsItLabel.
  ///
  /// In it, this message translates to:
  /// **'Che cos\'è?'**
  String get whatIsItLabel;

  /// No description provided for @createHint.
  ///
  /// In it, this message translates to:
  /// **'es. Lavastoviglie, l\'orologio del nonno, l\'auto'**
  String get createHint;

  /// No description provided for @createReassure.
  ///
  /// In it, this message translates to:
  /// **'Puoi aggiungere foto, ricevute e dettagli quando vuoi. Per ora non serve altro.'**
  String get createReassure;

  /// No description provided for @keepItButton.
  ///
  /// In it, this message translates to:
  /// **'Conserva'**
  String get keepItButton;

  /// No description provided for @upcomingDatesCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 data in arrivo} other{{count} date in arrivo}}'**
  String upcomingDatesCount(int count);

  /// No description provided for @addPhoto.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una foto'**
  String get addPhoto;

  /// No description provided for @renameTooltip.
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get renameTooltip;

  /// No description provided for @nameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get nameLabel;

  /// No description provided for @saveButton.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get saveButton;

  /// No description provided for @keptOn.
  ///
  /// In it, this message translates to:
  /// **'Conservato il {date}'**
  String keptOn(String date);

  /// No description provided for @nextUp.
  ///
  /// In it, this message translates to:
  /// **'Prossimo: {what}'**
  String nextUp(String what);

  /// No description provided for @detailsTitle.
  ///
  /// In it, this message translates to:
  /// **'Dettagli'**
  String get detailsTitle;

  /// No description provided for @detailsEmptySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Da dove viene, quanto è costato, quando l\'hai preso.'**
  String get detailsEmptySubtitle;

  /// No description provided for @tapToAddMore.
  ///
  /// In it, this message translates to:
  /// **'Tocca per aggiungere altro'**
  String get tapToAddMore;

  /// No description provided for @documentsTitle.
  ///
  /// In it, this message translates to:
  /// **'Documenti'**
  String get documentsTitle;

  /// No description provided for @documentsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Qui vivono ricevute, manuali e garanzie.'**
  String get documentsSubtitle;

  /// No description provided for @historyTitle.
  ///
  /// In it, this message translates to:
  /// **'Storia'**
  String get historyTitle;

  /// No description provided for @addDate.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una data'**
  String get addDate;

  /// No description provided for @historyEmpty.
  ///
  /// In it, this message translates to:
  /// **'Ancora niente — aggiungi come l\'hai preso, o una data da ricordare.'**
  String get historyEmpty;

  /// No description provided for @onDate.
  ///
  /// In it, this message translates to:
  /// **'il {date}'**
  String onDate(String date);

  /// No description provided for @menuRename.
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get menuRename;

  /// No description provided for @menuPutAway.
  ///
  /// In it, this message translates to:
  /// **'Metti via'**
  String get menuPutAway;

  /// No description provided for @menuRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get menuRemove;

  /// No description provided for @archivedSnack.
  ///
  /// In it, this message translates to:
  /// **'Messo via. È al sicuro.'**
  String get archivedSnack;

  /// No description provided for @removedSnack.
  ///
  /// In it, this message translates to:
  /// **'Rimosso. Non è ancora perso nulla.'**
  String get removedSnack;

  /// No description provided for @eventRemovedSnack.
  ///
  /// In it, this message translates to:
  /// **'Rimosso.'**
  String get eventRemovedSnack;

  /// No description provided for @undo.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get undo;

  /// No description provided for @errorNothingLost.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa è andato storto — ma non è andato perso nulla.'**
  String get errorNothingLost;

  /// No description provided for @goneMessage.
  ///
  /// In it, this message translates to:
  /// **'Non è più qui.'**
  String get goneMessage;

  /// No description provided for @boughtAt.
  ///
  /// In it, this message translates to:
  /// **'Comprato da {supplier}'**
  String boughtAt(String supplier);

  /// No description provided for @bought.
  ///
  /// In it, this message translates to:
  /// **'Comprato'**
  String get bought;

  /// No description provided for @receivedAsGift.
  ///
  /// In it, this message translates to:
  /// **'Ricevuto in regalo'**
  String get receivedAsGift;

  /// No description provided for @inheritedHeadline.
  ///
  /// In it, this message translates to:
  /// **'Ereditato'**
  String get inheritedHeadline;

  /// No description provided for @alreadyHadHeadline.
  ///
  /// In it, this message translates to:
  /// **'Ce l\'avevo già'**
  String get alreadyHadHeadline;

  /// No description provided for @keptHeadline.
  ///
  /// In it, this message translates to:
  /// **'Conservato'**
  String get keptHeadline;

  /// No description provided for @fromSupplier.
  ///
  /// In it, this message translates to:
  /// **'Da {supplier}'**
  String fromSupplier(String supplier);

  /// No description provided for @purchaseDetailsHeadline.
  ///
  /// In it, this message translates to:
  /// **'Dettagli d\'acquisto'**
  String get purchaseDetailsHeadline;

  /// No description provided for @acquisitionTitle.
  ///
  /// In it, this message translates to:
  /// **'Dettagli d\'acquisto'**
  String get acquisitionTitle;

  /// No description provided for @howDidYouGetIt.
  ///
  /// In it, this message translates to:
  /// **'Come l\'hai avuto?'**
  String get howDidYouGetIt;

  /// No description provided for @acqTypeBought.
  ///
  /// In it, this message translates to:
  /// **'Comprato'**
  String get acqTypeBought;

  /// No description provided for @acqTypeGift.
  ///
  /// In it, this message translates to:
  /// **'Regalo'**
  String get acqTypeGift;

  /// No description provided for @acqTypeInherited.
  ///
  /// In it, this message translates to:
  /// **'Ereditato'**
  String get acqTypeInherited;

  /// No description provided for @acqTypeAlreadyHad.
  ///
  /// In it, this message translates to:
  /// **'Già mio'**
  String get acqTypeAlreadyHad;

  /// No description provided for @acqTypeOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get acqTypeOther;

  /// No description provided for @whenLabel.
  ///
  /// In it, this message translates to:
  /// **'Quando'**
  String get whenLabel;

  /// No description provided for @notSet.
  ///
  /// In it, this message translates to:
  /// **'Non impostata'**
  String get notSet;

  /// No description provided for @whereFromLabel.
  ///
  /// In it, this message translates to:
  /// **'Da dove'**
  String get whereFromLabel;

  /// No description provided for @whereFromHint.
  ///
  /// In it, this message translates to:
  /// **'Negozio o persona'**
  String get whereFromHint;

  /// No description provided for @priceLabel.
  ///
  /// In it, this message translates to:
  /// **'Prezzo'**
  String get priceLabel;

  /// No description provided for @noteLabel.
  ///
  /// In it, this message translates to:
  /// **'Nota'**
  String get noteLabel;

  /// No description provided for @acquisitionReassure.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi quanto vuoi — puoi sempre tornarci.'**
  String get acquisitionReassure;

  /// No description provided for @reminderTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una data'**
  String get reminderTitle;

  /// No description provided for @reminderHint.
  ///
  /// In it, this message translates to:
  /// **'es. Scadenza garanzia'**
  String get reminderHint;

  /// No description provided for @suggWarranty.
  ///
  /// In it, this message translates to:
  /// **'Scadenza garanzia'**
  String get suggWarranty;

  /// No description provided for @suggReturn.
  ///
  /// In it, this message translates to:
  /// **'Fine reso'**
  String get suggReturn;

  /// No description provided for @suggService.
  ///
  /// In it, this message translates to:
  /// **'Manutenzione'**
  String get suggService;

  /// No description provided for @suggInsurance.
  ///
  /// In it, this message translates to:
  /// **'Rinnovo assicurazione'**
  String get suggInsurance;

  /// No description provided for @suggFilter.
  ///
  /// In it, this message translates to:
  /// **'Cambio filtro'**
  String get suggFilter;

  /// No description provided for @chooseDate.
  ///
  /// In it, this message translates to:
  /// **'Scegli una data'**
  String get chooseDate;

  /// No description provided for @remindMe.
  ///
  /// In it, this message translates to:
  /// **'Ricordamelo'**
  String get remindMe;

  /// No description provided for @leadSameDay.
  ///
  /// In it, this message translates to:
  /// **'Il giorno stesso'**
  String get leadSameDay;

  /// No description provided for @leadDayBefore.
  ///
  /// In it, this message translates to:
  /// **'1 giorno prima'**
  String get leadDayBefore;

  /// No description provided for @leadWeekBefore.
  ///
  /// In it, this message translates to:
  /// **'1 settimana prima'**
  String get leadWeekBefore;

  /// No description provided for @leadMonthBefore.
  ///
  /// In it, this message translates to:
  /// **'1 mese prima'**
  String get leadMonthBefore;

  /// No description provided for @today.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In it, this message translates to:
  /// **'Domani'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get yesterday;

  /// No description provided for @inDays.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{tra 1 giorno} other{tra {count} giorni}}'**
  String inDays(int count);

  /// No description provided for @daysAgo.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 giorno fa} other{{count} giorni fa}}'**
  String daysAgo(int count);

  /// No description provided for @noPlace.
  ///
  /// In it, this message translates to:
  /// **'Nessun luogo'**
  String get noPlace;

  /// No description provided for @placeLabel.
  ///
  /// In it, this message translates to:
  /// **'Luogo'**
  String get placeLabel;

  /// No description provided for @placeAssignHint.
  ///
  /// In it, this message translates to:
  /// **'Tocca per assegnare un luogo'**
  String get placeAssignHint;

  /// No description provided for @placePickerTitle.
  ///
  /// In it, this message translates to:
  /// **'Dove si trova?'**
  String get placePickerTitle;

  /// No description provided for @newPlaceHint.
  ///
  /// In it, this message translates to:
  /// **'Nuovo luogo — es. Garage, Ufficio'**
  String get newPlaceHint;

  /// No description provided for @addPlaceButton.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get addPlaceButton;

  /// No description provided for @placeManageTooltip.
  ///
  /// In it, this message translates to:
  /// **'Gestisci'**
  String get placeManageTooltip;

  /// No description provided for @placeDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get placeDelete;

  /// No description provided for @placeRenameTitle.
  ///
  /// In it, this message translates to:
  /// **'Rinomina luogo'**
  String get placeRenameTitle;

  /// No description provided for @cancelButton.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancelButton;

  /// No description provided for @placeDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare «{name}»?'**
  String placeDeleteTitle(String name);

  /// No description provided for @placeDeleteAssigned.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{È assegnato a 1 oggetto, che tornerà a «Nessun luogo».} other{È assegnato a {count} oggetti, che torneranno a «Nessun luogo».}}'**
  String placeDeleteAssigned(int count);

  /// No description provided for @placeDeleteNone.
  ///
  /// In it, this message translates to:
  /// **'Nessun oggetto usa questo luogo.'**
  String get placeDeleteNone;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento disponibile'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In it, this message translates to:
  /// **'È disponibile la versione {version}.'**
  String updateAvailableBody(String version);

  /// No description provided for @updateNow.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In it, this message translates to:
  /// **'Più tardi'**
  String get updateLater;

  /// No description provided for @updateDownloading.
  ///
  /// In it, this message translates to:
  /// **'Scaricamento…'**
  String get updateDownloading;

  /// No description provided for @updateVerifying.
  ///
  /// In it, this message translates to:
  /// **'Verifica…'**
  String get updateVerifying;

  /// No description provided for @updateInstalling.
  ///
  /// In it, this message translates to:
  /// **'Avvio installazione…'**
  String get updateInstalling;

  /// No description provided for @updatePermissionNeeded.
  ///
  /// In it, this message translates to:
  /// **'Per installare l\'aggiornamento, consenti l\'installazione di app da questa sorgente.'**
  String get updatePermissionNeeded;

  /// No description provided for @updateAllow.
  ///
  /// In it, this message translates to:
  /// **'Consenti'**
  String get updateAllow;

  /// No description provided for @updateRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get updateRetry;

  /// No description provided for @updateErrorDownload.
  ///
  /// In it, this message translates to:
  /// **'Scaricamento non riuscito.'**
  String get updateErrorDownload;

  /// No description provided for @updateErrorSha.
  ///
  /// In it, this message translates to:
  /// **'File di aggiornamento non valido.'**
  String get updateErrorSha;

  /// No description provided for @updateErrorInstall.
  ///
  /// In it, this message translates to:
  /// **'Installazione non riuscita.'**
  String get updateErrorInstall;

  /// No description provided for @closeButton.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get closeButton;
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
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
