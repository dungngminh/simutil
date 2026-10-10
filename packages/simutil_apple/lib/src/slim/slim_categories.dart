// Ported from simslim (https://github.com/MobAI-App/simslim) `profiles.go`,
// Copyright (c) Interlap, MIT License.

/// A group of simulator launchd daemons that slimming disables together.
class SlimCategory {
  /// Creates a category.
  const SlimCategory({
    required this.id,
    required this.name,
    required this.downside,
    required this.approxMemoryMB,
    required this.labels,
    this.alwaysEnabled = const [],
  });

  /// Stable id, e.g. `siri`.
  final String id;

  /// Display name.
  final String name;

  /// What stops working while the category is disabled.
  final String downside;

  /// Rough memory saved (iOS 26.5, not additive).
  final int approxMemoryMB;

  /// launchd labels disabled by this category.
  final List<String> labels;

  /// Labels shown with the category but never disabled.
  final List<String> alwaysEnabled;
}

/// Every category a slim profile may disable.
const slimCategories = <SlimCategory>[
  SlimCategory(
    id: 'widgets',
    name: 'Widgets & Wallpaper',
    downside:
        'Home and Lock Screen widgets, wallpaper posters, and Live Activities stop updating.',
    approxMemoryMB: 675,
    labels: [
      'com.apple.PosterBoard',
      'com.apple.chronod',
      'com.apple.liveactivitiesd',
      'com.apple.navd',
    ],
  ),
  SlimCategory(
    id: 'siri',
    name: 'Siri & Intelligence',
    downside:
        'Siri, speech features, and Apple Intelligence services are unavailable.',
    approxMemoryMB: 265,
    labels: [
      'com.apple.assistant_cdmd',
      'com.apple.assistant_service',
      'com.apple.siriactionsd',
      'com.apple.siriinferenced',
      'com.apple.siriknowledged',
      'com.apple.sirittsd',
      'com.apple.siri.context.service',
      'com.apple.siri.acousticsignature',
      'com.apple.corespeechd',
      'com.apple.voiced',
      'com.apple.voicebankingd',
      'com.apple.speechmodeltrainingd',
      'com.apple.intelligenceplatformd',
      'com.apple.intelligencecontextd',
      'com.apple.intelligenceflowd',
      'com.apple.intelligencetasksd',
      'com.apple.generativeexperiencesd',
      'com.apple.knowledgeconstructiond',
      'com.apple.naturallanguaged',
      'com.apple.textunderstandingd',
      'com.apple.modelcatalogd',
      'com.apple.modelmanagerd',
      'com.apple.mlhostd',
      'com.apple.mlruntimed',
      'com.apple.suggestd',
      'com.apple.parsecd',
      'com.apple.parsec-fbf',
      'com.apple.proactiveeventtrackerd',
    ],
    alwaysEnabled: ['com.apple.assistantd'],
  ),
  SlimCategory(
    id: 'search',
    name: 'Spotlight & Search',
    downside: 'Spotlight and Settings search return no results.',
    approxMemoryMB: 50,
    labels: [
      'com.apple.searchd',
      'com.apple.searchtoold',
      'com.apple.spotlightknowledged',
      'com.apple.spotlightknowledged.updater',
      'com.apple.corespotlightservice',
    ],
  ),
  SlimCategory(
    id: 'icloud',
    name: 'iCloud & Apple Account',
    downside:
        'iCloud sync, Apple Account, Keychain, and backup workflows will not work.',
    approxMemoryMB: 100,
    labels: [
      'com.apple.appleaccountd',
      'com.apple.appleaccounttransparencyd',
      'com.apple.appleidsetupd',
      'com.apple.akd',
      'com.apple.amsaccountsd',
      'com.apple.amsengagementd',
      'com.apple.amsondevicestoraged',
      'com.apple.cloudd',
      'com.apple.cloudphotod',
      'com.apple.ckdiscretionaryd',
      'com.apple.cloudsettingssyncagent',
      'com.apple.bird',
      'com.apple.syncdefaultsd',
      'com.apple.cdpd',
      'com.apple.sosd',
      'com.apple.SecureBackupDaemon',
      'com.apple.TrustedPeersHelper',
      'com.apple.protectedcloudstorage.protectedcloudkeysyncing',
      'com.apple.icloudmailagent',
      'com.apple.icloudsubscriptionoptimizerd',
      'com.apple.communicationtrustd',
    ],
  ),
  SlimCategory(
    id: 'store',
    name: 'App Store, Push & Media',
    downside:
        'Remote push notifications and StoreKit or App Store testing will not work.',
    approxMemoryMB: 80,
    labels: [
      'com.apple.appstored',
      'com.apple.appstorecomponentsd',
      'com.apple.apsd',
      'com.apple.itunescloudd',
      'com.apple.itunesstored',
      'com.apple.storekitd',
      'com.apple.amsaccountsd',
      'com.apple.amsengagementd',
      'com.apple.amsondevicestoraged',
      'com.apple.passd',
      'com.apple.financed',
      'com.apple.videosubscriptionsd',
      'com.apple.assetsubscriptiond',
      'com.apple.musicd',
    ],
  ),
  SlimCategory(
    id: 'pim',
    name: 'Mail, Calendar & Contacts',
    downside:
        'Contacts, Calendar, Reminders, and Mail-backed pickers or sync may fail.',
    approxMemoryMB: 80,
    labels: [
      'com.apple.email.maild',
      'com.apple.exchangesyncd',
      'com.apple.dataaccess.dataaccessd',
      'com.apple.calaccessd',
      'com.apple.remindd',
      'com.apple.contactsd',
      'com.apple.contacts.postersyncd',
      'com.apple.peopled',
    ],
  ),
  SlimCategory(
    id: 'web',
    name: 'Safari Sync & Web Services',
    downside:
        'Universal links and Safari sync or background web services will not work.',
    approxMemoryMB: 50,
    labels: [
      'com.apple.SafariBookmarksSyncAgent',
      'com.apple.Safari.History',
      'com.apple.Safari.passwordbreachd',
      'com.apple.Safari.SafeBrowsing.Service',
      'com.apple.safarifetcherd',
      'com.apple.WebBookmarks.webbookmarksd',
      'com.apple.webkit.adattributiond',
      'com.apple.webkit.webpushd',
      'com.apple.webprivacyd',
      'com.apple.swcd',
    ],
  ),
  SlimCategory(
    id: 'family',
    name: 'Family & Screen Time',
    downside: 'Family Sharing, Screen Time, and usage tracking stop working.',
    approxMemoryMB: 65,
    labels: [
      'com.apple.familycircled',
      'com.apple.FamilyControlsAgent',
      'com.apple.familynotification',
      'com.apple.askpermissiond',
      'com.apple.asktod',
      'com.apple.ScreenTimeAgent',
      'com.apple.ScreenTimeSettingsAgent',
      'com.apple.UsageTrackingAgent',
    ],
  ),
  SlimCategory(
    id: 'health',
    name: 'Health, Home & Fitness',
    downside: 'HealthKit, HomeKit, and Fitness integrations will not work.',
    approxMemoryMB: 135,
    labels: [
      'com.apple.healthd',
      'com.apple.healthappd',
      'com.apple.healthcontentd',
      'com.apple.healtheventsd',
      'com.apple.healthrecordsd',
      'com.apple.finhealthd',
      'com.apple.homed',
      'com.apple.homeeventsd',
      'com.apple.fitcore',
      'com.apple.fitcore.session',
      'com.apple.fitnesscoachingd',
      'com.apple.fitnessintelligenced',
      'com.apple.activityawardsd',
      'com.apple.activitysharingd',
    ],
  ),
  SlimCategory(
    id: 'photos',
    name: 'Photos & Media Analysis',
    downside:
        'Photo picker, Photos-library workflows, and media analysis may fail.',
    approxMemoryMB: 60,
    labels: [
      'com.apple.photoanalysisd',
      'com.apple.photosface',
      'com.apple.mediaanalysisd',
      'com.apple.mediaanalysisd.service',
      'com.apple.mediastream.mstreamd',
      'com.apple.medialibraryd',
      'com.apple.assetsd',
      'com.apple.assetsd.nebulad',
    ],
  ),
  SlimCategory(
    id: 'apps',
    name: 'News, Weather, Maps & Games',
    downside:
        'News, Weather, Maps background data, and game-controller services are unavailable.',
    approxMemoryMB: 90,
    labels: [
      'com.apple.newsd',
      'com.apple.weatherd',
      'com.apple.Maps.mapssyncd',
      'com.apple.Maps.mapspushd',
      'com.apple.Maps.geocorrectiond',
      'com.apple.maps.destinationd',
      'com.apple.MapKit.SnapshotService',
      'com.apple.jetpackassetd',
      'com.apple.tipsd',
      'com.apple.gamesaved',
      'com.apple.GameController.gamecontrollerd',
    ],
    alwaysEnabled: ['com.apple.gamed'],
  ),
  SlimCategory(
    id: 'messaging',
    name: 'Messaging & FaceTime',
    downside:
        'iMessage, FaceTime, and related identity services will not work.',
    approxMemoryMB: 60,
    labels: [
      'com.apple.identityservicesd',
      'com.apple.ids_simd',
      'com.apple.imautomatichistorydeletionagent',
      'com.apple.imcore.imtransferagent',
      'com.apple.imdpersistence.IMDPersistenceAgent',
      'com.apple.facetimemessagestored',
      'com.apple.telephonyutilities.callservicesd',
    ],
  ),
  SlimCategory(
    id: 'connectivity',
    name: 'Sharing & Device Connectivity',
    downside:
        'AirDrop, Continuity, CarPlay, Watch, and Find My connectivity will not work.',
    approxMemoryMB: 65,
    labels: [
      'com.apple.rapportd',
      'com.apple.companiond',
      'com.apple.carkitd',
      'com.apple.wcd',
      'com.apple.tvremoted',
      'com.apple.avatarsd',
      'com.apple.stickersd',
      'com.apple.sociallayerd',
      'com.apple.announced',
      'com.apple.navd',
      'com.apple.findmy.findmylocated',
    ],
    alwaysEnabled: ['com.apple.sharingd'],
  ),
  SlimCategory(
    id: 'telemetry',
    name: 'Ads, Diagnostics & Telemetry',
    downside:
        'DeviceCheck plus analytics, diagnostics, and feedback services are unavailable.',
    approxMemoryMB: 105,
    labels: [
      'com.apple.ap.adprivacyd',
      'com.apple.ap.promotedcontentd',
      'com.apple.diagnosticextensionsd',
      'com.apple.feedbackd',
      'com.apple.rtcreportingd',
      'com.apple.securityuploadd',
      'com.apple.geoanalyticsd',
      'com.apple.triald',
      'com.apple.followupd',
      'com.apple.purplebuddy.budd',
      'com.apple.devicecheckd',
    ],
  ),
  SlimCategory(
    id: 'other',
    name: 'Other Background Services',
    downside:
        'Wallet, merchant, business, asset, and miscellaneous background services are unavailable.',
    approxMemoryMB: 195,
    labels: [
      'com.apple.financed',
      'com.apple.passd',
      'com.apple.merchantd',
      'com.apple.coreidvd',
      'com.apple.businessservicesd',
      'com.apple.deviceaccessd',
      'com.apple.replicatord',
      'com.apple.linkd',
      'com.apple.ind',
      'com.apple.storagedatad',
      'com.apple.StatusKitAgent',
      'com.apple.countryd',
      'com.apple.mobileassetd',
      'com.apple.managedconfiguration.passcodenagd',
    ],
  ),
];
