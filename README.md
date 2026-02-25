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
      url: https://github.com/your-org/mmp_sdk_flutter.git
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

### Cách 1: Auto Popup (Khuyến nghị) ⭐

Chỉ cần **2 dòng code**. SDK tự xử lý: popup + điều hướng + cold/warm/hot start.

```dart
import 'package:mmp_sdk_flutter/mmp_sdk_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      navigatorKey: navigatorKey,
      onGenerateRoute: (settings) {
        // Định nghĩa routing cho app
        if (settings.name == '/product') {
          return MaterialPageRoute(builder: (_) => ProductScreen());
        }
        return MaterialPageRoute(builder: (_) => HomeScreen());
      },
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ CHỈ CẦN 1 DÒNG NÀY — SDK lo tất cả!
    MMPSdk.enableAutoPopup(navigatorKey);
  }
}
```

**SDK tự động:**
- 📱 Navigate tới `targetScreen` (ví dụ: `/product`, `/super-sale`)
- 🎯 Hiện popup attribution (Source, Campaign, Slug, Referral Code)
- ❄️ Cold start: Buffer link → replay khi widget sẵn sàng
- 🔥 Warm start: Lifecycle observer → re-check link khi app resumed
- ⚡ Hot start: Stream listener → xử lý real-time

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
*Lưu ý: Dữ liệu được lưu an toàn trong SharedPreferences. Ngay cả khi người dùng bực mình tắt hẳn App (Force Quit) ở màn hình Login, thì ngày hôm sau họ mở lại App rồi Login, màn hình đích (targetScreen) vẫn sẽ bung ra như chưa hề có cuộc chia ly!*

---

### Cách 3: Manual Callback (Tùy chỉnh cao)

Nếu muốn tự xử lý logic:

```dart
MMPSdk.onDeepLinkReceived((MMPDeeplinkData data) {
  print('Nguồn: ${data.utmSource}');
  print('Chiến dịch: ${data.utmCampaign}');
  print('Màn hình: ${data.targetScreen}');
  print('Referral: ${data.referralCode}');

  // Tự hiện popup nếu muốn
  MMPAttributionPopup.show(context, data);

  // Tự điều hướng
  if (data.targetScreen != null) {
    navigatorKey.currentState?.pushNamed(
      data.targetScreen!,
      arguments: data.queryParams,
    );
  }
});
```

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
