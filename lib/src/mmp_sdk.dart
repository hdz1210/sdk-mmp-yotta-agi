import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'mmp_config.dart';
import 'mmp_deeplink_data.dart';
import 'mmp_attribution_popup.dart';

/// MMP SDK — Deep Link Attribution & Deferred Deep Linking.
///
/// Usage:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await MMPSdk.initialize(
///     config: MMPConfig(
///       appKey: 'your-app-key',
///       endpoint: 'https://mmp.omnigen.cloud',
///     ),
///   );
///
///   MMPSdk.onDeepLinkReceived((data) {
///     // Navigate based on data.targetScreen and data.queryParams
///   });
///
///   runApp(MyApp());
/// }
/// ```
class MMPSdk {
  // ────────── Singleton ──────────
  static MMPSdk? _instance;
  static MMPSdk get _i => _instance ?? (throw StateError('MMPSdk not initialized. Call MMPSdk.initialize() first.'));

  // ────────── Config ──────────
  final MMPConfig _config;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // ────────── Callback ──────────
  static void Function(MMPDeeplinkData data)? _onDeepLinkCallback;
  static MMPDeeplinkData? _pendingData; // Buffer for links arriving before callback is set

  // ────────── Device fingerprint cache ──────────
  String? _cachedIp;
  String? _cachedModel;
  String? _cachedOsVersion;

  // ────────── Debug log (visible in both debug and release) ──────────
  static final List<String> debugLogs = [];
  static void _log(String msg) {
    final entry = '[${DateTime.now().toString().substring(11, 19)}] $msg';
    debugLogs.add(entry);
    print('[MMP SDK] $msg');
  }

  // ────────── Private constructor ──────────
  MMPSdk._(this._config);

  // ═══════════════════════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════════════════════

  /// Initialize the MMP SDK. Must be called once before any other method.
  ///
  /// [config] contains the app key and endpoint URL.
  /// [enableDeferredCheck] set false to skip Deferred Deep Link check on first launch.
  static Future<void> initialize({
    required MMPConfig config,
    bool enableDeferredCheck = true,
  }) async {
    if (_instance != null) return; // Already initialized

    final sdk = MMPSdk._(config);
    _instance = sdk;

    sdk._appLinks = AppLinks();

    // Wait for network to be ready (release mode may start before network stack is initialized)
    await sdk._waitForNetwork();

    // Collect device fingerprint
    await sdk._collectFingerprint();

    // STEP 1: Check for Direct Deep Link first (cold start)
    bool hasDirectLink = await sdk._checkInitialDirectLink();
    _log('Initial direct link found: $hasDirectLink');

    // STEP 2: Only check Deferred if NO direct link was found
    if (!hasDirectLink && enableDeferredCheck) {
      await sdk._checkDeferredDeepLink();
    }

    // STEP 3: Start listening for future links (hot start / warm start)
    sdk._listenForHotLinks();
  }

  /// Wait until network is available (retry up to 3 times with 1s delay).
  /// In release mode, initialize() runs before runApp(), and the network
  /// stack may not be ready yet, causing DNS lookup failures.
  Future<void> _waitForNetwork() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('https://api64.ipify.org?format=json'),
        ).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _log('Network ready (attempt $attempt)');
          
          // Fast-path: cache IP directly to avoid a second redundant network call
          try {
            final data = json.decode(response.body);
            if (data['ip'] != null) {
              _cachedIp = data['ip'];
            }
          } catch (_) {}
          
          return;
        }
      } catch (e) {
        _log('Network not ready (attempt $attempt): ${e.runtimeType}');
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    _log('⚠️ Network may be unavailable after 3 attempts');
  }

  /// Register a callback to receive deep link data.
  /// This callback fires for BOTH Direct and Deferred Deep Links.
  static void onDeepLinkReceived(void Function(MMPDeeplinkData data) callback) {
    _onDeepLinkCallback = callback;

    // Replay any pending deep link data that arrived before callback was set
    if (_pendingData != null) {
      _log('Replaying buffered deep link: target=${_pendingData!.targetScreen}, isDirect=${_pendingData!.isDirect}');
      final data = _pendingData!;
      _pendingData = null;
      // Use addPostFrameCallback + tiny delay to ensure widget tree + navigator are fully ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 50), () {
          callback(data);
        });
      });
    }
  }

  /// Manually trigger a Deferred Deep Link check.
  /// Useful if you disabled it during [initialize] and want to check later.
  static Future<void> checkDeferredDeepLink() async {
    await _i._checkDeferredDeepLink();
  }

  /// Clean up resources. Call when the app is being disposed.
  static void dispose() {
    _instance?._linkSubscription?.cancel();
    _instance = null;
    _onDeepLinkCallback = null;
  }

  /// Retrieves and consumes (deletes) the pending deep link data from storage.
  /// Use this method after the user successfully logs in to navigate to the delayed target screen.
  static Future<MMPDeeplinkData?> consumePendingNavigation() async {
    try {
      _pendingData = null; // Clear RAM buffer to prevent double-replaying

      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('mmp_pending_navigation');
      if (jsonStr != null) {
        final data = MMPDeeplinkData.fromJson(json.decode(jsonStr));
        await prefs.remove('mmp_pending_navigation');
        _log('Consumed pending navigation from storage: ${data.targetScreen}');
        return data;
      }
    } catch (e) {
      _log('Failed to consume pending navigation: $e');
    }
    return null;
  }

  static Future<void> _savePendingNavigation(MMPDeeplinkData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mmp_pending_navigation', json.encode(data.toJson()));
      _log('Saved pending navigation to storage');
    } catch (e) {
      _log('Failed to save pending navigation: $e');
    }
  }

  /// Enable automatic Attribution Popup + Screen Navigation.
  /// Just call this once after initialize and the SDK handles everything.
  /// Works for cold start (app tắt hoàn toàn) and hot start (app đang mở).
  ///
  /// [onData] — Optional callback for custom navigation (e.g. go_router).
  /// When provided, SDK delegates navigation to this callback instead of
  /// calling `pushNamed()`. Popup is always shown by SDK regardless.
  ///
  /// Navigator 1.0 (MaterialApp):
  /// ```dart
  /// MMPSdk.enableAutoPopup(navigatorKey);
  /// ```
  ///
  /// Navigator 2.0 (go_router):
  /// ```dart
  /// MMPSdk.enableAutoPopup(navigatorKey, onData: (data) {
  ///   GoRouter.of(navigatorKey.currentContext!).push(data.targetScreen!);
  /// });
  /// ```
  static String? _recentLinkSignature;
  static DateTime? _recentLinkTime;

  static void enableAutoPopup(
    GlobalKey<NavigatorState> navigatorKey, {
    void Function(MMPDeeplinkData data)? onData,
  }) {
    // Flag to prevent double-firing if both RAM buffer and Storage have the pending data
    bool hasReplayedFromRAM = _pendingData != null;

    // First hook up the listener (this will auto-replay the RAM buffer if any)
    onDeepLinkReceived((data) {
      // ────────── Deduplication Guard ──────────
      // Prevent double execution from overlapping sources (RAM buffer, Storage buffer, Hot Link stream)
      final signature = json.encode(data.toJson());
      final now = DateTime.now();
      if (_recentLinkSignature == signature && 
          _recentLinkTime != null && 
          now.difference(_recentLinkTime!).inMilliseconds < 1500) {
        _log('AutoPopup deduplication: ignoring identical event within 1.5s');
        return;
      }
      _recentLinkSignature = signature;
      _recentLinkTime = now;

      // Clear pending navigation from storage since we are handling it
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('mmp_pending_navigation');
      });

      // 1. Navigate to target screen
      if (data.targetScreen != null && data.targetScreen!.isNotEmpty) {
        if (onData != null) {
          // Delegate navigation to the host app (supports go_router / Navigator 2.0)
          onData.call(data);
        } else {
          // Default: use Navigator 1.0 pushNamed
          navigatorKey.currentState?.pushNamed(
            data.targetScreen!,
            arguments: data.queryParams,
          );
        }
      } else {
        // No target screen — still notify onData if provided
        onData?.call(data);
      }

      // 2. Show popup AFTER navigation
      Future.delayed(const Duration(milliseconds: 500), () {
        final navigator = navigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          // Push DialogRoute directly onto the navigator — bypasses
          // showDialog's context ancestry lookup which fails with go_router.
          navigator.push(
            DialogRoute(
              context: navigator.context,
              barrierDismissible: true,
              builder: (_) => MMPAttributionPopup.buildDialog(data),
            ),
          );
        }
      });
    });

    // Only recover from Storage if we DID NOT just replay from RAM
    if (!hasReplayedFromRAM) {
      consumePendingNavigation().then((pending) {
        if (pending != null) {
          _log('AutoPopup recovering stored pending navigation');
          _onDeepLinkCallback?.call(pending);
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  DIRECT DEEP LINK — App Links / Universal Links
  // ═══════════════════════════════════════════════════════════

  /// Check for an initial deep link (cold start). Returns true if found.
  Future<bool> _checkInitialDirectLink() async {
    try {
      final Uri? uri = await _appLinks.getInitialAppLink();
      if (uri != null) {
        _log('Cold start direct link: $uri');
        await _handleDirectLink(uri);
        return true;
      }
    } catch (e) {
      _log('Failed to get initial link: $e');
    }
    return false;
  }

  /// Listen for links while app is already running (hot start).
  void _listenForHotLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) => _handleDirectLink(uri),
      onError: (err) => print('[MMP SDK] Link stream error: $err'),
    );
  }

  // ────────── Link deduplication cache ──────────
  static String? _lastHandledUriStr;
  static DateTime? _lastHandledUriTime;

  Future<void> _handleDirectLink(Uri uri) async {
    _log('Direct link received: $uri');

    // Prevent duplicate processing of the exact same URI in rapid succession from underlying OS streams
    final uriStr = uri.toString();
    final now = DateTime.now();
    if (_lastHandledUriStr == uriStr &&
        _lastHandledUriTime != null &&
        now.difference(_lastHandledUriTime!).inMilliseconds < 1500) {
      _log('Ignoring duplicate rapid-fire link: $uriStr');
      return;
    }
    _lastHandledUriStr = uriStr;
    _lastHandledUriTime = now;

    // Only process links that belong to our configured domain
    final domain = _config.linkDomain;
    if (domain != null && !uri.host.contains(domain)) {
      _log('Ignoring link from unrelated domain: ${uri.host}');
      return;
    }

    final params = uri.queryParameters;
    String? utmSource = params['utm_source'];
    String? utmCampaign = params['utm_campaign'];
    String? slug = params['slug'];
    String? referralCode = params['referral_code'];
    String? targetScreen = uri.path.isNotEmpty && uri.path != '/' ? uri.path : params['target_screen'];

    // Unwrap short links (e.g. mmp.omnigen.cloud/app/r/slug123)
    if (uri.path.contains('/r/')) {
      final parts = uri.path.split('/r/');
      if (parts.length > 1) {
        final extractedSlug = parts.last.split('/').first;
        if (extractedSlug.isNotEmpty) {
          slug = extractedSlug;
          try {
            _log('Unwrapping short link slug: $slug');
            final response = await http.get(Uri.parse('${_config.endpoint}/api/deeplinks/resolve/$slug'));
            if (response.statusCode == 200) {
              final jsonResp = json.decode(response.body);
              if (jsonResp['success'] == true) {
                final resolvedData = jsonResp['data'];
                utmSource = resolvedData['utm_source'] ?? utmSource;
                utmCampaign = resolvedData['utm_campaign'] ?? utmCampaign;
                referralCode = resolvedData['referral_code'] ?? referralCode;
                targetScreen = resolvedData['target_screen'] ?? targetScreen;
                _log('Successfully resolved short link -> Target: $targetScreen');
              }
            } else {
              _log('Failed to unwrap slug, API returned: ${response.statusCode}');
            }
          } catch (e) {
            _log('Network error unwrapping slug: $e');
          }
        }
      }
    }

    final data = MMPDeeplinkData(
      utmSource: utmSource,
      utmCampaign: utmCampaign,
      slug: slug,
      referralCode: referralCode,
      targetScreen: targetScreen,
      queryParams: params,
      isDirect: true,
      rawUri: uri,
    );

    await _savePendingNavigation(data);

    _log('Direct deep link resolved: $data');
    if (_onDeepLinkCallback != null) {
      _onDeepLinkCallback!.call(data);
    } else {
      _log('Callback not yet registered, buffering data for later replay');
      _pendingData = data;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  DEFERRED DEEP LINK — Fingerprint matching via API
  // ═══════════════════════════════════════════════════════════

  Future<void> _checkDeferredDeepLink() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Only run deferred check ONCE (first launch after install)
      final alreadyChecked = prefs.getBool('mmp_deferred_done') ?? false;
      if (alreadyChecked) {
        print('[MMP SDK] Deferred check already done. Skipping.');
        return;
      }

      // If the app's VERY FIRST launch was via a Direct Link, the deferred check was skipped.
      // But mmp_pending_navigation was saved. If we open the app normally later, 
      // we DO NOT want the Deferred check to overwrite that pristine Direct Link!
      if (prefs.containsKey('mmp_pending_navigation')) {
        _log('A pending Direct Link exists. Skipping Deferred check to avoid overwriting it.');
        await prefs.setBool('mmp_deferred_done', true);
        return;
      }

      // Mark as done immediately so it never runs again
      await prefs.setBool('mmp_deferred_done', true);

      final matchedSlugs = prefs.getStringList('mmp_matched_slugs') ?? [];

      final ip = _cachedIp ?? 'Unknown';
      final model = _cachedModel ?? 'Unknown';
      final osVersion = _cachedOsVersion ?? 'Unknown';

      _log('DEFERRED CHECK - IP=$ip, Model=$model, OS=$osVersion');
      _log('Excluded slugs: $matchedSlugs');
      _log('Endpoint: ${_config.endpoint}/api/query-campaigns');

      final url = '${_config.endpoint}/api/query-campaigns';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-app-key': _config.appKey,
        },
        body: json.encode({
          'ip_address': ip,
          'device_model': model,
          'os_version': osVersion,
          'excluded_slugs': matchedSlugs,
        }),
      );

      _log('API Status: ${response.statusCode}');
      _log('API Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['success'] == true && result['campaign'] != null) {
          final campaign = result['campaign'];
          final slug = campaign['slug'];

          _log('✅ MATCH FOUND! Slug=$slug, Score=${campaign['match_score']}');

          if (slug != null && !matchedSlugs.contains(slug)) {
            // Save matched slug to prevent re-matching
            matchedSlugs.add(slug);
            await prefs.setStringList('mmp_matched_slugs', matchedSlugs);

            final data = MMPDeeplinkData(
              utmSource: campaign['source'],
              utmCampaign: campaign['campaign'],
              slug: slug,
              referralCode: campaign['referral_code'],
              targetScreen: campaign['target_screen'],
              queryParams: {
                if (campaign['source'] != null) 'utm_source': campaign['source'],
                if (campaign['campaign'] != null) 'utm_campaign': campaign['campaign'],
                if (campaign['referral_code'] != null) 'referral_code': campaign['referral_code'],
                if (slug != null) 'slug': slug,
              },
              matchScore: campaign['match_score'],
              isDirect: false,
              clickToOpenDuration: campaign['created_at'] != null 
                  ? DateTime.now().toUtc().difference(DateTime.parse(campaign['created_at']).toUtc())
                  : null,
            );

            await _savePendingNavigation(data);

            _log('Deferred resolved, isDirect=false');
            if (_onDeepLinkCallback != null) {
              _log('Callback registered, calling immediately');
              _onDeepLinkCallback!.call(data);
            } else {
              _log('Callback NOT registered → buffering deferred data');
              _pendingData = data;
            }
          } else {
            _log('⚠️ Slug "$slug" already matched. Skipping.');
          }
        } else {
          _log('❌ No deferred match. Message: ${result['message']}');
        }
      } else {
        _log('❌ API error: status ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ Deferred EXCEPTION: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  DEVICE FINGERPRINT COLLECTION
  // ═══════════════════════════════════════════════════════════

  Future<void> _collectFingerprint() async {
    try {
      // Get public IP only if not already cached by _waitForNetwork
      _cachedIp ??= await _getPublicIp();

      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        _cachedModel = info.model;
        _cachedOsVersion = info.version.release;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        _cachedModel = info.model;
        _cachedOsVersion = info.systemVersion;
      }

      _log('Fingerprint: IP=$_cachedIp, Model=$_cachedModel, OS=$_cachedOsVersion');
    } catch (e) {
      _log('Fingerprint FAILED: $e');
    }
  }

  Future<String> _getPublicIp() async {
    try {
      final response = await http.get(
        Uri.parse('https://api64.ipify.org?format=json'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ip'] ?? 'Unknown';
      }
    } catch (_) {}
    return 'Unknown';
  }
}
