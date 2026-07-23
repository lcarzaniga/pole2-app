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
      'Everything you care about can live here — safe, and only on this device.';

  @override
  String get homeEmptyCta => 'Tap to begin';

  @override
  String get privacyLine => 'Everything stays on this device';

  @override
  String get a11yKeepSomething => 'Keep something';

  @override
  String get a11yClose => 'Close';

  @override
  String get actionPhoto => 'From a photo';

  @override
  String get actionObject => 'From a name';

  @override
  String get a11yActionPhoto => 'Create an item starting from a photo';

  @override
  String get a11yActionObject => 'Create an item starting from a name';

  @override
  String get photoSourceTitle => 'Add a photo';

  @override
  String get photoTakePhoto => 'Take a photo';

  @override
  String get photoChooseGallery => 'Choose from gallery';

  @override
  String get cameraDeniedSnack =>
      'Pole² can’t use the camera yet. You can allow it in Settings.';

  @override
  String get captureFailedSnack =>
      'Nothing was lost. Try again whenever you like.';

  @override
  String get createTitle => 'Keep something';

  @override
  String get whatIsItLabel => 'What is it?';

  @override
  String get createHint => 'e.g. Dishwasher, grandpa’s watch, the car';

  @override
  String get createReassure =>
      'You can add photos, receipts and details whenever you like. For now, nothing else is needed.';

  @override
  String get keepItButton => 'Keep';

  @override
  String upcomingDatesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dates coming up',
      one: '1 date coming up',
    );
    return '$_temp0';
  }

  @override
  String get addPhoto => 'Add a photo';

  @override
  String get renameTooltip => 'Rename';

  @override
  String get nameLabel => 'Name';

  @override
  String get saveButton => 'Save';

  @override
  String keptOn(String date) {
    return 'Kept on $date';
  }

  @override
  String nextUp(String what) {
    return 'Next: $what';
  }

  @override
  String get detailsTitle => 'Details';

  @override
  String get detailsEmptySubtitle =>
      'Where it came from, what it cost, when you got it.';

  @override
  String get tapToAddMore => 'Tap to add more';

  @override
  String get recordEditorTitleNew => 'New record';

  @override
  String get recordEditorTitleEdit => 'Edit';

  @override
  String get recordDescriptionLabel => 'Description';

  @override
  String get recordDescriptionHint => 'Write a note…';

  @override
  String get recordCategoryLabel => 'Category';

  @override
  String get recordReferenceDateLabel => 'Date';

  @override
  String get recordValidityLabel => 'Validity';

  @override
  String get recordValidityAdd => 'Add an expiry date';

  @override
  String get recordValidityEndPrefix => 'Expires on';

  @override
  String get recordRemindMe => 'Remind me';

  @override
  String get recordAttachmentsLabel => 'Attachments';

  @override
  String get attachmentAdd => 'Add attachment';

  @override
  String get attachSheetTitle => 'Add an attachment';

  @override
  String get attachChoosePhoto => 'Choose a photo';

  @override
  String get attachChooseDocument => 'Choose a document';

  @override
  String get attachmentPhotoDefaultLabel => 'Photo';

  @override
  String get recordSwitchToNoteTitle => 'Switch to Note?';

  @override
  String get recordSwitchToNoteBody =>
      'A simple note doesn’t keep a date, expiry, reminder or attachments. Do you want to remove them?';

  @override
  String get recordSwitchToNoteConfirm => 'Remove and continue';

  @override
  String recordValidUntil(Object date) {
    return 'Valid until $date';
  }

  @override
  String get catNote => 'Note';

  @override
  String get catPurchase => 'Purchase / receipt';

  @override
  String get catWarranty => 'Warranty';

  @override
  String get catManual => 'Manual / documentation';

  @override
  String get catMaintenance => 'Maintenance';

  @override
  String get catInsurance => 'Insurance / certificate';

  @override
  String get catOther => 'Other';

  @override
  String get historyTitle => 'History';

  @override
  String get addDate => 'Add a date';

  @override
  String get historyEmpty =>
      'Nothing yet — add how you got it, or a date to remember.';

  @override
  String onDate(String date) {
    return 'on $date';
  }

  @override
  String get menuRename => 'Rename';

  @override
  String get menuPutAway => 'Put away';

  @override
  String get menuRemove => 'Remove';

  @override
  String get archivedSnack => 'Put away. It’s safe.';

  @override
  String get removedSnack => 'Removed. Nothing is lost yet.';

  @override
  String get eventRemovedSnack => 'Removed.';

  @override
  String get undo => 'Undo';

  @override
  String get errorNothingLost => 'Something went wrong — but nothing was lost.';

  @override
  String get goneMessage => 'It’s no longer here.';

  @override
  String boughtAt(String supplier) {
    return 'Bought from $supplier';
  }

  @override
  String get bought => 'Bought';

  @override
  String get receivedAsGift => 'Received as a gift';

  @override
  String get inheritedHeadline => 'Inherited';

  @override
  String get alreadyHadHeadline => 'Already had it';

  @override
  String get keptHeadline => 'Kept';

  @override
  String fromSupplier(String supplier) {
    return 'From $supplier';
  }

  @override
  String get purchaseDetailsHeadline => 'Purchase details';

  @override
  String get acquisitionTitle => 'Purchase details';

  @override
  String get howDidYouGetIt => 'How did you get it?';

  @override
  String get acqTypeBought => 'Bought';

  @override
  String get acqTypeGift => 'Gift';

  @override
  String get acqTypeInherited => 'Inherited';

  @override
  String get acqTypeAlreadyHad => 'Already mine';

  @override
  String get acqTypeOther => 'Other';

  @override
  String get whenLabel => 'When';

  @override
  String get notSet => 'Not set';

  @override
  String get whereFromLabel => 'Where from';

  @override
  String get whereFromHint => 'Shop or person';

  @override
  String get priceLabel => 'Price';

  @override
  String get noteLabel => 'Note';

  @override
  String get acquisitionReassure =>
      'Add as much as you like — you can always come back to it.';

  @override
  String get reminderTitle => 'Add a date';

  @override
  String get reminderHint => 'e.g. Warranty expiry';

  @override
  String get suggWarranty => 'Warranty expiry';

  @override
  String get suggReturn => 'Return due';

  @override
  String get suggService => 'Maintenance';

  @override
  String get suggInsurance => 'Insurance renewal';

  @override
  String get suggFilter => 'Filter change';

  @override
  String get chooseDate => 'Choose a date';

  @override
  String get remindMe => 'Remind me';

  @override
  String get leadSameDay => 'On the day';

  @override
  String get leadDayBefore => '1 day before';

  @override
  String get leadWeekBefore => '1 week before';

  @override
  String get leadMonthBefore => '1 month before';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get noPlace => 'No place';

  @override
  String get placeLabel => 'Place';

  @override
  String get placeAssignHint => 'Tap to assign a place';

  @override
  String get placePickerTitle => 'Where is it?';

  @override
  String get addPlaceButton => 'Add';

  @override
  String get placeManageTooltip => 'Manage';

  @override
  String get placeDelete => 'Delete';

  @override
  String get placeRenameTitle => 'Rename place';

  @override
  String get cancelButton => 'Cancel';

  @override
  String placeDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String placeDeleteAssigned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It’s assigned to $count items, which will return to “No place”.',
      one: 'It’s assigned to 1 item, which will return to “No place”.',
    );
    return '$_temp0';
  }

  @override
  String get placeDeleteNone => 'No item uses this place.';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableBody(String version) {
    return 'Version $version is available.';
  }

  @override
  String get updateNow => 'Update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateVerifying => 'Verifying…';

  @override
  String get updateInstalling => 'Starting installation…';

  @override
  String get updatePermissionNeeded =>
      'To install the update, allow installing apps from this source.';

  @override
  String get updateAllow => 'Allow';

  @override
  String get updateRetry => 'Try again';

  @override
  String get updateErrorDownload => 'Download failed.';

  @override
  String get updateErrorSha => 'Invalid update file.';

  @override
  String get updateErrorInstall => 'Installation failed.';

  @override
  String get updateRestoreBusy =>
      'A restore is in progress. Reopen Pole² and finish the restore before updating.';

  @override
  String get updateBackupTitle =>
      'Before updating, would you like to create a backup?';

  @override
  String get updateBackupBody =>
      'It’s recommended for this update. The backup stays with you, and you can save it wherever you prefer.';

  @override
  String get updateBackupCreate => 'Create backup';

  @override
  String get updateBackupContinueWithout => 'Continue without a backup';

  @override
  String get updateBackupScreenIntro =>
      'Create a backup before installing the update. When it’s done, the update resumes on its own.';

  @override
  String get updateWithoutTitle => 'Continue without creating a backup?';

  @override
  String get updateWithoutBody =>
      'Updates usually keep your data, but a backup is recommended for this version.';

  @override
  String get updateWithoutContinue => 'Continue';

  @override
  String get updateWithoutBack => 'Back';

  @override
  String get closeButton => 'Close';

  @override
  String get placeEmptyHint =>
      'You can assign an item to this place from the item’s page.';

  @override
  String get placeMoveAction => 'Move to another place';

  @override
  String get placeRemoveAction => 'Remove from place';

  @override
  String get placeMovedSnack => 'Item moved.';

  @override
  String get placeRemovedFromSnack => 'Removed from the place.';

  @override
  String get itemActionsTooltip => 'Options';

  @override
  String get placeEditTooltip => 'Change place';

  @override
  String get documentAddFailed =>
      'Nothing was lost. Try again whenever you like.';

  @override
  String get documentOpenFailed =>
      'Couldn’t open the attachment. Try again whenever you like.';

  @override
  String get documentOpenNoApp =>
      'No app is available to open this type of file.';

  @override
  String get documentMissing => 'This attachment is no longer available.';

  @override
  String get documentRemoveTooltip => 'Remove attachment';

  @override
  String get hubPhoto => 'Photo';

  @override
  String get hubNote => 'Note';

  @override
  String get hubDate => 'Date';

  @override
  String get hubPlace => 'Place';

  @override
  String get searchHint => 'Search';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchNoResults => 'No results';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortName => 'Name';

  @override
  String get filterTooltip => 'Where it is';

  @override
  String get filterNoPlace => 'No place';

  @override
  String get custodyAll => 'All';

  @override
  String custodyInPlace(String path) {
    return 'In: $path';
  }

  @override
  String custodyWithPerson(String name) {
    return 'With: $name';
  }

  @override
  String get photoEditTooltip => 'Change photo';

  @override
  String get photoView => 'View the photo';

  @override
  String get placeReviewStart => 'Tidy up this place';

  @override
  String get placeReviewKeep => 'Keep here';

  @override
  String get placeReviewMove => 'Move';

  @override
  String get placeReviewUnassign => 'Remove from place';

  @override
  String get placeReviewArchive => 'Put aside';

  @override
  String get placeReviewDone => 'Done';

  @override
  String get placeReviewAllSeen => 'You’ve looked at everything that’s here.';

  @override
  String placeReviewGentleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things here',
      one: '1 thing here',
      zero: 'Nothing here',
    );
    return '$_temp0';
  }

  @override
  String get photoAddAnother => 'Add another photo';

  @override
  String get photoSetCover => 'Set as cover';

  @override
  String get photoIsCover => 'Cover';

  @override
  String get photoRemove => 'Remove photo';

  @override
  String get photoRemovedSnack => 'Photo removed.';

  @override
  String photoPosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get lendToSomeone => 'Lend to someone';

  @override
  String get lendEditTitle => 'Edit loan';

  @override
  String get borrowerLabel => 'Who are you lending it to?';

  @override
  String get borrowerChoose => 'Choose a person';

  @override
  String get selectPerson => 'Choose a person';

  @override
  String get createPerson => 'New person';

  @override
  String get personNameHint => 'Name';

  @override
  String get addPersonButton => 'Add';

  @override
  String get lentDateLabel => 'Loan date';

  @override
  String get expectedReturnOptional => 'Expected return (optional)';

  @override
  String get noReturnDate => 'No return date';

  @override
  String get returnDateClear => 'Remove the date';

  @override
  String get returnReminder => 'Remind me about the return';

  @override
  String lentToPerson(String name) {
    return 'Lent to $name';
  }

  @override
  String lentOn(String date) {
    return 'Lent on $date';
  }

  @override
  String expectedReturnOn(String date) {
    return 'Expected back on $date';
  }

  @override
  String get returnReminderSet => 'We’ll remind you about the return';

  @override
  String get markReturned => 'Mark as returned';

  @override
  String get returnTitle => 'Mark as returned';

  @override
  String get returnActualDate => 'Return date';

  @override
  String get returnPlaceLabel => 'Put it back in';

  @override
  String returnedOn(String date) {
    return 'Returned on $date';
  }

  @override
  String get loanStarted => 'Lent. It’s noted.';

  @override
  String get loanUpdated => 'Loan updated.';

  @override
  String get loanReturned => 'Returned. Welcome back.';

  @override
  String get loanDatesInvalid => 'The loan date can’t be after the return.';

  @override
  String get cannotAssignPlaceWhileLent =>
      'You can assign a place when it comes back.';

  @override
  String get resolveLoanBeforeArchive =>
      'Mark it as returned before archiving or removing it.';

  @override
  String get moreOptions => 'More options';

  @override
  String get personEmptyHint => 'Add the first person above.';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveMenu => 'Archive';

  @override
  String get archiveKeptTab => 'Kept aside';

  @override
  String get archiveRemovedTab => 'Removed';

  @override
  String get archiveRestore => 'Restore';

  @override
  String get archiveRestoredSnack => 'Restored.';

  @override
  String get removedRestoredSnack => 'Restored.';

  @override
  String get archivedStatusLabel => 'Kept aside';

  @override
  String get transferredStatusLabel => 'Given';

  @override
  String get lostStatusLabel => 'Lost';

  @override
  String get disposedStatusLabel => 'Disposed of';

  @override
  String get removedStatusLabel => 'Removed';

  @override
  String get archiveKeptEmpty => 'You haven’t put any item aside.';

  @override
  String get archiveKeptEmptyHint =>
      'Things you put aside stay safe here, and you can restore them whenever you like.';

  @override
  String get archiveRemovedEmpty => 'There are no removed items.';

  @override
  String get archiveRemovedEmptyHint =>
      'Anything you remove stays here, ready to restore.';

  @override
  String get archiveSearchHint => 'Search the archive';

  @override
  String get archiveSearchNoResults => 'No results';

  @override
  String archiveUpdatedOn(String date) {
    return 'Updated on $date';
  }

  @override
  String get inactiveReadOnlyHint => 'Restore it to edit it again.';

  @override
  String get removedBannerTitle => 'Removed';

  @override
  String get placesTitle => 'Places';

  @override
  String get placesMenu => 'Places';

  @override
  String get placeAddRoot => 'New place';

  @override
  String get placeAddChild => 'Add a sub-place';

  @override
  String get placeChildrenSection => 'Sub-places';

  @override
  String get placeDirectItemsSection => 'Directly here';

  @override
  String get placeMove => 'Move place';

  @override
  String get placeMoveToRoot => 'No parent place';

  @override
  String placeTotalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items in all',
      one: '1 item in all',
      zero: 'Nothing',
    );
    return '$_temp0';
  }

  @override
  String placeSubtreeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'empty',
    );
    return '$_temp0';
  }

  @override
  String get placesEmpty => 'You don’t have any places yet.';

  @override
  String get placesEmptyHint =>
      'Create a place to start organising your things.';

  @override
  String get placeEmptyTree => 'There’s nothing here yet.';

  @override
  String get placeNoDirectItems => 'No item directly here.';

  @override
  String get placeDeleteHasChildren => 'Move or remove the sub-places first.';

  @override
  String get placeMoveInvalid => 'You can’t move it there.';

  @override
  String get placeMovedToSnack => 'Place moved.';

  @override
  String get newRootPlaceHint => 'New top-level place';

  @override
  String get placeNewChildTitle => 'New sub-place';

  @override
  String get placeParentGone => 'That place is no longer there.';

  @override
  String get entrustToSomeone => 'Entrust to someone';

  @override
  String get giveToSomeone => 'Give to someone';

  @override
  String get giveEditTitle => 'Give to someone';

  @override
  String get giveRecipientLabel => 'Who are you giving it to?';

  @override
  String get giveRecipientChoose => 'Choose a person';

  @override
  String get giveDateLabel => 'When';

  @override
  String get giveNoteLabel => 'Note (optional)';

  @override
  String get giveEffectHint =>
      'It will leave the Home and its place, but stay safe in the Archive.';

  @override
  String givenToPerson(String name) {
    return 'Given to $name';
  }

  @override
  String givenOn(String date) {
    return 'Given on $date';
  }

  @override
  String get givenSavedSnack => 'Given. It’s noted.';

  @override
  String get transferDateFutureError => 'The date can’t be in the future.';

  @override
  String get reacquireAction => 'Bring back to my things';

  @override
  String get reacquireTitle => 'Bring back to my things';

  @override
  String get reacquireDateLabel => 'When it came back';

  @override
  String get reacquiredTimeline => 'Back among your things';

  @override
  String get reacquiredSnack => 'Welcome back among your things.';

  @override
  String get reacquireBeforeTransferError =>
      'It can’t be before you gave it away.';

  @override
  String get backupTitle => 'Backup and restore';

  @override
  String get backupIntro =>
      'Your data stays on the device. You can create a file that contains Pole²’s database and photos.';

  @override
  String get backupReassure =>
      'The backup stays with you: no cloud, no account. Keep it wherever you prefer.';

  @override
  String get backupSectionTitle => 'Backup';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupEncryptToggle => 'Protect with a password (recommended)';

  @override
  String get backupPasswordLabel => 'Password';

  @override
  String get backupPasswordConfirmLabel => 'Confirm password';

  @override
  String get backupPasswordWarning =>
      'This password protects the backup. If you forget it, the backup can’t be recovered.';

  @override
  String get backupPasswordTooShort => 'Use at least 10 characters.';

  @override
  String get backupPasswordMismatch => 'The passwords don’t match.';

  @override
  String get backupPlaintextWarning =>
      'This backup isn’t protected: anyone with the file can see its contents.';

  @override
  String get backupWorking => 'Preparing the backup…';

  @override
  String get backupSaving => 'Saving…';

  @override
  String get backupSuccess =>
      'Backup created. It’s now safe wherever you chose to keep it.';

  @override
  String get backupFailure =>
      'We couldn’t create the backup. Your data stayed where it was.';

  @override
  String backupIncomplete(String object) {
    return 'The photo of “$object” is missing. Add it or remove it, then try again.';
  }

  @override
  String get backupLowSpace => 'Not enough space to create the backup.';

  @override
  String get backupDormantMissingWarning =>
      'Some photos that are no longer present weren’t included.';

  @override
  String backupLastDate(String date) {
    return 'Last backup: $date';
  }

  @override
  String get restoreSectionTitle => 'Restore';

  @override
  String get restoreAction => 'Restore from a backup';

  @override
  String get restoreComingSoon => 'Available in the next update.';

  @override
  String get restoreIntro =>
      'Choose a Pole² backup file to bring your data back here.';

  @override
  String get restoreReplaceWarning =>
      'Restoring replaces Pole²’s current data with the data from the backup. The data currently on this device will be replaced.';

  @override
  String get restoreConfirm => 'I understand, restore';

  @override
  String get restorePasswordTitle => 'Backup password';

  @override
  String get restorePasswordPrompt =>
      'This backup is protected. Enter the password.';

  @override
  String get restoreSummaryTitle => 'Backup contents';

  @override
  String restoreSummaryCounts(int objects, int photos, int places, int people) {
    return '$objects items · $photos photos · $places places · $people people';
  }

  @override
  String restoreSummaryCreated(String date) {
    return 'Created on $date';
  }

  @override
  String get restoreMigratedNote =>
      'Backup from an earlier version: it will be updated during the restore.';

  @override
  String get restorePreparing => 'Checking the backup…';

  @override
  String get restoreCloseTitle => 'Almost done';

  @override
  String get restoreCloseBody =>
      'Pole² will close to finish the restore. Reopen it to continue.';

  @override
  String get restoreCloseButton => 'Close Pole²';

  @override
  String get restoreClosing => 'Closing…';

  @override
  String get restoreCloseManual =>
      'Close Pole² from recent apps and reopen it to finish the restore.';

  @override
  String get restoreErrPrepareFailed =>
      'We couldn’t prepare the restore. Your data stayed where it was.';

  @override
  String get restoreDoneMessage =>
      'Backup restored. Your things are back where they belong.';

  @override
  String get restoreFailedMessage =>
      'Restore failed. Your data stayed where it was.';

  @override
  String get restoreErrNewer => 'Update Pole² to open this backup.';

  @override
  String get restoreErrPassword => 'Wrong password, or the backup is damaged.';

  @override
  String get restoreErrIncompleteMedia =>
      'The backup is missing some required photos.';

  @override
  String get restoreErrLowSpace => 'Not enough space for the restore.';

  @override
  String get restoreErrAccess =>
      'Pole² wasn’t given access to the chosen file. Try selecting it again.';

  @override
  String get restoreErrUnreadable =>
      'The chosen file couldn’t be read. Try again.';

  @override
  String get restoreErrEmpty => 'The chosen file is empty.';

  @override
  String get restoreErrNotBackup => 'This file isn’t a Pole² backup.';

  @override
  String get restoreErrGeneric => 'The backup couldn’t be read.';

  @override
  String get peopleMenu => 'People';

  @override
  String get peopleTitle => 'People';

  @override
  String get peopleSearchHint => 'Search for a person';

  @override
  String get peopleEmpty =>
      'The people you lend or give things to appear here.';

  @override
  String get peopleAddTooltip => 'Add person';

  @override
  String get peopleAddTitle => 'Add person';

  @override
  String peopleCountLent(int count) {
    return '$count on loan';
  }

  @override
  String peopleCountGiven(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count given',
      one: '1 given',
    );
    return '$_temp0';
  }

  @override
  String get personSectionLent => 'On loan';

  @override
  String get personSectionGiven => 'Given';

  @override
  String get personSectionHistory => 'History';

  @override
  String personGivenOn(String date) {
    return 'Given on $date';
  }

  @override
  String personHistReturned(String date) {
    return 'Returned on $date';
  }

  @override
  String personHistGiven(String date) {
    return 'Given on $date';
  }

  @override
  String personHistReacquired(String date) {
    return 'Taken back on $date';
  }

  @override
  String get personEmpty => 'No connection with your things yet.';

  @override
  String get personRename => 'Rename';

  @override
  String get personRenameTitle => 'Rename person';

  @override
  String get personRenameDuplicate => 'A person with this name already exists.';

  @override
  String get personDelete => 'Remove';

  @override
  String personDeleteTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get personDeleteBody =>
      'Their history stays readable. You can remove a person only when they have nothing on loan or that you’ve given them.';

  @override
  String personDeleteBlocked(String name) {
    return 'You can’t remove $name while they have something on loan or that you’ve given them.';
  }

  @override
  String get personDeletedSnack => 'Person removed.';

  @override
  String get settingsMenu => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get languageAuto => 'Automatic';

  @override
  String get languageAutoSubtitle => 'Follows your device language';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsDataSection => 'Data and space';

  @override
  String get settingsDataRow => 'Backup, restore and space';

  @override
  String get settingsDataRowSub => 'Create a backup, restore, free up space';

  @override
  String get settingsUpdatesSection => 'Updates';

  @override
  String get settingsInstalledVersion => 'Installed version';

  @override
  String get settingsUpdateCheck => 'Check for updates';

  @override
  String get settingsUpdateCheckSub => 'Look for a newer version';

  @override
  String get settingsUpdateChecking => 'Checking…';

  @override
  String get settingsUpdateUpToDate => 'Pole² is up to date.';

  @override
  String get settingsUpdateCheckFailed =>
      'Couldn’t check right now. Try again whenever you like.';

  @override
  String get settingsUpdateManagedByStore =>
      'Updates come from the Play Store.';

  @override
  String get settingsInfoSection => 'Information and support';

  @override
  String get settingsInfoRow => 'Information and support';

  @override
  String get settingsInfoRowSub => 'Support, privacy, website and licenses';

  @override
  String get infoTitle => 'Information and support';

  @override
  String get infoSlogan => 'Keep what counts, and count what you keep.';

  @override
  String infoVersion(String version, String build) {
    return 'Version $version · build $build';
  }

  @override
  String get infoVersionUnknown => 'Version unavailable';

  @override
  String get infoLocalFirst =>
      'Pole²’s data stays on your device, except for the backups you choose to export.';

  @override
  String get infoLinksTitle => 'On the web';

  @override
  String get infoLinkSite => 'Pole² website';

  @override
  String get infoLinkSiteSub => 'Pole²’s public home';

  @override
  String get infoLinkGuide => 'Guide';

  @override
  String get infoLinkGuideSub => 'How to use it, calmly';

  @override
  String get infoLinkNews => 'What’s new';

  @override
  String get infoLinkNewsSub => 'What has changed';

  @override
  String get infoLinkSupport => 'Support';

  @override
  String get infoLinkSupportSub => 'Write to us if something’s not right';

  @override
  String get infoLinkPrivacy => 'Privacy';

  @override
  String get infoLinkPrivacySub => 'What stays on the device';

  @override
  String infoLinkSemantics(String label) {
    return '$label. Opens in the browser.';
  }

  @override
  String get infoLinkFootnote =>
      'Links open in your browser. Support only receives the installed version.';

  @override
  String get infoOpenFailed =>
      'Couldn’t open the link. You can visit pole2.app from your browser.';

  @override
  String get infoOpenNoBrowser =>
      'There’s no browser on this device. You can visit pole2.app from another device.';

  @override
  String get infoLegalTitle => 'About the app';

  @override
  String get infoLicenses => 'Open-source licenses';

  @override
  String get infoLicensesSub => 'The libraries that make Pole² possible';

  @override
  String infoLicensesSemantics(String label) {
    return '$label. Stays in the app.';
  }

  @override
  String get infoLicensesLegalese =>
      'Pole² keeps your data on your device. Each open-source library listed here is distributed under its own license.';

  @override
  String get permanentDeleteAction => 'Delete permanently';

  @override
  String permanentDeleteTitle(String title) {
    return 'Permanently delete “$title”?';
  }

  @override
  String get permanentDeleteBody =>
      'This can’t be undone. The item and its history will be deleted from this device. Photos and attachments used only by this item will be deleted too. Linked people and places remain. A backup created earlier can bring the item back.';

  @override
  String get permanentDeleteConfirm => 'Delete permanently';

  @override
  String get permanentDeleteCancel => 'Cancel';

  @override
  String permanentDeleteDoneSnack(String title) {
    return '“$title” deleted from this device.';
  }

  @override
  String permanentDeletePartialSnack(String title) {
    return '“$title” was deleted. Some files will be reclaimed later with “Free up space”.';
  }

  @override
  String permanentDeleteFailedSnack(String title) {
    return 'Couldn’t delete “$title”. Nothing was changed.';
  }

  @override
  String get permanentDeleteBlockedBackup =>
      'A backup is in progress. Wait for it to finish before deleting.';

  @override
  String get permanentDeleteBlockedRestore =>
      'A restore is in progress. Finish it before deleting permanently.';

  @override
  String get selectAction => 'Select';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get selectionClose => 'Close selection';

  @override
  String get selectAll => 'Select all';

  @override
  String get selectAllResults => 'Select all results';

  @override
  String permanentDeleteManyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Permanently delete $count items?',
      one: 'Permanently delete 1 item?',
    );
    return '$_temp0';
  }

  @override
  String get permanentDeleteManyBody =>
      'This can’t be undone. The selected items and their history will be deleted from this device. Photos and attachments used only by these items will be deleted too. Linked people and places remain. A backup created earlier can bring the items back.';

  @override
  String permanentDeleteManyDoneSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items deleted from this device.',
      one: '1 item deleted from this device.',
    );
    return '$_temp0';
  }

  @override
  String permanentDeleteManyPartialSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count items deleted. Some files will be reclaimed later with “Free up space”.',
      one:
          '1 item deleted. Some files will be reclaimed later with “Free up space”.',
    );
    return '$_temp0';
  }

  @override
  String get permanentDeleteManyFailedSnack =>
      'Couldn’t delete the selected items. Nothing was changed.';

  @override
  String get permanentDeleteStaleSnack =>
      'The selection changed. Nothing was deleted.';

  @override
  String get storageSectionTitle => 'Space on the device';

  @override
  String get storageBody =>
      'Pole² can look for photographs that no longer belong to any item.';

  @override
  String get storageScanAction => 'Check the space';

  @override
  String get storageScanning => 'Checking the space…';

  @override
  String get storageNoCandidates => 'There are no unused files to remove.';

  @override
  String storageCandidates(String size) {
    return 'You can free up about $size. Only photographs that Pole² no longer uses will be removed. Backups and recoverable data won’t be touched.';
  }

  @override
  String get storageCleanCancel => 'Cancel';

  @override
  String get storageCleanAction => 'Free up space';

  @override
  String get storageCleaning => 'Freeing up space…';

  @override
  String storageDone(String size) {
    return 'Space freed: $size.';
  }

  @override
  String storagePartial(String size) {
    return 'Space freed: $size. Some files weren’t removed.';
  }

  @override
  String get storageScanFailed =>
      'Couldn’t check the space. Nothing was changed.';

  @override
  String get storageBlockedBackup =>
      'A backup is in progress. Wait for it to finish before freeing up space.';

  @override
  String get storageBlockedRestore =>
      'A restore is in progress. Finish it before freeing up space.';

  @override
  String get storageBlockedPermanentDelete =>
      'A deletion is in progress. Wait for it to finish before freeing up space.';

  @override
  String get mediaSaveBlockedBackup =>
      'A backup is in progress. Try saving the photo again shortly.';

  @override
  String get mediaSaveBlockedRestore =>
      'A restore is in progress. Finish it before saving the photo.';

  @override
  String get mediaSaveBlockedBusy =>
      'An operation is in progress. Try saving the photo again shortly.';

  @override
  String get mediaSaveFailed => 'Couldn’t save the photo. Nothing was changed.';
}
