/// Configuration for MMP SDK.
class MMPConfig {
  /// The unique App Key obtained from the MMP Admin Panel.
  final String appKey;

  /// The backend API endpoint URL.
  /// Example: 'https://mmp.omnigen.cloud'
  final String endpoint;

  /// The domain used for App Links / Universal Links.
  /// Must match the domain configured in your AndroidManifest.xml/Info.plist.
  /// Example: 'mmp.omnigen.cloud'
  final String? linkDomain;

  const MMPConfig({
    required this.appKey,
    required this.endpoint,
    this.linkDomain,
  });
}
