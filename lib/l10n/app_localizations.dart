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

  /// No description provided for @placeContentsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Qui non c\'è ancora niente.'**
  String get placeContentsEmpty;

  /// No description provided for @placeEmptyHint.
  ///
  /// In it, this message translates to:
  /// **'Puoi assegnare un oggetto a questo luogo dalla sua scheda.'**
  String get placeEmptyHint;

  /// No description provided for @placeItemCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessun oggetto} =1{1 oggetto} other{{count} oggetti}}'**
  String placeItemCount(int count);

  /// No description provided for @placeMoveAction.
  ///
  /// In it, this message translates to:
  /// **'Sposta in un altro luogo'**
  String get placeMoveAction;

  /// No description provided for @placeRemoveAction.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dal luogo'**
  String get placeRemoveAction;

  /// No description provided for @placeMovedSnack.
  ///
  /// In it, this message translates to:
  /// **'Oggetto spostato.'**
  String get placeMovedSnack;

  /// No description provided for @placeRemovedFromSnack.
  ///
  /// In it, this message translates to:
  /// **'Rimosso dal luogo.'**
  String get placeRemovedFromSnack;

  /// No description provided for @itemActionsTooltip.
  ///
  /// In it, this message translates to:
  /// **'Opzioni'**
  String get itemActionsTooltip;

  /// No description provided for @placeEditTooltip.
  ///
  /// In it, this message translates to:
  /// **'Cambia luogo'**
  String get placeEditTooltip;

  /// No description provided for @noteEditorTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una nota'**
  String get noteEditorTitle;

  /// No description provided for @noteHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi una nota…'**
  String get noteHint;

  /// No description provided for @addNote.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una nota'**
  String get addNote;

  /// No description provided for @addDocument.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un documento'**
  String get addDocument;

  /// No description provided for @documentAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get documentAdd;

  /// No description provided for @documentRemovedSnack.
  ///
  /// In it, this message translates to:
  /// **'Documento rimosso.'**
  String get documentRemovedSnack;

  /// No description provided for @documentAddFailed.
  ///
  /// In it, this message translates to:
  /// **'Nulla è andato perso. Riprova quando vuoi.'**
  String get documentAddFailed;

  /// No description provided for @hubPhoto.
  ///
  /// In it, this message translates to:
  /// **'Foto'**
  String get hubPhoto;

  /// No description provided for @hubNote.
  ///
  /// In it, this message translates to:
  /// **'Nota'**
  String get hubNote;

  /// No description provided for @hubDocument.
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get hubDocument;

  /// No description provided for @hubDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get hubDate;

  /// No description provided for @hubPlace.
  ///
  /// In it, this message translates to:
  /// **'Luogo'**
  String get hubPlace;

  /// No description provided for @searchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get searchHint;

  /// No description provided for @searchClear.
  ///
  /// In it, this message translates to:
  /// **'Cancella'**
  String get searchClear;

  /// No description provided for @searchNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato'**
  String get searchNoResults;

  /// No description provided for @sortTooltip.
  ///
  /// In it, this message translates to:
  /// **'Ordina'**
  String get sortTooltip;

  /// No description provided for @sortNewest.
  ///
  /// In it, this message translates to:
  /// **'Più recenti'**
  String get sortNewest;

  /// No description provided for @sortName.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get sortName;

  /// No description provided for @filterTooltip.
  ///
  /// In it, this message translates to:
  /// **'Filtra per luogo'**
  String get filterTooltip;

  /// No description provided for @filterAllPlaces.
  ///
  /// In it, this message translates to:
  /// **'Tutti i luoghi'**
  String get filterAllPlaces;

  /// No description provided for @filterNoPlace.
  ///
  /// In it, this message translates to:
  /// **'Senza luogo'**
  String get filterNoPlace;

  /// No description provided for @photoEditTooltip.
  ///
  /// In it, this message translates to:
  /// **'Cambia foto'**
  String get photoEditTooltip;

  /// No description provided for @photoView.
  ///
  /// In it, this message translates to:
  /// **'Vedi la foto'**
  String get photoView;

  /// No description provided for @placeReviewStart.
  ///
  /// In it, this message translates to:
  /// **'Riordina questo luogo'**
  String get placeReviewStart;

  /// No description provided for @placeReviewKeep.
  ///
  /// In it, this message translates to:
  /// **'Tieni qui'**
  String get placeReviewKeep;

  /// No description provided for @placeReviewMove.
  ///
  /// In it, this message translates to:
  /// **'Sposta'**
  String get placeReviewMove;

  /// No description provided for @placeReviewUnassign.
  ///
  /// In it, this message translates to:
  /// **'Togli dal luogo'**
  String get placeReviewUnassign;

  /// No description provided for @placeReviewArchive.
  ///
  /// In it, this message translates to:
  /// **'Metti da parte'**
  String get placeReviewArchive;

  /// No description provided for @placeReviewDone.
  ///
  /// In it, this message translates to:
  /// **'Fine'**
  String get placeReviewDone;

  /// No description provided for @placeReviewAllSeen.
  ///
  /// In it, this message translates to:
  /// **'Hai guardato tutto quello che c\'è qui.'**
  String get placeReviewAllSeen;

  /// No description provided for @placeReviewGentleCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Niente qui} =1{1 cosa qui} other{{count} cose qui}}'**
  String placeReviewGentleCount(int count);

  /// No description provided for @photoAddAnother.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un\'altra foto'**
  String get photoAddAnother;

  /// No description provided for @photoSetCover.
  ///
  /// In it, this message translates to:
  /// **'Imposta come copertina'**
  String get photoSetCover;

  /// No description provided for @photoIsCover.
  ///
  /// In it, this message translates to:
  /// **'Copertina'**
  String get photoIsCover;

  /// No description provided for @photoRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi foto'**
  String get photoRemove;

  /// No description provided for @photoRemovedSnack.
  ///
  /// In it, this message translates to:
  /// **'Foto rimossa.'**
  String get photoRemovedSnack;

  /// No description provided for @photoPosition.
  ///
  /// In it, this message translates to:
  /// **'{current} di {total}'**
  String photoPosition(int current, int total);

  /// No description provided for @photoCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 foto} other{{count} foto}}'**
  String photoCount(int count);

  /// No description provided for @lendToSomeone.
  ///
  /// In it, this message translates to:
  /// **'Presta a qualcuno'**
  String get lendToSomeone;

  /// No description provided for @lendEditTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica prestito'**
  String get lendEditTitle;

  /// No description provided for @borrowerLabel.
  ///
  /// In it, this message translates to:
  /// **'A chi lo presti?'**
  String get borrowerLabel;

  /// No description provided for @borrowerChoose.
  ///
  /// In it, this message translates to:
  /// **'Scegli una persona'**
  String get borrowerChoose;

  /// No description provided for @selectPerson.
  ///
  /// In it, this message translates to:
  /// **'Scegli una persona'**
  String get selectPerson;

  /// No description provided for @createPerson.
  ///
  /// In it, this message translates to:
  /// **'Nuova persona'**
  String get createPerson;

  /// No description provided for @personNameHint.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get personNameHint;

  /// No description provided for @addPersonButton.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get addPersonButton;

  /// No description provided for @lentDateLabel.
  ///
  /// In it, this message translates to:
  /// **'Data del prestito'**
  String get lentDateLabel;

  /// No description provided for @expectedReturnLabel.
  ///
  /// In it, this message translates to:
  /// **'Rientro previsto'**
  String get expectedReturnLabel;

  /// No description provided for @expectedReturnOptional.
  ///
  /// In it, this message translates to:
  /// **'Rientro previsto (facoltativo)'**
  String get expectedReturnOptional;

  /// No description provided for @noReturnDate.
  ///
  /// In it, this message translates to:
  /// **'Nessuna data di rientro'**
  String get noReturnDate;

  /// No description provided for @returnDateClear.
  ///
  /// In it, this message translates to:
  /// **'Togli la data'**
  String get returnDateClear;

  /// No description provided for @returnReminder.
  ///
  /// In it, this message translates to:
  /// **'Ricordami il rientro'**
  String get returnReminder;

  /// No description provided for @lentToPerson.
  ///
  /// In it, this message translates to:
  /// **'Prestato a {name}'**
  String lentToPerson(String name);

  /// No description provided for @lentOn.
  ///
  /// In it, this message translates to:
  /// **'Prestato il {date}'**
  String lentOn(String date);

  /// No description provided for @expectedReturnOn.
  ///
  /// In it, this message translates to:
  /// **'Rientro previsto il {date}'**
  String expectedReturnOn(String date);

  /// No description provided for @returnReminderSet.
  ///
  /// In it, this message translates to:
  /// **'Ti ricorderò il rientro'**
  String get returnReminderSet;

  /// No description provided for @markReturned.
  ///
  /// In it, this message translates to:
  /// **'Segna come restituito'**
  String get markReturned;

  /// No description provided for @returnTitle.
  ///
  /// In it, this message translates to:
  /// **'Segna come restituito'**
  String get returnTitle;

  /// No description provided for @returnActualDate.
  ///
  /// In it, this message translates to:
  /// **'Data di rientro'**
  String get returnActualDate;

  /// No description provided for @returnPlaceLabel.
  ///
  /// In it, this message translates to:
  /// **'Rimettilo in'**
  String get returnPlaceLabel;

  /// No description provided for @returnedOn.
  ///
  /// In it, this message translates to:
  /// **'Restituito il {date}'**
  String returnedOn(String date);

  /// No description provided for @returnReminderTitle.
  ///
  /// In it, this message translates to:
  /// **'Rientro: {object}'**
  String returnReminderTitle(String object);

  /// No description provided for @loanStarted.
  ///
  /// In it, this message translates to:
  /// **'Prestato. È annotato.'**
  String get loanStarted;

  /// No description provided for @loanUpdated.
  ///
  /// In it, this message translates to:
  /// **'Prestito aggiornato.'**
  String get loanUpdated;

  /// No description provided for @loanReturned.
  ///
  /// In it, this message translates to:
  /// **'Restituito. Bentornato.'**
  String get loanReturned;

  /// No description provided for @loanDatesInvalid.
  ///
  /// In it, this message translates to:
  /// **'La data del prestito non può essere dopo il rientro.'**
  String get loanDatesInvalid;

  /// No description provided for @cannotAssignPlaceWhileLent.
  ///
  /// In it, this message translates to:
  /// **'Puoi assegnare un luogo quando torna.'**
  String get cannotAssignPlaceWhileLent;

  /// No description provided for @resolveLoanBeforeArchive.
  ///
  /// In it, this message translates to:
  /// **'Segna come restituito prima di archiviare o rimuovere.'**
  String get resolveLoanBeforeArchive;

  /// No description provided for @moreOptions.
  ///
  /// In it, this message translates to:
  /// **'Altre opzioni'**
  String get moreOptions;

  /// No description provided for @personEmptyHint.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi la prima persona qui sopra.'**
  String get personEmptyHint;

  /// No description provided for @archiveTitle.
  ///
  /// In it, this message translates to:
  /// **'Archivio'**
  String get archiveTitle;

  /// No description provided for @archiveMenu.
  ///
  /// In it, this message translates to:
  /// **'Archivio'**
  String get archiveMenu;

  /// No description provided for @archiveKeptTab.
  ///
  /// In it, this message translates to:
  /// **'Conservati'**
  String get archiveKeptTab;

  /// No description provided for @archiveRemovedTab.
  ///
  /// In it, this message translates to:
  /// **'Rimossi'**
  String get archiveRemovedTab;

  /// No description provided for @archiveOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri'**
  String get archiveOpen;

  /// No description provided for @archiveRestore.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get archiveRestore;

  /// No description provided for @archiveRestoredSnack.
  ///
  /// In it, this message translates to:
  /// **'Ripristinato.'**
  String get archiveRestoredSnack;

  /// No description provided for @removedRestoredSnack.
  ///
  /// In it, this message translates to:
  /// **'Ripristinato.'**
  String get removedRestoredSnack;

  /// No description provided for @archivedStatusLabel.
  ///
  /// In it, this message translates to:
  /// **'Messo da parte'**
  String get archivedStatusLabel;

  /// No description provided for @transferredStatusLabel.
  ///
  /// In it, this message translates to:
  /// **'Dato'**
  String get transferredStatusLabel;

  /// No description provided for @lostStatusLabel.
  ///
  /// In it, this message translates to:
  /// **'Smarrito'**
  String get lostStatusLabel;

  /// No description provided for @disposedStatusLabel.
  ///
  /// In it, this message translates to:
  /// **'Dismesso'**
  String get disposedStatusLabel;

  /// No description provided for @removedStatusLabel.
  ///
  /// In it, this message translates to:
  /// **'Rimosso'**
  String get removedStatusLabel;

  /// No description provided for @archiveKeptEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non hai messo da parte nessun oggetto.'**
  String get archiveKeptEmpty;

  /// No description provided for @archiveKeptEmptyHint.
  ///
  /// In it, this message translates to:
  /// **'Le cose messe da parte restano al sicuro qui e puoi ripristinarle quando vuoi.'**
  String get archiveKeptEmptyHint;

  /// No description provided for @archiveRemovedEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono oggetti rimossi.'**
  String get archiveRemovedEmpty;

  /// No description provided for @archiveRemovedEmptyHint.
  ///
  /// In it, this message translates to:
  /// **'Quello che rimuovi resta qui, pronto da ripristinare.'**
  String get archiveRemovedEmptyHint;

  /// No description provided for @archiveSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca nell\'archivio'**
  String get archiveSearchHint;

  /// No description provided for @archiveSearchNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato'**
  String get archiveSearchNoResults;

  /// No description provided for @archiveUpdatedOn.
  ///
  /// In it, this message translates to:
  /// **'Aggiornato il {date}'**
  String archiveUpdatedOn(String date);

  /// No description provided for @inactiveReadOnlyHint.
  ///
  /// In it, this message translates to:
  /// **'Ripristina per modificarlo di nuovo.'**
  String get inactiveReadOnlyHint;

  /// No description provided for @removedBannerTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimosso'**
  String get removedBannerTitle;

  /// No description provided for @placesTitle.
  ///
  /// In it, this message translates to:
  /// **'Luoghi'**
  String get placesTitle;

  /// No description provided for @placesMenu.
  ///
  /// In it, this message translates to:
  /// **'Luoghi'**
  String get placesMenu;

  /// No description provided for @placeAddRoot.
  ///
  /// In it, this message translates to:
  /// **'Nuovo luogo'**
  String get placeAddRoot;

  /// No description provided for @placeAddChild.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi sottoluogo'**
  String get placeAddChild;

  /// No description provided for @placeChildrenSection.
  ///
  /// In it, this message translates to:
  /// **'Sottoluoghi'**
  String get placeChildrenSection;

  /// No description provided for @placeDirectItemsSection.
  ///
  /// In it, this message translates to:
  /// **'Qui direttamente'**
  String get placeDirectItemsSection;

  /// No description provided for @placeMove.
  ///
  /// In it, this message translates to:
  /// **'Sposta luogo'**
  String get placeMove;

  /// No description provided for @placeMoveToRoot.
  ///
  /// In it, this message translates to:
  /// **'Nessun luogo superiore'**
  String get placeMoveToRoot;

  /// No description provided for @placeParent.
  ///
  /// In it, this message translates to:
  /// **'Luogo superiore'**
  String get placeParent;

  /// No description provided for @placeTotalCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Niente} =1{1 oggetto in tutto} other{{count} oggetti in tutto}}'**
  String placeTotalCount(int count);

  /// No description provided for @placeDirectCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{niente qui} =1{1 qui} other{{count} qui}}'**
  String placeDirectCount(int count);

  /// No description provided for @placeSubtreeCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{vuoto} =1{1 oggetto} other{{count} oggetti}}'**
  String placeSubtreeCount(int count);

  /// No description provided for @placesEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non hai ancora nessun luogo.'**
  String get placesEmpty;

  /// No description provided for @placesEmptyHint.
  ///
  /// In it, this message translates to:
  /// **'Crea un luogo per iniziare a organizzare le tue cose.'**
  String get placesEmptyHint;

  /// No description provided for @placeEmptyTree.
  ///
  /// In it, this message translates to:
  /// **'Qui non c\'è ancora niente.'**
  String get placeEmptyTree;

  /// No description provided for @placeNoDirectItems.
  ///
  /// In it, this message translates to:
  /// **'Nessun oggetto direttamente qui.'**
  String get placeNoDirectItems;

  /// No description provided for @placeNoChildren.
  ///
  /// In it, this message translates to:
  /// **'Nessun sottoluogo.'**
  String get placeNoChildren;

  /// No description provided for @placeDeleteHasChildren.
  ///
  /// In it, this message translates to:
  /// **'Prima sposta o rimuovi i sottoluoghi.'**
  String get placeDeleteHasChildren;

  /// No description provided for @placeMoveInvalid.
  ///
  /// In it, this message translates to:
  /// **'Non puoi spostarlo lì.'**
  String get placeMoveInvalid;

  /// No description provided for @placeMovedToSnack.
  ///
  /// In it, this message translates to:
  /// **'Luogo spostato.'**
  String get placeMovedToSnack;

  /// No description provided for @placeCreateUnder.
  ///
  /// In it, this message translates to:
  /// **'Nuovo sottoluogo di «{parent}»'**
  String placeCreateUnder(String parent);

  /// No description provided for @placeRootLevel.
  ///
  /// In it, this message translates to:
  /// **'Luogo principale'**
  String get placeRootLevel;

  /// No description provided for @newRootPlaceHint.
  ///
  /// In it, this message translates to:
  /// **'Nuovo luogo principale'**
  String get newRootPlaceHint;

  /// No description provided for @placeNewChildTitle.
  ///
  /// In it, this message translates to:
  /// **'Nuovo sottoluogo'**
  String get placeNewChildTitle;

  /// No description provided for @placeParentGone.
  ///
  /// In it, this message translates to:
  /// **'Quel luogo non c\'è più.'**
  String get placeParentGone;

  /// No description provided for @entrustToSomeone.
  ///
  /// In it, this message translates to:
  /// **'Affida a qualcuno'**
  String get entrustToSomeone;

  /// No description provided for @giveToSomeone.
  ///
  /// In it, this message translates to:
  /// **'Dai a qualcuno'**
  String get giveToSomeone;

  /// No description provided for @giveEditTitle.
  ///
  /// In it, this message translates to:
  /// **'Dai a qualcuno'**
  String get giveEditTitle;

  /// No description provided for @giveRecipientLabel.
  ///
  /// In it, this message translates to:
  /// **'A chi lo dai?'**
  String get giveRecipientLabel;

  /// No description provided for @giveRecipientChoose.
  ///
  /// In it, this message translates to:
  /// **'Scegli una persona'**
  String get giveRecipientChoose;

  /// No description provided for @giveDateLabel.
  ///
  /// In it, this message translates to:
  /// **'Quando'**
  String get giveDateLabel;

  /// No description provided for @giveNoteLabel.
  ///
  /// In it, this message translates to:
  /// **'Nota (facoltativa)'**
  String get giveNoteLabel;

  /// No description provided for @markAsGiven.
  ///
  /// In it, this message translates to:
  /// **'Segna come dato'**
  String get markAsGiven;

  /// No description provided for @giveEffectHint.
  ///
  /// In it, this message translates to:
  /// **'Uscirà dalla Home e dal suo luogo, ma resterà al sicuro in Archivio.'**
  String get giveEffectHint;

  /// No description provided for @givenToPerson.
  ///
  /// In it, this message translates to:
  /// **'Dato a {name}'**
  String givenToPerson(String name);

  /// No description provided for @givenOn.
  ///
  /// In it, this message translates to:
  /// **'Dato il {date}'**
  String givenOn(String date);

  /// No description provided for @givenSavedSnack.
  ///
  /// In it, this message translates to:
  /// **'Dato. È annotato.'**
  String get givenSavedSnack;

  /// No description provided for @transferDateFutureError.
  ///
  /// In it, this message translates to:
  /// **'La data non può essere nel futuro.'**
  String get transferDateFutureError;

  /// No description provided for @resolveLoanBeforeGive.
  ///
  /// In it, this message translates to:
  /// **'Segna prima l\'oggetto come restituito.'**
  String get resolveLoanBeforeGive;

  /// No description provided for @reacquireAction.
  ///
  /// In it, this message translates to:
  /// **'Torna tra i miei oggetti'**
  String get reacquireAction;

  /// No description provided for @reacquireTitle.
  ///
  /// In it, this message translates to:
  /// **'Torna tra i miei oggetti'**
  String get reacquireTitle;

  /// No description provided for @reacquireDateLabel.
  ///
  /// In it, this message translates to:
  /// **'Quando è tornato'**
  String get reacquireDateLabel;

  /// No description provided for @reacquiredTimeline.
  ///
  /// In it, this message translates to:
  /// **'Tornato tra i tuoi oggetti'**
  String get reacquiredTimeline;

  /// No description provided for @reacquiredSnack.
  ///
  /// In it, this message translates to:
  /// **'Bentornato tra le tue cose.'**
  String get reacquiredSnack;

  /// No description provided for @reacquireBeforeTransferError.
  ///
  /// In it, this message translates to:
  /// **'Non può essere prima di quando l\'hai dato.'**
  String get reacquireBeforeTransferError;

  /// No description provided for @backupMenu.
  ///
  /// In it, this message translates to:
  /// **'Backup e ripristino'**
  String get backupMenu;

  /// No description provided for @backupTitle.
  ///
  /// In it, this message translates to:
  /// **'Backup e ripristino'**
  String get backupTitle;

  /// No description provided for @backupIntro.
  ///
  /// In it, this message translates to:
  /// **'I tuoi dati restano sul dispositivo. Puoi creare un file che contiene il database e le foto di Pole².'**
  String get backupIntro;

  /// No description provided for @backupReassure.
  ///
  /// In it, this message translates to:
  /// **'Il backup resta a te: nessun cloud, nessun account. Custodiscilo dove preferisci.'**
  String get backupReassure;

  /// No description provided for @backupSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Backup'**
  String get backupSectionTitle;

  /// No description provided for @backupCreate.
  ///
  /// In it, this message translates to:
  /// **'Crea backup'**
  String get backupCreate;

  /// No description provided for @backupEncryptToggle.
  ///
  /// In it, this message translates to:
  /// **'Proteggi con password (consigliato)'**
  String get backupEncryptToggle;

  /// No description provided for @backupPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get backupPasswordLabel;

  /// No description provided for @backupPasswordConfirmLabel.
  ///
  /// In it, this message translates to:
  /// **'Conferma password'**
  String get backupPasswordConfirmLabel;

  /// No description provided for @backupPasswordWarning.
  ///
  /// In it, this message translates to:
  /// **'Questa password protegge il backup. Se la dimentichi, non sarà possibile recuperarlo.'**
  String get backupPasswordWarning;

  /// No description provided for @backupPasswordTooShort.
  ///
  /// In it, this message translates to:
  /// **'Usa almeno 10 caratteri.'**
  String get backupPasswordTooShort;

  /// No description provided for @backupPasswordMismatch.
  ///
  /// In it, this message translates to:
  /// **'Le password non coincidono.'**
  String get backupPasswordMismatch;

  /// No description provided for @backupPlaintextToggle.
  ///
  /// In it, this message translates to:
  /// **'Crea un backup senza password'**
  String get backupPlaintextToggle;

  /// No description provided for @backupPlaintextWarning.
  ///
  /// In it, this message translates to:
  /// **'Questo backup non è protetto: chi ha il file può vederne il contenuto.'**
  String get backupPlaintextWarning;

  /// No description provided for @backupWorking.
  ///
  /// In it, this message translates to:
  /// **'Sto preparando il backup…'**
  String get backupWorking;

  /// No description provided for @backupSaving.
  ///
  /// In it, this message translates to:
  /// **'Sto salvando…'**
  String get backupSaving;

  /// No description provided for @backupSuccess.
  ///
  /// In it, this message translates to:
  /// **'Backup creato. Ora è al sicuro dove hai scelto di conservarlo.'**
  String get backupSuccess;

  /// No description provided for @backupFailure.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a creare il backup. I tuoi dati sono rimasti al loro posto.'**
  String get backupFailure;

  /// No description provided for @backupIncomplete.
  ///
  /// In it, this message translates to:
  /// **'Manca la foto di «{object}». Aggiungila o rimuovila, poi riprova.'**
  String backupIncomplete(String object);

  /// No description provided for @backupLowSpace.
  ///
  /// In it, this message translates to:
  /// **'Spazio insufficiente per creare il backup.'**
  String get backupLowSpace;

  /// No description provided for @backupDormantMissingWarning.
  ///
  /// In it, this message translates to:
  /// **'Alcune foto non più presenti non sono state incluse.'**
  String get backupDormantMissingWarning;

  /// No description provided for @backupLastDate.
  ///
  /// In it, this message translates to:
  /// **'Ultimo backup: {date}'**
  String backupLastDate(String date);

  /// No description provided for @backupNever.
  ///
  /// In it, this message translates to:
  /// **'Nessun backup ancora.'**
  String get backupNever;

  /// No description provided for @restoreSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Ripristino'**
  String get restoreSectionTitle;

  /// No description provided for @restoreAction.
  ///
  /// In it, this message translates to:
  /// **'Ripristina da backup'**
  String get restoreAction;

  /// No description provided for @restoreComingSoon.
  ///
  /// In it, this message translates to:
  /// **'Disponibile nel prossimo aggiornamento.'**
  String get restoreComingSoon;

  /// No description provided for @restoreIntro.
  ///
  /// In it, this message translates to:
  /// **'Scegli un file di backup di Pole² per riportare qui i tuoi dati.'**
  String get restoreIntro;

  /// No description provided for @restoreReplaceWarning.
  ///
  /// In it, this message translates to:
  /// **'Il ripristino sostituisce i dati attuali di Pole² con quelli del backup. Le cose che hai adesso su questo dispositivo verranno rimpiazzate.'**
  String get restoreReplaceWarning;

  /// No description provided for @restoreConfirm.
  ///
  /// In it, this message translates to:
  /// **'Ho capito, ripristina'**
  String get restoreConfirm;

  /// No description provided for @restorePasswordTitle.
  ///
  /// In it, this message translates to:
  /// **'Password del backup'**
  String get restorePasswordTitle;

  /// No description provided for @restorePasswordPrompt.
  ///
  /// In it, this message translates to:
  /// **'Questo backup è protetto. Inserisci la password.'**
  String get restorePasswordPrompt;

  /// No description provided for @restoreSummaryTitle.
  ///
  /// In it, this message translates to:
  /// **'Contenuto del backup'**
  String get restoreSummaryTitle;

  /// No description provided for @restoreSummaryCounts.
  ///
  /// In it, this message translates to:
  /// **'{objects} oggetti · {photos} foto · {places} luoghi · {people} persone'**
  String restoreSummaryCounts(int objects, int photos, int places, int people);

  /// No description provided for @restoreSummaryCreated.
  ///
  /// In it, this message translates to:
  /// **'Creato il {date}'**
  String restoreSummaryCreated(String date);

  /// No description provided for @restoreMigratedNote.
  ///
  /// In it, this message translates to:
  /// **'Backup di una versione precedente: verrà aggiornato durante il ripristino.'**
  String get restoreMigratedNote;

  /// No description provided for @restorePreparing.
  ///
  /// In it, this message translates to:
  /// **'Sto verificando il backup…'**
  String get restorePreparing;

  /// No description provided for @restoreCloseTitle.
  ///
  /// In it, this message translates to:
  /// **'Quasi fatto'**
  String get restoreCloseTitle;

  /// No description provided for @restoreCloseBody.
  ///
  /// In it, this message translates to:
  /// **'Pole² verrà chiusa per completare il ripristino. Riaprila per continuare.'**
  String get restoreCloseBody;

  /// No description provided for @restoreCloseButton.
  ///
  /// In it, this message translates to:
  /// **'Chiudi Pole²'**
  String get restoreCloseButton;

  /// No description provided for @restoreClosing.
  ///
  /// In it, this message translates to:
  /// **'Chiusura…'**
  String get restoreClosing;

  /// No description provided for @restoreCloseManual.
  ///
  /// In it, this message translates to:
  /// **'Chiudi Pole² dalle applicazioni recenti e riaprila per completare il ripristino.'**
  String get restoreCloseManual;

  /// No description provided for @restoreErrPrepareFailed.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a preparare il ripristino. I tuoi dati sono rimasti al loro posto.'**
  String get restoreErrPrepareFailed;

  /// No description provided for @restoreDoneMessage.
  ///
  /// In it, this message translates to:
  /// **'Backup ripristinato. Le tue cose sono di nuovo al loro posto.'**
  String get restoreDoneMessage;

  /// No description provided for @restoreFailedMessage.
  ///
  /// In it, this message translates to:
  /// **'Ripristino non riuscito. I tuoi dati sono rimasti al loro posto.'**
  String get restoreFailedMessage;

  /// No description provided for @restoreErrNewer.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna Pole² per aprire questo backup.'**
  String get restoreErrNewer;

  /// No description provided for @restoreErrPassword.
  ///
  /// In it, this message translates to:
  /// **'Password errata oppure backup danneggiato.'**
  String get restoreErrPassword;

  /// No description provided for @restoreErrIncompleteMedia.
  ///
  /// In it, this message translates to:
  /// **'Nel backup mancano delle foto necessarie.'**
  String get restoreErrIncompleteMedia;

  /// No description provided for @restoreErrLowSpace.
  ///
  /// In it, this message translates to:
  /// **'Spazio insufficiente per il ripristino.'**
  String get restoreErrLowSpace;

  /// No description provided for @restoreErrAccess.
  ///
  /// In it, this message translates to:
  /// **'Pole² non ha ricevuto l\'accesso al file scelto. Prova a selezionarlo di nuovo.'**
  String get restoreErrAccess;

  /// No description provided for @restoreErrUnreadable.
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile leggere il file scelto. Riprova.'**
  String get restoreErrUnreadable;

  /// No description provided for @restoreErrEmpty.
  ///
  /// In it, this message translates to:
  /// **'Il file scelto è vuoto.'**
  String get restoreErrEmpty;

  /// No description provided for @restoreErrNotBackup.
  ///
  /// In it, this message translates to:
  /// **'Questo file non è un backup di Pole².'**
  String get restoreErrNotBackup;

  /// No description provided for @restoreErrGeneric.
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile leggere il backup.'**
  String get restoreErrGeneric;
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
