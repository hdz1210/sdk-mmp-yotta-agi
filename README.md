# MMP SDK for Flutter

SDK hỗ trợ **Deep Link Attribution** và **Deferred Deep Linking** cho hệ thống MMP SaaS.

## Tính năng

- ✅ **Direct Deep Link**: Tự động bắt và bóc tách App Links / Universal Links
- ✅ **Deferred Deep Link**: Tự động nhận diện chiến dịch cho người dùng cài mới từ Store  
- ✅ **Device Fingerprinting**: Thu thập IP, Device Model, OS Version
- ✅ **Multi-tenant**: Hỗ trợ nhiều ứng dụng khách hàng qua App Key
- ✅ **Auto Popup**: Tự động hiện popup thông tin attribution
- ✅ **Auto Navigate**: Tự điều hướng tới Target Screen
- ✅ **Cold/Warm/Hot Start**: Hoạt động đúng ở mọi trạng thái app

## Cài đặt

Thêm vào `pubspec.yaml`:

```yaml
dependencies:
  mmp_sdk_flutter:
    git:
      url: https://github.com/hdz1210/sdk-mmp-yotta-agi.git
      ref: main
```

## Cấu hình Android (BẮT BUỘC)

> ⚠️ **QUAN TRỌNG**: Phải cấu hình đúng AndroidManifest.xml, nếu không deep link sẽ KHÔNG hoạt động khi app chạy ngầm.

### Bước 1: Sửa `android/app/src/main/AndroidManifest.xml`

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTask"
    ...>
```

**Yêu cầu bắt buộc:**

| Thuộc tính | Giá trị | Lý do |
|---|---|---|
| `launchMode` | **`singleTask`** ⚠️ | Đảm bảo chỉ có 1 instance activity, mọi Intent mới gửi qua `onNewIntent` |
| `taskAffinity` | **XÓA DÒNG NÀY** ⚠️ | Nếu để `taskAffinity=""` (mặc định Flutter), app tạo task riêng → Intent từ browser KHÔNG gửi được `onNewIntent` → mất link! |

> **Lưu ý:** Template mặc định Flutter dùng `singleTop` + `taskAffinity=""`. Cấu hình này gây lỗi warm start deep link. Tất cả deep linking SDK lớn (Branch, AppsFlyer, Adjust) đều yêu cầu `singleTask`.

### Bước 2: Thêm Intent Filter cho App Links

```xml
<!-- App Links (Web Domain) -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="mmp.omnigen.cloud" />
</intent-filter>
```

### AndroidManifest.xml hoàn chỉnh (mẫu)

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTask"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">

    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- App Links -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="mmp.omnigen.cloud" />
    </intent-filter>
</activity>
```

---

## Sử dụng

> ⚠️ **QUAN TRỌNG: Navigator 1.0 vs Navigator 2.0 (go_router)**
>
> Cả 2 đều dùng `enableAutoPopup()`. Khác biệt duy nhất: Navigator 2.0 cần thêm `onData` callback để tự điều hướng bằng `GoRouter.of(ctx).push()` vì `pushNamed()` bên trong SDK chỉ hoạt động với Navigator 1.0.

| Cấu hình app | Dùng cách nào? |
|---|---|
| `MaterialApp` + `onGenerateRoute` (Navigator 1.0) | ✅ **Cách 1A: Auto Popup** |
| `MaterialApp.router` + `go_router` (Navigator 2.0) | ✅ **Cách 1B: Auto Popup + onData** |
| App có màn Đăng Nhập (Auth Wall) | ✅ **Cách 2** |

---

### Cách 1A: Auto Popup — Navigator 1.0 (MaterialApp) ⭐

> Chỉ dành cho app dùng `MaterialApp` + `onGenerateRoute` (Navigator 1.0 truyền thống).

Chỉ cần **2 dòng code**. SDK tự xử lý: popup + điều hướng + cold/warm/hot start.

```dart
import 'package:mmp_sdk_flutter/mmp_sdk_flutter.dart';

// ① Khai báo navigatorKey ở GLOBAL SCOPE
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ② Khởi tạo SDK
  await MMPSdk.initialize(
    config: const MMPConfig(
      appKey: 'your-app-key-from-admin-panel',
      endpoint: 'https://mmp.omnigen.cloud',
      linkDomain: 'mmp.omnigen.cloud',
    ),
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ③ GẮN navigatorKey vào MaterialApp
      navigatorKey: navigatorKey,
      onGenerateRoute: (settings) {
        // ④ Định nghĩa routing cho app (Navigator 1.0)
        if (settings.name == '/product') {
          return MaterialPageRoute(builder: (_) => ProductScreen());
        }
        if (settings.name == '/super-sale') {
          return MaterialPageRoute(builder: (_) => SuperSaleScreen());
        }
        return MaterialPageRoute(builder: (_) => HomeScreen());
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // ⑤ CHỈ CẦN 1 DÒNG NÀY — SDK lo tất cả!
    MMPSdk.enableAutoPopup(navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Home')));
  }
}
```

**Tại sao hoạt động?** SDK gọi `navigatorKey.currentState!.pushNamed(targetScreen)` bên trong → Navigator 1.0 tìm route qua `onGenerateRoute` → điều hướng đúng.

---

### Cách 1B: Tích hợp chuẩn cho Navigator 2.0 (`go_router`) ⭐

> `go_router` quản lý Navigator độc lập, do đó SDK **không thể** tự động push route hay hiện popup từ global context.  
> Để tích hợp hoàn hảo với `go_router` (popup hiển thị đúng, nút Back hoạt động), bạn làm theo 3 bước sau:

**B1. Khởi tạo SDK như bình thường:**

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MMPSdk.initialize(config: const MMPConfig(...));
  runApp(const MyApp());
}
```

**B2. Bắt buộc: Chặn URI Deep Link bằng `redirect` trong GoRouter**
> Nếu không có bước này, hệ điều hành sẽ mở thẳng màn hình đích → tạo ra "màn hình ma" (không có nút Back, không hiện được popup).

```dart
// lib/router/app_router.dart
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  // Chặn GoRouter tự navigate khi app mở từ deep link
  redirect: (context, state) {
    final params = state.uri.queryParameters;
    // Nếu có query của MMP -> Ép về Home ('/') để HomeScreen khởi tạo SDK
    if (params.containsKey('utm_source') || 
        params.containsKey('slug') || 
        state.uri.host.contains('mmp.omnigen.cloud')) {
      return '/';
    }
    return null;
  },
  routes: [ /* ... */ ],
);
```

**B3. Xử lý Deep Link tại HomeScreen (Cực kỳ quan trọng)**

Trong `HomeScreen` của bạn, sử dụng `onDeepLinkReceived` và `consumePendingNavigation` (thay vì `enableAutoPopup`), kết hợp với cơ chế chống double-trigger.

```dart
// lib/screens/home_screen.dart
class _HomeScreenState extends State<HomeScreen> {
  String? _lastHandledSignature; // Biến chống double-trigger

  @override
  void initState() {
    super.initState();
    _setupDeepLink();
  }

  void _setupDeepLink() {
    // 1. Phục hồi deep link pending (Cold Start)
    MMPSdk.consumePendingNavigation().then((data) {
      if (data != null) _handleDeepLink(data);
    });

    // 2. Lắng nghe deep link stream (Hot/Warm Start)
    MMPSdk.onDeepLinkReceived((data) {
      _handleDeepLink(data);
    });
  }

  void _handleDeepLink(MMPDeeplinkData data) {
    // A. Chống xử lý 2 lần liên tiếp cùng 1 link
    final signature = '${data.slug}_${data.targetScreen}';
    if (_lastHandledSignature == signature) return;
    _lastHandledSignature = signature;

    // B. Điều hướng bằng go_router (Dùng context của widget -> Nút Back hoạt động)
    if (data.targetScreen != null && data.targetScreen!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push(data.targetScreen!, extra: data.queryParams);
      });
    }

    // C. Hiện popup bằng context của widget (Chậm lại 1 nhịp để route kịp push)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) MMPAttributionPopup.show(context, data);
    });
  }
}
```

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Home')));
  }
}
```

**Tại sao phải làm khác?**

| | Navigator 1.0 | Navigator 2.0 (go_router) |
|---|---|---|
| **Widget gốc** | `MaterialApp(navigatorKey: ...)` | `MaterialApp.router(routerConfig: ...)` |
| **Đăng ký route** | `onGenerateRoute` | `GoRouter(routes: [...])` |
| **Điều hướng** | `Navigator.pushNamed('/path')` | `context.push('/path')` / `GoRouter.of(ctx).push(...)` |
| **SDK `pushNamed()` hoạt động?** | ✅ Có | ❌ Không — route không được đăng ký với Navigator mặc định |
| **SDK popup hoạt động?** | ✅ Có (qua `navigatorKey.currentContext`) | ✅ Có (qua `navigatorKey.currentContext`) |

---

### Cách 2: App có màn hình Đăng Nhập (Auth Wall) 🔒

Nếu app của bạn bắt buộc người dùng Đăng Nhập / Đăng Ký trước khi truy cập vào ứng dụng, **MMP SDK sẽ tự động lưu lại Deep Link (Persistent Storage)** để dùng sau khi login thành công. Cách làm rất đơn giản:

**B1. Khởi tạo SDK ở màn hình Login:**
```dart
class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // Khởi tạo SDK để nhận link (nhưng KHÔNG tự chuyển trang)
    MMPSdk.initialize(config: const MMPConfig(
      appKey: 'your-app-key', 
      endpoint: 'https://mmp.omnigen.cloud',
      linkDomain: 'mmp.omnigen.cloud',
    ));
  }
}
```

**B2. Tự động phục hồi Deep Link ở HomeScreen:**

**Navigator 1.0:**
```dart
class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Sau khi login xong vào Home, bật AutoPopup. 
    // SDK sẽ tự động tìm thấy link đã lưu từ màn hình Login và thực thi ngay lập tức!
    MMPSdk.enableAutoPopup(navigatorKey);
  }
}
```

**Navigator 2.0 (go_router):**
```dart
class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Dùng consumePendingNavigation + manual navigation
    _recoverPendingLink();
  }

  Future<void> _recoverPendingLink() async {
    final data = await MMPSdk.consumePendingNavigation();
    if (data != null && data.targetScreen != null) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        GoRouter.of(ctx).push(data.targetScreen!, extra: data.queryParams);
        Future.delayed(const Duration(milliseconds: 300), () {
          final popupCtx = navigatorKey.currentContext;
          if (popupCtx != null) MMPAttributionPopup.show(popupCtx, data);
        });
      }
    }
    // Bật listener cho các link mới
    MMPSdk.onDeepLinkReceived((data) {
      if (data.targetScreen != null) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) GoRouter.of(ctx).push(data.targetScreen!, extra: data.queryParams);
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) MMPAttributionPopup.show(ctx, data);
      });
    });
  }
}
```
*Lưu ý: Dữ liệu được lưu an toàn trong SharedPreferences. Ngay cả khi người dùng bực mình tắt hẳn App (Force Quit) ở màn hình Login, thì ngày hôm sau họ mở lại App rồi Login, màn hình đích (targetScreen) vẫn sẽ bung ra như chưa hề có cuộc chia ly!*

---

### Cách 3: Manual Callback (Tùy chỉnh cao)

Nếu muốn tự xử lý logic hoàn toàn:

```dart
MMPSdk.onDeepLinkReceived((MMPDeeplinkData data) {
  print('Nguồn: ${data.utmSource}');
  print('Chiến dịch: ${data.utmCampaign}');
  print('Màn hình: ${data.targetScreen}');
  print('Referral: ${data.referralCode}');

  // Tự hiện popup nếu muốn
  MMPAttributionPopup.show(context, data);

  // Tự điều hướng — chọn 1 trong 2:
  // Navigator 1.0:
  navigatorKey.currentState?.pushNamed(
    data.targetScreen!,
    arguments: data.queryParams,
  );

  // Navigator 2.0 (go_router):
  // GoRouter.of(navigatorKey.currentContext!).push(
  //   data.targetScreen!,
  //   extra: data.queryParams,
  // );
});
```

---

## Tóm tắt: Cần sửa file nào?

### Navigator 1.0 (`MaterialApp` + `onGenerateRoute`)

| # | File | Thay đổi |
|---|---|---|
| 1 | `pubspec.yaml` | Thêm dependency `mmp_sdk_flutter` (git) |
| 2 | `android/app/src/main/AndroidManifest.xml` | `launchMode="singleTask"`, xóa `taskAffinity=""`, thêm intent-filter App Links |
| 3 | `lib/main.dart` | Khai báo `navigatorKey` global, gọi `MMPSdk.initialize()`, gắn `navigatorKey` vào `MaterialApp` |
| 4 | `lib/<home_screen>.dart` | Gọi `MMPSdk.enableAutoPopup(navigatorKey)` trong `initState()` |

### Navigator 2.0 (`MaterialApp.router` + `go_router`)

| # | File | Thay đổi |
|---|---|---|
| 1 | `pubspec.yaml` | Thêm dependency `mmp_sdk_flutter` (git) |
| 2 | `android/app/src/main/AndroidManifest.xml` | `launchMode="singleTask"`, xóa `taskAffinity=""`, thêm intent-filter App Links |
| 3 | `lib/main.dart` | Khai báo `navigatorKey` global, gọi `MMPSdk.initialize()` |
| 4 | `lib/router/app_router.dart` | Gắn `navigatorKey` vào `GoRouter(navigatorKey: navigatorKey)` |
| 5 | `lib/<home_screen>.dart` | Dùng `MMPSdk.enableAutoPopup(navigatorKey, onData: ...)` + `GoRouter.of(ctx).push()` |

> 💡 **Tip:** Navigator 1.0 = 4 file, Navigator 2.0 = 5 file (thêm `app_router.dart` vì `navigatorKey` phải gắn vào `GoRouter`)

---

## API Response (MMPDeeplinkData)

| Field | Type | Mô tả |
|-------|------|--------|
| `utmSource` | `String?` | Nguồn traffic (facebook, google...) |
| `utmCampaign` | `String?` | Tên chiến dịch |
| `slug` | `String?` | Slug của deep link |
| `referralCode` | `String?` | Mã giới thiệu (affiliate) |
| `targetScreen` | `String?` | Đường dẫn màn hình trong app |
| `queryParams` | `Map<String, String>` | Tất cả query parameters |
| `isDirect` | `bool` | `true` = Direct, `false` = Deferred |
| `matchScore` | `int?` | Điểm matching (chỉ Deferred) |

---

## Kiến trúc

```
Host App
  └── MMPSdk.initialize(appKey, endpoint)
        ├── enableAutoPopup(navigatorKey)
        │     ├── Popup Attribution (tự động)
        │     ├── Auto Navigate (tự động)
        │     └── Lifecycle Observer (warm start)
        ├── Direct Deep Link (AppLinks)
        │     ├── Cold start: getInitialAppLink() → buffer
        │     ├── Warm start: getLatestAppLink() on resume
        │     ├── Hot start: uriLinkStream
        │     └── onDeepLinkReceived(data)
        └── Deferred Deep Link (Fingerprint → API)
              ├── Collect: IP + Device Model + OS Version
              ├── POST /api/query-campaigns (x-app-key header)
              └── onDeepLinkReceived(data)
```

---

## Troubleshooting

### ❌ App mở trang chủ thay vì target screen (warm start)
**Nguyên nhân:** `AndroidManifest.xml` dùng `singleTop` + `taskAffinity=""`
**Fix:** Đổi sang `singleTask`, xóa `taskAffinity=""`

### ❌ Popup không hiện
**Nguyên nhân:** Chưa gọi `enableAutoPopup` hoặc `navigatorKey` chưa gắn vào `MaterialApp`
**Fix:** Đảm bảo `navigatorKey` được truyền vào cả `MaterialApp(navigatorKey: navigatorKey)` và `MMPSdk.enableAutoPopup(navigatorKey)`

### ❌ Deep link không nhận được gì
**Nguyên nhân:** SHA256 fingerprint trên Admin Panel không khớp với signing key của APK
**Fix:** Chạy `keytool -list -v -keystore ~/.android/debug.keystore` và cập nhật SHA256 trên Admin Panel
