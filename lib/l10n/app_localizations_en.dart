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
  String get actionObject => 'Un oggetto';

  @override
  String get actionPhoto => 'Una foto';

  @override
  String get actionDocument => 'Un documento';

  @override
  String get actionReminder => 'Un promemoria';

  @override
  String get actionNote => 'Una nota';

  @override
  String get actionDetail => 'Un dettaglio';

  @override
  String get quickActionSoon =>
      'Presto. Per ora, inizia conservando un oggetto.';

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
  String get closeButton => 'Chiudi';

  @override
  String get placeContentsEmpty => 'Ancora niente qui';

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
  String get filterTooltip => 'Filtra per luogo';

  @override
  String get filterAllPlaces => 'Tutti i luoghi';

  @override
  String get filterNoPlace => 'Senza luogo';

  @override
  String get photoEditTooltip => 'Cambia foto';

  @override
  String get photoView => 'Vedi la foto';
}
