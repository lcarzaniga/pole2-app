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

  /// No description provided for @actionPhoto.
  ///
  /// In it, this message translates to:
  /// **'Dalla foto'**
  String get actionPhoto;

  /// No description provided for @actionObject.
  ///
  /// In it, this message translates to:
  /// **'Dal nome'**
  String get actionObject;

  /// No description provided for @a11yActionPhoto.
  ///
  /// In it, this message translates to:
  /// **'Crea un oggetto partendo da una foto'**
  String get a11yActionPhoto;

  /// No description provided for @a11yActionObject.
  ///
  /// In it, this message translates to:
  /// **'Crea un oggetto partendo dal nome'**
  String get a11yActionObject;

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

  /// No description provided for @recordEditorTitleNew.
  ///
  /// In it, this message translates to:
  /// **'Nota'**
  String get recordEditorTitleNew;

  /// No description provided for @recordEditorTitleEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get recordEditorTitleEdit;

  /// No description provided for @recordDescriptionLabel.
  ///
  /// In it, this message translates to:
  /// **'Descrizione'**
  String get recordDescriptionLabel;

  /// No description provided for @recordDescriptionHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi una nota…'**
  String get recordDescriptionHint;

  /// No description provided for @recordDetailsToggle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi dettagli'**
  String get recordDetailsToggle;

  /// No description provided for @recordCategoryLabel.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get recordCategoryLabel;

  /// No description provided for @recordReferenceDateLabel.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get recordReferenceDateLabel;

  /// No description provided for @recordValidityLabel.
  ///
  /// In it, this message translates to:
  /// **'Validità'**
  String get recordValidityLabel;

  /// No description provided for @recordValidityAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una scadenza'**
  String get recordValidityAdd;

  /// No description provided for @recordValidityEndPrefix.
  ///
  /// In it, this message translates to:
  /// **'Scade il'**
  String get recordValidityEndPrefix;

  /// No description provided for @recordRemindMe.
  ///
  /// In it, this message translates to:
  /// **'Ricordamelo'**
  String get recordRemindMe;

  /// No description provided for @recordAttachmentsLabel.
  ///
  /// In it, this message translates to:
  /// **'Documenti'**
  String get recordAttachmentsLabel;

  /// No description provided for @recordAttachmentAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un documento'**
  String get recordAttachmentAdd;

  /// No description provided for @attachmentAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi allegato'**
  String get attachmentAdd;

  /// No description provided for @attachSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un allegato'**
  String get attachSheetTitle;

  /// No description provided for @attachChoosePhoto.
  ///
  /// In it, this message translates to:
  /// **'Scegli una foto'**
  String get attachChoosePhoto;

  /// No description provided for @attachChooseDocument.
  ///
  /// In it, this message translates to:
  /// **'Scegli un documento'**
  String get attachChooseDocument;

  /// No description provided for @attachmentPhotoDefaultLabel.
  ///
  /// In it, this message translates to:
  /// **'Foto'**
  String get attachmentPhotoDefaultLabel;

  /// No description provided for @recordSwitchToNoteTitle.
  ///
  /// In it, this message translates to:
  /// **'Passare a Nota?'**
  String get recordSwitchToNoteTitle;

  /// No description provided for @recordSwitchToNoteBody.
  ///
  /// In it, this message translates to:
  /// **'Una nota semplice non conserva data, scadenza, promemoria o documenti. Vuoi rimuoverli?'**
  String get recordSwitchToNoteBody;

  /// No description provided for @recordSwitchToNoteConfirm.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi e continua'**
  String get recordSwitchToNoteConfirm;

  /// No description provided for @recordValidUntil.
  ///
  /// In it, this message translates to:
  /// **'Valido fino al {date}'**
  String recordValidUntil(Object date);

  /// No description provided for @catNote.
  ///
  /// In it, this message translates to:
  /// **'Nota'**
  String get catNote;

  /// No description provided for @catPurchase.
  ///
  /// In it, this message translates to:
  /// **'Acquisto / ricevuta'**
  String get catPurchase;

  /// No description provided for @catWarranty.
  ///
  /// In it, this message translates to:
  /// **'Garanzia'**
  String get catWarranty;

  /// No description provided for @catManual.
  ///
  /// In it, this message translates to:
  /// **'Manuale / documentazione'**
  String get catManual;

  /// No description provided for @catMaintenance.
  ///
  /// In it, this message translates to:
  /// **'Manutenzione'**
  String get catMaintenance;

  /// No description provided for @catInsurance.
  ///
  /// In it, this message translates to:
  /// **'Assicurazione / certificato'**
  String get catInsurance;

  /// No description provided for @catOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get catOther;

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

  /// No description provided for @updateRestoreBusy.
  ///
  /// In it, this message translates to:
  /// **'Un ripristino è in corso. Riapri Pole² e completa il ripristino prima di aggiornare.'**
  String get updateRestoreBusy;

  /// No description provided for @updateBackupTitle.
  ///
  /// In it, this message translates to:
  /// **'Prima di aggiornare, vuoi creare un backup?'**
  String get updateBackupTitle;

  /// No description provided for @updateBackupBody.
  ///
  /// In it, this message translates to:
  /// **'È consigliato per questo aggiornamento. Il backup resta a te e puoi salvarlo dove preferisci.'**
  String get updateBackupBody;

  /// No description provided for @updateBackupCreate.
  ///
  /// In it, this message translates to:
  /// **'Crea backup'**
  String get updateBackupCreate;

  /// No description provided for @updateBackupContinueWithout.
  ///
  /// In it, this message translates to:
  /// **'Continua senza backup'**
  String get updateBackupContinueWithout;

  /// No description provided for @updateBackupScreenIntro.
  ///
  /// In it, this message translates to:
  /// **'Crea un backup prima di installare l\'aggiornamento. Al termine, l\'aggiornamento riprende da solo.'**
  String get updateBackupScreenIntro;

  /// No description provided for @updateWithoutTitle.
  ///
  /// In it, this message translates to:
  /// **'Vuoi continuare senza creare un backup?'**
  String get updateWithoutTitle;

  /// No description provided for @updateWithoutBody.
  ///
  /// In it, this message translates to:
  /// **'Di solito l\'aggiornamento mantiene i tuoi dati, ma per questa versione è consigliato un backup.'**
  String get updateWithoutBody;

  /// No description provided for @updateWithoutContinue.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get updateWithoutContinue;

  /// No description provided for @updateWithoutBack.
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get updateWithoutBack;

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

  /// No description provided for @documentOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri'**
  String get documentOpen;

  /// No description provided for @documentOpenFailed.
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile aprire il documento. Riprova quando vuoi.'**
  String get documentOpenFailed;

  /// No description provided for @documentOpenNoApp.
  ///
  /// In it, this message translates to:
  /// **'Nessuna app disponibile per aprire questo tipo di documento.'**
  String get documentOpenNoApp;

  /// No description provided for @documentMissing.
  ///
  /// In it, this message translates to:
  /// **'Questo documento non è più disponibile.'**
  String get documentMissing;

  /// No description provided for @documentRemoveTooltip.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi documento'**
  String get documentRemoveTooltip;

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
  /// **'Dove si trova'**
  String get filterTooltip;

  /// No description provided for @filterNoPlace.
  ///
  /// In it, this message translates to:
  /// **'Senza luogo'**
  String get filterNoPlace;

  /// No description provided for @custodyAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get custodyAll;

  /// No description provided for @custodyInPlace.
  ///
  /// In it, this message translates to:
  /// **'In: {path}'**
  String custodyInPlace(String path);

  /// No description provided for @custodyWithPerson.
  ///
  /// In it, this message translates to:
  /// **'Con: {name}'**
  String custodyWithPerson(String name);

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

  /// No description provided for @peopleMenu.
  ///
  /// In it, this message translates to:
  /// **'Persone'**
  String get peopleMenu;

  /// No description provided for @peopleTitle.
  ///
  /// In it, this message translates to:
  /// **'Persone'**
  String get peopleTitle;

  /// No description provided for @peopleSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca una persona'**
  String get peopleSearchHint;

  /// No description provided for @peopleEmpty.
  ///
  /// In it, this message translates to:
  /// **'Le persone a cui presti o dai qualcosa compaiono qui.'**
  String get peopleEmpty;

  /// No description provided for @peopleAddTooltip.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi persona'**
  String get peopleAddTooltip;

  /// No description provided for @peopleAddTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi persona'**
  String get peopleAddTitle;

  /// No description provided for @peopleCountLent.
  ///
  /// In it, this message translates to:
  /// **'{count} in prestito'**
  String peopleCountLent(int count);

  /// No description provided for @peopleCountGiven.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 dato} other{{count} dati}}'**
  String peopleCountGiven(int count);

  /// No description provided for @personSectionLent.
  ///
  /// In it, this message translates to:
  /// **'In prestito'**
  String get personSectionLent;

  /// No description provided for @personSectionGiven.
  ///
  /// In it, this message translates to:
  /// **'Dati'**
  String get personSectionGiven;

  /// No description provided for @personSectionHistory.
  ///
  /// In it, this message translates to:
  /// **'Storico'**
  String get personSectionHistory;

  /// No description provided for @personGivenOn.
  ///
  /// In it, this message translates to:
  /// **'Dato il {date}'**
  String personGivenOn(String date);

  /// No description provided for @personHistReturned.
  ///
  /// In it, this message translates to:
  /// **'Restituito il {date}'**
  String personHistReturned(String date);

  /// No description provided for @personHistGiven.
  ///
  /// In it, this message translates to:
  /// **'Dato il {date}'**
  String personHistGiven(String date);

  /// No description provided for @personHistReacquired.
  ///
  /// In it, this message translates to:
  /// **'Ripreso il {date}'**
  String personHistReacquired(String date);

  /// No description provided for @personEmpty.
  ///
  /// In it, this message translates to:
  /// **'Ancora nessun collegamento con le tue cose.'**
  String get personEmpty;

  /// No description provided for @personRename.
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get personRename;

  /// No description provided for @personRenameTitle.
  ///
  /// In it, this message translates to:
  /// **'Rinomina persona'**
  String get personRenameTitle;

  /// No description provided for @personRenameDuplicate.
  ///
  /// In it, this message translates to:
  /// **'Esiste già una persona con questo nome.'**
  String get personRenameDuplicate;

  /// No description provided for @personDelete.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get personDelete;

  /// No description provided for @personDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere {name}?'**
  String personDeleteTitle(String name);

  /// No description provided for @personDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'La cronologia resta leggibile. Puoi rimuovere una persona solo quando non ha nulla in prestito o che le hai dato.'**
  String get personDeleteBody;

  /// No description provided for @personDeleteBlocked.
  ///
  /// In it, this message translates to:
  /// **'Non puoi rimuovere {name} finché ha qualcosa in prestito o che le hai dato.'**
  String personDeleteBlocked(String name);

  /// No description provided for @personDeletedSnack.
  ///
  /// In it, this message translates to:
  /// **'Persona rimossa.'**
  String get personDeletedSnack;

  /// No description provided for @infoMenu.
  ///
  /// In it, this message translates to:
  /// **'Informazioni e supporto'**
  String get infoMenu;

  /// No description provided for @infoTitle.
  ///
  /// In it, this message translates to:
  /// **'Informazioni e supporto'**
  String get infoTitle;

  /// No description provided for @infoSlogan.
  ///
  /// In it, this message translates to:
  /// **'Custodisci ciò che conta, conta ciò che custodisci.'**
  String get infoSlogan;

  /// The installed version and build, read at runtime from the package itself — never hard-coded.
  ///
  /// In it, this message translates to:
  /// **'Versione {version} · build {build}'**
  String infoVersion(String version, String build);

  /// No description provided for @infoVersionUnknown.
  ///
  /// In it, this message translates to:
  /// **'Versione non disponibile'**
  String get infoVersionUnknown;

  /// No description provided for @infoLocalFirst.
  ///
  /// In it, this message translates to:
  /// **'I dati di Pole² restano sul tuo dispositivo, salvo i backup che scegli di esportare.'**
  String get infoLocalFirst;

  /// No description provided for @infoLinksTitle.
  ///
  /// In it, this message translates to:
  /// **'Sul sito'**
  String get infoLinksTitle;

  /// No description provided for @infoLinkSite.
  ///
  /// In it, this message translates to:
  /// **'Sito di Pole²'**
  String get infoLinkSite;

  /// No description provided for @infoLinkSiteSub.
  ///
  /// In it, this message translates to:
  /// **'La casa pubblica di Pole²'**
  String get infoLinkSiteSub;

  /// No description provided for @infoLinkGuide.
  ///
  /// In it, this message translates to:
  /// **'Guida'**
  String get infoLinkGuide;

  /// No description provided for @infoLinkGuideSub.
  ///
  /// In it, this message translates to:
  /// **'Come si usa, con calma'**
  String get infoLinkGuideSub;

  /// No description provided for @infoLinkNews.
  ///
  /// In it, this message translates to:
  /// **'Novità'**
  String get infoLinkNews;

  /// No description provided for @infoLinkNewsSub.
  ///
  /// In it, this message translates to:
  /// **'Cosa è cambiato'**
  String get infoLinkNewsSub;

  /// No description provided for @infoLinkSupport.
  ///
  /// In it, this message translates to:
  /// **'Supporto'**
  String get infoLinkSupport;

  /// No description provided for @infoLinkSupportSub.
  ///
  /// In it, this message translates to:
  /// **'Scrivici se qualcosa non torna'**
  String get infoLinkSupportSub;

  /// No description provided for @infoLinkPrivacy.
  ///
  /// In it, this message translates to:
  /// **'Privacy'**
  String get infoLinkPrivacy;

  /// No description provided for @infoLinkPrivacySub.
  ///
  /// In it, this message translates to:
  /// **'Cosa resta sul dispositivo'**
  String get infoLinkPrivacySub;

  /// Spoken label for a link row: the purpose plus the fact that it leaves the app.
  ///
  /// In it, this message translates to:
  /// **'{label}. Si apre nel browser.'**
  String infoLinkSemantics(String label);

  /// No description provided for @infoLinkFootnote.
  ///
  /// In it, this message translates to:
  /// **'I link si aprono nel tuo browser. Il supporto riceve solo la versione installata.'**
  String get infoLinkFootnote;

  /// No description provided for @infoOpenFailed.
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile aprire il link. Puoi visitare pole2.app dal tuo browser.'**
  String get infoOpenFailed;

  /// No description provided for @infoOpenNoBrowser.
  ///
  /// In it, this message translates to:
  /// **'Non c\'è un browser su questo dispositivo. Puoi visitare pole2.app da un altro dispositivo.'**
  String get infoOpenNoBrowser;

  /// No description provided for @infoLegalTitle.
  ///
  /// In it, this message translates to:
  /// **'Sull\'app'**
  String get infoLegalTitle;

  /// No description provided for @infoLicenses.
  ///
  /// In it, this message translates to:
  /// **'Licenze open source'**
  String get infoLicenses;

  /// No description provided for @infoLicensesSub.
  ///
  /// In it, this message translates to:
  /// **'Le librerie che rendono possibile Pole²'**
  String get infoLicensesSub;

  /// Spoken label for the licenses row: the purpose plus the fact that it stays inside the app (no browser).
  ///
  /// In it, this message translates to:
  /// **'{label}. Rimane nell\'app.'**
  String infoLicensesSemantics(String label);

  /// No description provided for @infoLicensesLegalese.
  ///
  /// In it, this message translates to:
  /// **'Pole² conserva i tuoi dati sul dispositivo. Le librerie open source elencate qui mantengono ciascuna la propria licenza.'**
  String get infoLicensesLegalese;

  /// No description provided for @permanentDeleteAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina definitivamente'**
  String get permanentDeleteAction;

  /// Confirmation dialog title for permanently deleting one removed possession.
  ///
  /// In it, this message translates to:
  /// **'Eliminare definitivamente «{title}»?'**
  String permanentDeleteTitle(String title);

  /// No description provided for @permanentDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'Questa azione non può essere annullata. L\'oggetto, la sua cronologia e le sue foto verranno eliminati da questo dispositivo. Le persone e i luoghi collegati restano. Un backup creato prima d\'ora conterrà ancora questo oggetto: ripristinando quel backup, l\'oggetto potrà tornare.'**
  String get permanentDeleteBody;

  /// No description provided for @permanentDeleteConfirm.
  ///
  /// In it, this message translates to:
  /// **'Elimina definitivamente'**
  String get permanentDeleteConfirm;

  /// No description provided for @permanentDeleteCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get permanentDeleteCancel;

  /// Success snackbar after permanent deletion.
  ///
  /// In it, this message translates to:
  /// **'«{title}» eliminato da questo dispositivo.'**
  String permanentDeleteDoneSnack(String title);

  /// Shown when the rows were deleted but some orphan files could not be removed now.
  ///
  /// In it, this message translates to:
  /// **'«{title}» è stato eliminato. Alcuni file verranno recuperati più tardi con «Libera spazio».'**
  String permanentDeletePartialSnack(String title);

  /// Shown when permanent deletion did not happen (nothing changed).
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile eliminare «{title}». Nulla è stato modificato.'**
  String permanentDeleteFailedSnack(String title);

  /// No description provided for @permanentDeleteBlockedBackup.
  ///
  /// In it, this message translates to:
  /// **'Un backup è in corso. Attendi che finisca prima di eliminare.'**
  String get permanentDeleteBlockedBackup;

  /// No description provided for @permanentDeleteBlockedRestore.
  ///
  /// In it, this message translates to:
  /// **'Un ripristino è in corso. Completalo prima di eliminare definitivamente.'**
  String get permanentDeleteBlockedRestore;

  /// No description provided for @selectAction.
  ///
  /// In it, this message translates to:
  /// **'Seleziona'**
  String get selectAction;

  /// Contextual app bar title while selecting removed items.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 selezionato} other{{count} selezionati}}'**
  String selectionCount(int count);

  /// No description provided for @selectionClose.
  ///
  /// In it, this message translates to:
  /// **'Chiudi selezione'**
  String get selectionClose;

  /// No description provided for @selectAll.
  ///
  /// In it, this message translates to:
  /// **'Seleziona tutto'**
  String get selectAll;

  /// No description provided for @selectAllResults.
  ///
  /// In it, this message translates to:
  /// **'Seleziona tutti i risultati'**
  String get selectAllResults;

  /// Confirmation dialog title for permanently deleting several removed possessions.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Eliminare definitivamente 1 oggetto?} other{Eliminare definitivamente {count} oggetti?}}'**
  String permanentDeleteManyTitle(int count);

  /// No description provided for @permanentDeleteManyBody.
  ///
  /// In it, this message translates to:
  /// **'Questa azione non può essere annullata. Gli oggetti selezionati, la loro cronologia e le foto usate soltanto da loro verranno eliminati da questo dispositivo. Le persone e i luoghi collegati restano. Un backup creato in precedenza potrà riportare questi oggetti.'**
  String get permanentDeleteManyBody;

  /// Success snackbar after batch permanent deletion.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 oggetto eliminato da questo dispositivo.} other{{count} oggetti eliminati da questo dispositivo.}}'**
  String permanentDeleteManyDoneSnack(int count);

  /// Batch deletion succeeded but some orphan files could not be removed now.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 oggetto eliminato. Alcuni file verranno recuperati più tardi con «Libera spazio».} other{{count} oggetti eliminati. Alcuni file verranno recuperati più tardi con «Libera spazio».}}'**
  String permanentDeleteManyPartialSnack(int count);

  /// No description provided for @permanentDeleteManyFailedSnack.
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile eliminare gli oggetti selezionati. Nulla è stato modificato.'**
  String get permanentDeleteManyFailedSnack;

  /// No description provided for @permanentDeleteStaleSnack.
  ///
  /// In it, this message translates to:
  /// **'La selezione è cambiata. Nulla è stato eliminato.'**
  String get permanentDeleteStaleSnack;

  /// No description provided for @storageSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Spazio sul dispositivo'**
  String get storageSectionTitle;

  /// No description provided for @storageBody.
  ///
  /// In it, this message translates to:
  /// **'Pole² può cercare fotografie che non appartengono più ad alcun oggetto.'**
  String get storageBody;

  /// No description provided for @storageScanAction.
  ///
  /// In it, this message translates to:
  /// **'Controlla lo spazio'**
  String get storageScanAction;

  /// No description provided for @storageScanning.
  ///
  /// In it, this message translates to:
  /// **'Sto controllando lo spazio…'**
  String get storageScanning;

  /// No description provided for @storageNoCandidates.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono file inutilizzati da rimuovere.'**
  String get storageNoCandidates;

  /// Shown after a scan finds reclaimable orphan photos; {size} is a human byte size.
  ///
  /// In it, this message translates to:
  /// **'Puoi liberare circa {size}. Verranno rimosse soltanto fotografie che Pole² non utilizza più. Backup e dati recuperabili non verranno toccati.'**
  String storageCandidates(String size);

  /// No description provided for @storageCleanCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get storageCleanCancel;

  /// No description provided for @storageCleanAction.
  ///
  /// In it, this message translates to:
  /// **'Libera spazio'**
  String get storageCleanAction;

  /// No description provided for @storageCleaning.
  ///
  /// In it, this message translates to:
  /// **'Sto liberando spazio…'**
  String get storageCleaning;

  /// Completion message after freeing space; {size} is a human byte size.
  ///
  /// In it, this message translates to:
  /// **'Spazio liberato: {size}.'**
  String storageDone(String size);

  /// Completion message when some files could not be removed; {size} is a human byte size.
  ///
  /// In it, this message translates to:
  /// **'Spazio liberato: {size}. Alcuni file non sono stati rimossi.'**
  String storagePartial(String size);

  /// No description provided for @storageScanFailed.
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile controllare lo spazio. Nulla è stato modificato.'**
  String get storageScanFailed;

  /// No description provided for @storageBlockedBackup.
  ///
  /// In it, this message translates to:
  /// **'Un backup è in corso. Attendi che finisca prima di liberare spazio.'**
  String get storageBlockedBackup;

  /// No description provided for @storageBlockedRestore.
  ///
  /// In it, this message translates to:
  /// **'Un ripristino è in corso. Completalo prima di liberare spazio.'**
  String get storageBlockedRestore;

  /// No description provided for @storageBlockedPermanentDelete.
  ///
  /// In it, this message translates to:
  /// **'Un\'eliminazione è in corso. Attendi che finisca prima di liberare spazio.'**
  String get storageBlockedPermanentDelete;

  /// No description provided for @mediaSaveBlockedBackup.
  ///
  /// In it, this message translates to:
  /// **'Un backup è in corso. Riprova a salvare la foto tra poco.'**
  String get mediaSaveBlockedBackup;

  /// No description provided for @mediaSaveBlockedRestore.
  ///
  /// In it, this message translates to:
  /// **'Un ripristino è in corso. Completalo prima di salvare la foto.'**
  String get mediaSaveBlockedRestore;

  /// No description provided for @mediaSaveBlockedBusy.
  ///
  /// In it, this message translates to:
  /// **'Un\'operazione è in corso. Riprova a salvare la foto tra poco.'**
  String get mediaSaveBlockedBusy;

  /// No description provided for @mediaSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile salvare la foto. Nulla è stato modificato.'**
  String get mediaSaveFailed;
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
