// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Pole²';

  @override
  String get homeEmptyTitle => 'A calm home for your things';

  @override
  String get homeEmptyBody =>
      'Tutto ciò a cui tieni può vivere qui — al sicuro, e solo su questo dispositivo.';

  @override
  String get homeEmptyCta => 'Tap to begin';

  @override
  String get privacyLine => 'Everything stays on this device';

  @override
  String get a11yKeepSomething => 'Conserva qualcosa';

  @override
  String get a11yClose => 'Chiudi';

  @override
  String get actionPhoto => 'Dalla foto';

  @override
  String get actionObject => 'Dal nome';

  @override
  String get a11yActionPhoto => 'Crea un oggetto partendo da una foto';

  @override
  String get a11yActionObject => 'Crea un oggetto partendo dal nome';

  @override
  String get photoSourceTitle => 'Aggiungi una foto';

  @override
  String get photoTakePhoto => 'Scatta una foto';

  @override
  String get photoChooseGallery => 'Scegli dalla galleria';

  @override
  String get cameraDeniedSnack =>
      'Pole² non può ancora usare la fotocamera. Puoi autorizzarla dalle impostazioni.';

  @override
  String get captureFailedSnack => 'Nulla è andato perso. Riprova quando vuoi.';

  @override
  String get createTitle => 'Conserva qualcosa';

  @override
  String get whatIsItLabel => 'Che cos\'è?';

  @override
  String get createHint => 'es. Lavastoviglie, l\'orologio del nonno, l\'auto';

  @override
  String get createReassure =>
      'Puoi aggiungere foto, ricevute e dettagli quando vuoi. Per ora non serve altro.';

  @override
  String get keepItButton => 'Keep';

  @override
  String upcomingDatesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count date in arrivo',
      one: '1 data in arrivo',
    );
    return '$_temp0';
  }

  @override
  String get addPhoto => 'Aggiungi una foto';

  @override
  String get renameTooltip => 'Rinomina';

  @override
  String get nameLabel => 'Nome';

  @override
  String get saveButton => 'Save';

  @override
  String keptOn(String date) {
    return 'Conservato il $date';
  }

  @override
  String nextUp(String what) {
    return 'Prossimo: $what';
  }

  @override
  String get detailsTitle => 'Dettagli';

  @override
  String get detailsEmptySubtitle =>
      'Da dove viene, quanto è costato, quando l\'hai preso.';

  @override
  String get tapToAddMore => 'Tocca per aggiungere altro';

  @override
  String get documentsTitle => 'Documenti';

  @override
  String get documentsSubtitle => 'Qui vivono ricevute, manuali e garanzie.';

  @override
  String get historyTitle => 'Storia';

  @override
  String get addDate => 'Aggiungi una data';

  @override
  String get historyEmpty =>
      'Ancora niente — aggiungi come l\'hai preso, o una data da ricordare.';

  @override
  String onDate(String date) {
    return 'il $date';
  }

  @override
  String get menuRename => 'Rinomina';

  @override
  String get menuPutAway => 'Metti via';

  @override
  String get menuRemove => 'Rimuovi';

  @override
  String get archivedSnack => 'Messo via. È al sicuro.';

  @override
  String get removedSnack => 'Rimosso. Non è ancora perso nulla.';

  @override
  String get eventRemovedSnack => 'Rimosso.';

  @override
  String get undo => 'Undo';

  @override
  String get errorNothingLost =>
      'Qualcosa è andato storto — ma non è andato perso nulla.';

  @override
  String get goneMessage => 'Non è più qui.';

  @override
  String boughtAt(String supplier) {
    return 'Comprato da $supplier';
  }

  @override
  String get bought => 'Comprato';

  @override
  String get receivedAsGift => 'Ricevuto in regalo';

  @override
  String get inheritedHeadline => 'Ereditato';

  @override
  String get alreadyHadHeadline => 'Ce l\'avevo già';

  @override
  String get keptHeadline => 'Conservato';

  @override
  String fromSupplier(String supplier) {
    return 'Da $supplier';
  }

  @override
  String get purchaseDetailsHeadline => 'Dettagli d\'acquisto';

  @override
  String get acquisitionTitle => 'Dettagli d\'acquisto';

  @override
  String get howDidYouGetIt => 'Come l\'hai avuto?';

  @override
  String get acqTypeBought => 'Comprato';

  @override
  String get acqTypeGift => 'Regalo';

  @override
  String get acqTypeInherited => 'Ereditato';

  @override
  String get acqTypeAlreadyHad => 'Già mio';

  @override
  String get acqTypeOther => 'Altro';

  @override
  String get whenLabel => 'Quando';

  @override
  String get notSet => 'Non impostata';

  @override
  String get whereFromLabel => 'Da dove';

  @override
  String get whereFromHint => 'Negozio o persona';

  @override
  String get priceLabel => 'Prezzo';

  @override
  String get noteLabel => 'Nota';

  @override
  String get acquisitionReassure =>
      'Aggiungi quanto vuoi — puoi sempre tornarci.';

  @override
  String get reminderTitle => 'Aggiungi una data';

  @override
  String get reminderHint => 'es. Scadenza garanzia';

  @override
  String get suggWarranty => 'Scadenza garanzia';

  @override
  String get suggReturn => 'Fine reso';

  @override
  String get suggService => 'Manutenzione';

  @override
  String get suggInsurance => 'Rinnovo assicurazione';

  @override
  String get suggFilter => 'Cambio filtro';

  @override
  String get chooseDate => 'Scegli una data';

  @override
  String get remindMe => 'Ricordamelo';

  @override
  String get leadSameDay => 'Il giorno stesso';

  @override
  String get leadDayBefore => '1 giorno prima';

  @override
  String get leadWeekBefore => '1 settimana prima';

  @override
  String get leadMonthBefore => '1 mese prima';

  @override
  String get today => 'Oggi';

  @override
  String get tomorrow => 'Domani';

  @override
  String get yesterday => 'Ieri';

  @override
  String inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tra $count giorni',
      one: 'tra 1 giorno',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni fa',
      one: '1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String get noPlace => 'Nessun luogo';

  @override
  String get placeLabel => 'Luogo';

  @override
  String get placeAssignHint => 'Tocca per assegnare un luogo';

  @override
  String get placePickerTitle => 'Dove si trova?';

  @override
  String get newPlaceHint => 'Nuovo luogo — es. Garage, Ufficio';

  @override
  String get addPlaceButton => 'Aggiungi';

  @override
  String get placeManageTooltip => 'Gestisci';

  @override
  String get placeDelete => 'Elimina';

  @override
  String get placeRenameTitle => 'Rinomina luogo';

  @override
  String get cancelButton => 'Annulla';

  @override
  String placeDeleteTitle(String name) {
    return 'Eliminare «$name»?';
  }

  @override
  String placeDeleteAssigned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'È assegnato a $count oggetti, che torneranno a «Nessun luogo».',
      one: 'È assegnato a 1 oggetto, che tornerà a «Nessun luogo».',
    );
    return '$_temp0';
  }

  @override
  String get placeDeleteNone => 'Nessun oggetto usa questo luogo.';

  @override
  String get updateAvailableTitle => 'Aggiornamento disponibile';

  @override
  String updateAvailableBody(String version) {
    return 'È disponibile la versione $version.';
  }

  @override
  String get updateNow => 'Aggiorna';

  @override
  String get updateLater => 'Più tardi';

  @override
  String get updateDownloading => 'Scaricamento…';

  @override
  String get updateVerifying => 'Verifica…';

  @override
  String get updateInstalling => 'Avvio installazione…';

  @override
  String get updatePermissionNeeded =>
      'Per installare l\'aggiornamento, consenti l\'installazione di app da questa sorgente.';

  @override
  String get updateAllow => 'Consenti';

  @override
  String get updateRetry => 'Riprova';

  @override
  String get updateErrorDownload => 'Scaricamento non riuscito.';

  @override
  String get updateErrorSha => 'File di aggiornamento non valido.';

  @override
  String get updateErrorInstall => 'Installazione non riuscita.';

  @override
  String get updateRestoreBusy =>
      'Un ripristino è in corso. Riapri Pole² e completa il ripristino prima di aggiornare.';

  @override
  String get updateBackupTitle => 'Prima di aggiornare, vuoi creare un backup?';

  @override
  String get updateBackupBody =>
      'È consigliato per questo aggiornamento. Il backup resta a te e puoi salvarlo dove preferisci.';

  @override
  String get updateBackupCreate => 'Crea backup';

  @override
  String get updateBackupContinueWithout => 'Continua senza backup';

  @override
  String get updateBackupScreenIntro =>
      'Crea un backup prima di installare l\'aggiornamento. Al termine, l\'aggiornamento riprende da solo.';

  @override
  String get updateWithoutTitle => 'Vuoi continuare senza creare un backup?';

  @override
  String get updateWithoutBody =>
      'Di solito l\'aggiornamento mantiene i tuoi dati, ma per questa versione è consigliato un backup.';

  @override
  String get updateWithoutContinue => 'Continua';

  @override
  String get updateWithoutBack => 'Indietro';

  @override
  String get closeButton => 'Chiudi';

  @override
  String get placeContentsEmpty => 'Qui non c\'è ancora niente.';

  @override
  String get placeEmptyHint =>
      'Puoi assegnare un oggetto a questo luogo dalla sua scheda.';

  @override
  String placeItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oggetti',
      one: '1 oggetto',
      zero: 'Nessun oggetto',
    );
    return '$_temp0';
  }

  @override
  String get placeMoveAction => 'Sposta in un altro luogo';

  @override
  String get placeRemoveAction => 'Rimuovi dal luogo';

  @override
  String get placeMovedSnack => 'Oggetto spostato.';

  @override
  String get placeRemovedFromSnack => 'Rimosso dal luogo.';

  @override
  String get itemActionsTooltip => 'Opzioni';

  @override
  String get placeEditTooltip => 'Cambia luogo';

  @override
  String get noteEditorTitle => 'Aggiungi una nota';

  @override
  String get noteHint => 'Scrivi una nota…';

  @override
  String get addNote => 'Aggiungi una nota';

  @override
  String get addDocument => 'Aggiungi un documento';

  @override
  String get documentAdd => 'Aggiungi';

  @override
  String get documentRemovedSnack => 'Documento rimosso.';

  @override
  String get documentAddFailed => 'Nulla è andato perso. Riprova quando vuoi.';

  @override
  String get hubPhoto => 'Foto';

  @override
  String get hubNote => 'Nota';

  @override
  String get hubDocument => 'Documento';

  @override
  String get hubDate => 'Data';

  @override
  String get hubPlace => 'Luogo';

  @override
  String get searchHint => 'Cerca';

  @override
  String get searchClear => 'Cancella';

  @override
  String get searchNoResults => 'Nessun risultato';

  @override
  String get sortTooltip => 'Ordina';

  @override
  String get sortNewest => 'Più recenti';

  @override
  String get sortName => 'Nome';

  @override
  String get filterTooltip => 'Dove si trova';

  @override
  String get filterNoPlace => 'Senza luogo';

  @override
  String get custodyAll => 'Tutti';

  @override
  String custodyInPlace(String path) {
    return 'In: $path';
  }

  @override
  String custodyWithPerson(String name) {
    return 'Con: $name';
  }

  @override
  String get photoEditTooltip => 'Cambia foto';

  @override
  String get photoView => 'Vedi la foto';

  @override
  String get placeReviewStart => 'Riordina questo luogo';

  @override
  String get placeReviewKeep => 'Tieni qui';

  @override
  String get placeReviewMove => 'Sposta';

  @override
  String get placeReviewUnassign => 'Togli dal luogo';

  @override
  String get placeReviewArchive => 'Metti da parte';

  @override
  String get placeReviewDone => 'Fine';

  @override
  String get placeReviewAllSeen => 'Hai guardato tutto quello che c\'è qui.';

  @override
  String placeReviewGentleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cose qui',
      one: '1 cosa qui',
      zero: 'Niente qui',
    );
    return '$_temp0';
  }

  @override
  String get photoAddAnother => 'Aggiungi un\'altra foto';

  @override
  String get photoSetCover => 'Imposta come copertina';

  @override
  String get photoIsCover => 'Copertina';

  @override
  String get photoRemove => 'Rimuovi foto';

  @override
  String get photoRemovedSnack => 'Foto rimossa.';

  @override
  String photoPosition(int current, int total) {
    return '$current di $total';
  }

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String get lendToSomeone => 'Presta a qualcuno';

  @override
  String get lendEditTitle => 'Modifica prestito';

  @override
  String get borrowerLabel => 'A chi lo presti?';

  @override
  String get borrowerChoose => 'Scegli una persona';

  @override
  String get selectPerson => 'Scegli una persona';

  @override
  String get createPerson => 'Nuova persona';

  @override
  String get personNameHint => 'Nome';

  @override
  String get addPersonButton => 'Aggiungi';

  @override
  String get lentDateLabel => 'Data del prestito';

  @override
  String get expectedReturnLabel => 'Rientro previsto';

  @override
  String get expectedReturnOptional => 'Rientro previsto (facoltativo)';

  @override
  String get noReturnDate => 'Nessuna data di rientro';

  @override
  String get returnDateClear => 'Togli la data';

  @override
  String get returnReminder => 'Ricordami il rientro';

  @override
  String lentToPerson(String name) {
    return 'Prestato a $name';
  }

  @override
  String lentOn(String date) {
    return 'Prestato il $date';
  }

  @override
  String expectedReturnOn(String date) {
    return 'Rientro previsto il $date';
  }

  @override
  String get returnReminderSet => 'Ti ricorderò il rientro';

  @override
  String get markReturned => 'Segna come restituito';

  @override
  String get returnTitle => 'Segna come restituito';

  @override
  String get returnActualDate => 'Data di rientro';

  @override
  String get returnPlaceLabel => 'Rimettilo in';

  @override
  String returnedOn(String date) {
    return 'Restituito il $date';
  }

  @override
  String returnReminderTitle(String object) {
    return 'Rientro: $object';
  }

  @override
  String get loanStarted => 'Prestato. È annotato.';

  @override
  String get loanUpdated => 'Prestito aggiornato.';

  @override
  String get loanReturned => 'Restituito. Bentornato.';

  @override
  String get loanDatesInvalid =>
      'La data del prestito non può essere dopo il rientro.';

  @override
  String get cannotAssignPlaceWhileLent =>
      'Puoi assegnare un luogo quando torna.';

  @override
  String get resolveLoanBeforeArchive =>
      'Segna come restituito prima di archiviare o rimuovere.';

  @override
  String get moreOptions => 'Altre opzioni';

  @override
  String get personEmptyHint => 'Aggiungi la prima persona qui sopra.';

  @override
  String get archiveTitle => 'Archivio';

  @override
  String get archiveMenu => 'Archivio';

  @override
  String get archiveKeptTab => 'Conservati';

  @override
  String get archiveRemovedTab => 'Rimossi';

  @override
  String get archiveOpen => 'Apri';

  @override
  String get archiveRestore => 'Ripristina';

  @override
  String get archiveRestoredSnack => 'Ripristinato.';

  @override
  String get removedRestoredSnack => 'Ripristinato.';

  @override
  String get archivedStatusLabel => 'Messo da parte';

  @override
  String get transferredStatusLabel => 'Dato';

  @override
  String get lostStatusLabel => 'Smarrito';

  @override
  String get disposedStatusLabel => 'Dismesso';

  @override
  String get removedStatusLabel => 'Rimosso';

  @override
  String get archiveKeptEmpty => 'Non hai messo da parte nessun oggetto.';

  @override
  String get archiveKeptEmptyHint =>
      'Le cose messe da parte restano al sicuro qui e puoi ripristinarle quando vuoi.';

  @override
  String get archiveRemovedEmpty => 'Non ci sono oggetti rimossi.';

  @override
  String get archiveRemovedEmptyHint =>
      'Quello che rimuovi resta qui, pronto da ripristinare.';

  @override
  String get archiveSearchHint => 'Cerca nell\'archivio';

  @override
  String get archiveSearchNoResults => 'Nessun risultato';

  @override
  String archiveUpdatedOn(String date) {
    return 'Aggiornato il $date';
  }

  @override
  String get inactiveReadOnlyHint => 'Ripristina per modificarlo di nuovo.';

  @override
  String get removedBannerTitle => 'Rimosso';

  @override
  String get placesTitle => 'Luoghi';

  @override
  String get placesMenu => 'Luoghi';

  @override
  String get placeAddRoot => 'Nuovo luogo';

  @override
  String get placeAddChild => 'Aggiungi sottoluogo';

  @override
  String get placeChildrenSection => 'Sottoluoghi';

  @override
  String get placeDirectItemsSection => 'Qui direttamente';

  @override
  String get placeMove => 'Sposta luogo';

  @override
  String get placeMoveToRoot => 'Nessun luogo superiore';

  @override
  String get placeParent => 'Luogo superiore';

  @override
  String placeTotalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oggetti in tutto',
      one: '1 oggetto in tutto',
      zero: 'Niente',
    );
    return '$_temp0';
  }

  @override
  String placeDirectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count qui',
      one: '1 qui',
      zero: 'niente qui',
    );
    return '$_temp0';
  }

  @override
  String placeSubtreeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oggetti',
      one: '1 oggetto',
      zero: 'vuoto',
    );
    return '$_temp0';
  }

  @override
  String get placesEmpty => 'Non hai ancora nessun luogo.';

  @override
  String get placesEmptyHint =>
      'Crea un luogo per iniziare a organizzare le tue cose.';

  @override
  String get placeEmptyTree => 'Qui non c\'è ancora niente.';

  @override
  String get placeNoDirectItems => 'Nessun oggetto direttamente qui.';

  @override
  String get placeNoChildren => 'Nessun sottoluogo.';

  @override
  String get placeDeleteHasChildren => 'Prima sposta o rimuovi i sottoluoghi.';

  @override
  String get placeMoveInvalid => 'Non puoi spostarlo lì.';

  @override
  String get placeMovedToSnack => 'Luogo spostato.';

  @override
  String placeCreateUnder(String parent) {
    return 'Nuovo sottoluogo di «$parent»';
  }

  @override
  String get placeRootLevel => 'Luogo principale';

  @override
  String get newRootPlaceHint => 'Nuovo luogo principale';

  @override
  String get placeNewChildTitle => 'Nuovo sottoluogo';

  @override
  String get placeParentGone => 'Quel luogo non c\'è più.';

  @override
  String get entrustToSomeone => 'Affida a qualcuno';

  @override
  String get giveToSomeone => 'Dai a qualcuno';

  @override
  String get giveEditTitle => 'Dai a qualcuno';

  @override
  String get giveRecipientLabel => 'A chi lo dai?';

  @override
  String get giveRecipientChoose => 'Scegli una persona';

  @override
  String get giveDateLabel => 'Quando';

  @override
  String get giveNoteLabel => 'Nota (facoltativa)';

  @override
  String get markAsGiven => 'Segna come dato';

  @override
  String get giveEffectHint =>
      'Uscirà dalla Home e dal suo luogo, ma resterà al sicuro in Archivio.';

  @override
  String givenToPerson(String name) {
    return 'Dato a $name';
  }

  @override
  String givenOn(String date) {
    return 'Dato il $date';
  }

  @override
  String get givenSavedSnack => 'Dato. È annotato.';

  @override
  String get transferDateFutureError => 'La data non può essere nel futuro.';

  @override
  String get resolveLoanBeforeGive => 'Segna prima l\'oggetto come restituito.';

  @override
  String get reacquireAction => 'Torna tra i miei oggetti';

  @override
  String get reacquireTitle => 'Torna tra i miei oggetti';

  @override
  String get reacquireDateLabel => 'Quando è tornato';

  @override
  String get reacquiredTimeline => 'Tornato tra i tuoi oggetti';

  @override
  String get reacquiredSnack => 'Bentornato tra le tue cose.';

  @override
  String get reacquireBeforeTransferError =>
      'Non può essere prima di quando l\'hai dato.';

  @override
  String get backupMenu => 'Backup e ripristino';

  @override
  String get backupTitle => 'Backup e ripristino';

  @override
  String get backupIntro =>
      'I tuoi dati restano sul dispositivo. Puoi creare un file che contiene il database e le foto di Pole².';

  @override
  String get backupReassure =>
      'Il backup resta a te: nessun cloud, nessun account. Custodiscilo dove preferisci.';

  @override
  String get backupSectionTitle => 'Backup';

  @override
  String get backupCreate => 'Crea backup';

  @override
  String get backupEncryptToggle => 'Proteggi con password (consigliato)';

  @override
  String get backupPasswordLabel => 'Password';

  @override
  String get backupPasswordConfirmLabel => 'Conferma password';

  @override
  String get backupPasswordWarning =>
      'Questa password protegge il backup. Se la dimentichi, non sarà possibile recuperarlo.';

  @override
  String get backupPasswordTooShort => 'Usa almeno 10 caratteri.';

  @override
  String get backupPasswordMismatch => 'Le password non coincidono.';

  @override
  String get backupPlaintextToggle => 'Crea un backup senza password';

  @override
  String get backupPlaintextWarning =>
      'Questo backup non è protetto: chi ha il file può vederne il contenuto.';

  @override
  String get backupWorking => 'Sto preparando il backup…';

  @override
  String get backupSaving => 'Sto salvando…';

  @override
  String get backupSuccess =>
      'Backup creato. Ora è al sicuro dove hai scelto di conservarlo.';

  @override
  String get backupFailure =>
      'Non siamo riusciti a creare il backup. I tuoi dati sono rimasti al loro posto.';

  @override
  String backupIncomplete(String object) {
    return 'Manca la foto di «$object». Aggiungila o rimuovila, poi riprova.';
  }

  @override
  String get backupLowSpace => 'Spazio insufficiente per creare il backup.';

  @override
  String get backupDormantMissingWarning =>
      'Alcune foto non più presenti non sono state incluse.';

  @override
  String backupLastDate(String date) {
    return 'Ultimo backup: $date';
  }

  @override
  String get backupNever => 'Nessun backup ancora.';

  @override
  String get restoreSectionTitle => 'Ripristino';

  @override
  String get restoreAction => 'Ripristina da backup';

  @override
  String get restoreComingSoon => 'Disponibile nel prossimo aggiornamento.';

  @override
  String get restoreIntro =>
      'Scegli un file di backup di Pole² per riportare qui i tuoi dati.';

  @override
  String get restoreReplaceWarning =>
      'Il ripristino sostituisce i dati attuali di Pole² con quelli del backup. Le cose che hai adesso su questo dispositivo verranno rimpiazzate.';

  @override
  String get restoreConfirm => 'Ho capito, ripristina';

  @override
  String get restorePasswordTitle => 'Password del backup';

  @override
  String get restorePasswordPrompt =>
      'Questo backup è protetto. Inserisci la password.';

  @override
  String get restoreSummaryTitle => 'Contenuto del backup';

  @override
  String restoreSummaryCounts(int objects, int photos, int places, int people) {
    return '$objects oggetti · $photos foto · $places luoghi · $people persone';
  }

  @override
  String restoreSummaryCreated(String date) {
    return 'Creato il $date';
  }

  @override
  String get restoreMigratedNote =>
      'Backup di una versione precedente: verrà aggiornato durante il ripristino.';

  @override
  String get restorePreparing => 'Sto verificando il backup…';

  @override
  String get restoreCloseTitle => 'Quasi fatto';

  @override
  String get restoreCloseBody =>
      'Pole² verrà chiusa per completare il ripristino. Riaprila per continuare.';

  @override
  String get restoreCloseButton => 'Chiudi Pole²';

  @override
  String get restoreClosing => 'Chiusura…';

  @override
  String get restoreCloseManual =>
      'Chiudi Pole² dalle applicazioni recenti e riaprila per completare il ripristino.';

  @override
  String get restoreErrPrepareFailed =>
      'Non siamo riusciti a preparare il ripristino. I tuoi dati sono rimasti al loro posto.';

  @override
  String get restoreDoneMessage =>
      'Backup ripristinato. Le tue cose sono di nuovo al loro posto.';

  @override
  String get restoreFailedMessage =>
      'Ripristino non riuscito. I tuoi dati sono rimasti al loro posto.';

  @override
  String get restoreErrNewer => 'Aggiorna Pole² per aprire questo backup.';

  @override
  String get restoreErrPassword => 'Password errata oppure backup danneggiato.';

  @override
  String get restoreErrIncompleteMedia =>
      'Nel backup mancano delle foto necessarie.';

  @override
  String get restoreErrLowSpace => 'Spazio insufficiente per il ripristino.';

  @override
  String get restoreErrAccess =>
      'Pole² non ha ricevuto l\'accesso al file scelto. Prova a selezionarlo di nuovo.';

  @override
  String get restoreErrUnreadable =>
      'Non è stato possibile leggere il file scelto. Riprova.';

  @override
  String get restoreErrEmpty => 'Il file scelto è vuoto.';

  @override
  String get restoreErrNotBackup => 'Questo file non è un backup di Pole².';

  @override
  String get restoreErrGeneric => 'Non è stato possibile leggere il backup.';

  @override
  String get peopleMenu => 'Persone';

  @override
  String get peopleTitle => 'Persone';

  @override
  String get peopleSearchHint => 'Cerca una persona';

  @override
  String get peopleEmpty =>
      'Le persone a cui presti o dai qualcosa compaiono qui.';

  @override
  String get peopleAddTooltip => 'Aggiungi persona';

  @override
  String get peopleAddTitle => 'Aggiungi persona';

  @override
  String peopleCountLent(int count) {
    return '$count in prestito';
  }

  @override
  String peopleCountGiven(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dati',
      one: '1 dato',
    );
    return '$_temp0';
  }

  @override
  String get personSectionLent => 'In prestito';

  @override
  String get personSectionGiven => 'Dati';

  @override
  String get personSectionHistory => 'Storico';

  @override
  String personGivenOn(String date) {
    return 'Dato il $date';
  }

  @override
  String personHistReturned(String date) {
    return 'Restituito il $date';
  }

  @override
  String personHistGiven(String date) {
    return 'Dato il $date';
  }

  @override
  String personHistReacquired(String date) {
    return 'Ripreso il $date';
  }

  @override
  String get personEmpty => 'Ancora nessun collegamento con le tue cose.';

  @override
  String get personRename => 'Rinomina';

  @override
  String get personRenameTitle => 'Rinomina persona';

  @override
  String get personRenameDuplicate => 'Esiste già una persona con questo nome.';

  @override
  String get personDelete => 'Rimuovi';

  @override
  String personDeleteTitle(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String get personDeleteBody =>
      'La cronologia resta leggibile. Puoi rimuovere una persona solo quando non ha nulla in prestito o che le hai dato.';

  @override
  String personDeleteBlocked(String name) {
    return 'Non puoi rimuovere $name finché ha qualcosa in prestito o che le hai dato.';
  }

  @override
  String get personDeletedSnack => 'Persona rimossa.';

  @override
  String get infoMenu => 'Informazioni e supporto';

  @override
  String get infoTitle => 'Informazioni e supporto';

  @override
  String get infoSlogan =>
      'Custodisci ciò che conta, conta ciò che custodisci.';

  @override
  String infoVersion(String version, String build) {
    return 'Versione $version · build $build';
  }

  @override
  String get infoVersionUnknown => 'Versione non disponibile';

  @override
  String get infoLocalFirst =>
      'I dati di Pole² restano sul tuo dispositivo, salvo i backup che scegli di esportare.';

  @override
  String get infoLinksTitle => 'Sul sito';

  @override
  String get infoLinkSite => 'Sito di Pole²';

  @override
  String get infoLinkSiteSub => 'La casa pubblica di Pole²';

  @override
  String get infoLinkGuide => 'Guida';

  @override
  String get infoLinkGuideSub => 'Come si usa, con calma';

  @override
  String get infoLinkNews => 'Novità';

  @override
  String get infoLinkNewsSub => 'Cosa è cambiato';

  @override
  String get infoLinkSupport => 'Supporto';

  @override
  String get infoLinkSupportSub => 'Scrivici se qualcosa non torna';

  @override
  String get infoLinkPrivacy => 'Privacy';

  @override
  String get infoLinkPrivacySub => 'Cosa resta sul dispositivo';

  @override
  String infoLinkSemantics(String label) {
    return '$label. Si apre nel browser.';
  }

  @override
  String get infoLinkFootnote =>
      'I link si aprono nel tuo browser. Il supporto riceve solo la versione installata.';

  @override
  String get infoOpenFailed =>
      'Non è stato possibile aprire il link. Puoi visitare pole2.app dal tuo browser.';

  @override
  String get infoOpenNoBrowser =>
      'Non c\'è un browser su questo dispositivo. Puoi visitare pole2.app da un altro dispositivo.';

  @override
  String get infoLegalTitle => 'Sull\'app';

  @override
  String get infoLicenses => 'Licenze open source';

  @override
  String get infoLicensesSub => 'Le librerie che rendono possibile Pole²';

  @override
  String infoLicensesSemantics(String label) {
    return '$label. Rimane nell\'app.';
  }

  @override
  String get infoLicensesLegalese =>
      'Pole² conserva i tuoi dati sul dispositivo. Le librerie open source elencate qui mantengono ciascuna la propria licenza.';
}
