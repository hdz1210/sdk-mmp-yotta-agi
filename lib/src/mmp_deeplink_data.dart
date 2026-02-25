/// Data model representing a resolved deep link.
///
/// This is returned to the host app via [MMPSdk.onDeepLinkReceived] callback
/// for both Direct and Deferred Deep Links.
class MMPDeeplinkData {
  /// The UTM source of the campaign. Example: 'facebook'
  final String? utmSource;

  /// The UTM campaign name. Example: 'summer_sale_2024'
  final String? utmCampaign;

  /// The deep link slug. Example: 'khuyen-mai-he'
  final String? slug;

  /// The referral code for affiliate tracking. Example: 'REF_JOHN_123'
  final String? referralCode;

  /// The target screen path in the host app. Example: '/products'
  final String? targetScreen;

  /// All query parameters from the deep link URL.
  /// Example: { 'id': '123', 'ref': 'ABC', 'utm_source': 'facebook' }
  final Map<String, String> queryParams;

  /// The match score from fingerprint matching (0-3).
  /// Only available for Deferred Deep Links.
  /// 3 = IP match, 2 = Device model match, 1 = OS version match
  final int? matchScore;

  /// Whether this link was resolved via Direct (true) or Deferred (false).
  final bool isDirect;

  /// The raw URI that triggered this deep link (only for Direct).
  final Uri? rawUri;

  /// Duration between link click (from DB created_at) and app open (only for Deferred).
  final Duration? clickToOpenDuration;

  const MMPDeeplinkData({
    this.utmSource,
    this.utmCampaign,
    this.slug,
    this.referralCode,
    this.targetScreen,
    this.queryParams = const {},
    this.matchScore,
    this.isDirect = false,
    this.rawUri,
    this.clickToOpenDuration,
  });

  @override
  String toString() {
    return 'MMPDeeplinkData('
        'source: $utmSource, '
        'campaign: $utmCampaign, '
        'slug: $slug, '
        'referral: $referralCode, '
        'screen: $targetScreen, '
        'params: $queryParams, '
        'isDirect: $isDirect, '
        'score: $matchScore)';
  }

  /// Converts the object to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'utmSource': utmSource,
      'utmCampaign': utmCampaign,
      'slug': slug,
      'referralCode': referralCode,
      'targetScreen': targetScreen,
      'queryParams': queryParams,
      'matchScore': matchScore,
      'isDirect': isDirect,
      'rawUri': rawUri?.toString(),
      'clickToOpenDuration': clickToOpenDuration?.inMilliseconds,
    };
  }

  /// Creates an object from a JSON map (used when restoring from storage).
  factory MMPDeeplinkData.fromJson(Map<String, dynamic> json) {
    return MMPDeeplinkData(
      utmSource: json['utmSource'],
      utmCampaign: json['utmCampaign'],
      slug: json['slug'],
      referralCode: json['referralCode'],
      targetScreen: json['targetScreen'],
      queryParams: Map<String, String>.from(json['queryParams'] ?? {}),
      matchScore: json['matchScore'],
      isDirect: json['isDirect'] ?? false,
      rawUri: json['rawUri'] != null ? Uri.tryParse(json['rawUri']) : null,
      clickToOpenDuration: json['clickToOpenDuration'] != null ? Duration(milliseconds: json['clickToOpenDuration']) : null,
    );
  }
}
