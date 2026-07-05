# core_network

A secure, modular, and type-safe networking abstraction package for Flutter. This package supports both `http` and `dio` client backends transparently via a clean architecture interface wrapper, shielding features from direct dependencies on underlying HTTP libraries.

---

## 1. Features
* **Dual Implementations**: Full HTTP communication via standard `http` or custom `dio` clients.
* **Interface Abstraction**: Clean decoupling of domains from concrete implementations.
* **Zero Naked `dynamic` Types**: Strongly-typed payload declarations via `NetworkRequestPayload`.
* **Multipart Request Support**: Clean abstraction for fields and file lists upload.
* **Progress Tracking**: Hooks for tracking upload/download progress.
* **Connection Tracking**: Transparent checking of internet connection states via `ConnectionTracker` before requests are sent.
* **Silent Exception Handling**: Custom set-type exception parameters to classify silent errors.

---

## 2. Setup & Installation

Add `core_network` path dependency inside your project's `pubspec.yaml`:

```yaml
dependencies:
  core_network:
    path: packages/core_network
```

---

## 3. Usage Examples

### 3.1 Initializing Client via Service Locator

Register the client of your choice in your Dependency Injection (DI) registry using the `CoreNetwork` entry point:

```dart
import 'package:core_network/core_network.dart';

void setupDependencies() {
  // Using Dio client:
  getIt.registerLazySingleton<NetworkClient>(
    () => CoreNetwork.dio(
      baseUrl: 'https://api.example.com',
      defaultApiVersion: 'v1', // Configures default API version path
      defaultSilentExceptions: {NoInternetException}, // Set default silent exceptions
      interceptors: [
        ConnectionInterceptor(
          getIt<ConnectionTracker>(),
          message: 'Offline mode is active', // Customize display message
        ),
        AuthInterceptor(getIt<TokenProvider>()),
        const DefaultHeadersInterceptor(),
        const LoggingInterceptor(),
      ],
    ),
  );

  // Or switch easily to standard http client:
  // getIt.registerLazySingleton<NetworkClient>(
  //   () => CoreNetwork.http(
  //     baseUrl: 'https://api.example.com',
  //     defaultApiVersion: 'v1',
  //     defaultSilentExceptions: {NoInternetException},
  //     interceptors: [
  //       ConnectionInterceptor(getIt<ConnectionTracker>()),
  //       AuthInterceptor(getIt<TokenProvider>()),
  //       const DefaultHeadersInterceptor(),
  //       const LoggingInterceptor(),
  //     ],
  //   ),
  // );
}
```

---

### 3.2 Defining Request Payloads

To make requests, declare payloads implementing the `NetworkRequestPayload` interface:

```dart
import 'package:core_network/core_network.dart';

class UserLoginPayload implements NetworkRequestPayload {
  final String username;
  final String password;

  const UserLoginPayload({required this.username, required this.password});

  @override
  Map<String, dynamic> toBody() {
    return {
      'username': username,
      'password': password,
    };
  }
}
```

---

### 3.3 Executing Requests

```dart
final client = getIt<NetworkClient>();

try {
  final response = await client.post<Map<String, dynamic>>(
    '/auth/login',
    data: UserLoginPayload(username: 'test', password: '123'),
  );
  print('Logged in successfully: $response');
} on UnauthorizedException catch (e) {
  print('Authentication failed: ${e.message}');
} on NoInternetException {
  print('Please check your network settings.');
}
```

---

### 3.4 Multipart File Upload with Progress

```dart
final profilePicFile = NetworkFile(
  bytes: fileBytes,
  filename: 'profile.jpg',
  contentType: 'image/jpeg',
);

final payload = MultipartPayload(
  fields: {'userId': '42'},
  files: {
    'profile_picture': [profilePicFile],
  },
);

final response = await client.post<Map<String, dynamic>>(
  '/user/upload-profile',
  data: payload,
  onSendProgress: (sentBytes, totalBytes) {
    final progress = (sentBytes / totalBytes) * 100;
    print('Uploaded: ${progress.toStringAsFixed(1)}%');
  },
);
```

---

### 3.5 Handling Silent Exceptions

If you want to suppress UI error alerts for specific non-critical network calls (like background analytics or pre-fetching non-essential data), pass the exception types in the `silentExceptions` set:

```dart
try {
  final response = await client.get<Map<String, dynamic>>(
    '/user/notifications',
    silentExceptions: {UnauthorizedException, ServerException},
  );
} on NetworkException catch (e) {
  if (e.isSilent) {
    // Log silently without raising error popups or banners to the user
    logger.fine('Fetch notifications failed silently: ${e.message}');
  } else {
    // Show error banner to the user
    showErrorBanner(e.message);
  }
}
```

---

### 3.6 API Versioning & Custom URLs

#### Dynamic API Versioning
You can override the default API version path of a request:
```dart
// Sends GET request to https://api.example.com/v2/users
final response = await client.get<List<dynamic>>(
  '/users',
  apiVersion: 'v2',
);
```

#### Custom Fully-Qualified URLs
If you want to make a request to a third-party or custom external service, pass the full HTTP/HTTPS URL. The client will automatically bypass the `baseUrl` and `apiVersion` formatting:
```dart
// Bypasses local base URL and versioning paths
final response = await client.get<Map<String, dynamic>>(
  'https://some-other-service.com/api/v1/weather',
);
```

#### Developer Fail-Fast Assertions
In development (debug mode), the client enforces assertions on initialization parameters and request paths:
* Paths must start with a slash `/` (to prevent double-slash errors) unless passing a fully qualified HTTP/HTTPS URL.
* `baseUrl` must start with `http://` or `https://` and must not end with a trailing slash.
* `MultipartPayload` must contain at least one field or file list.
* Assertions will crash the app immediately in debug mode to keep development error-free.
