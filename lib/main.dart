import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/constants.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/messaging_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await initializeDateFormatting('tr_TR', null);

  runApp(const ProviderScope(child: IsTakipApp()));
}

class IsTakipApp extends ConsumerStatefulWidget {
  const IsTakipApp({super.key});

  @override
  ConsumerState<IsTakipApp> createState() => _IsTakipAppState();
}

class _IsTakipAppState extends ConsumerState<IsTakipApp> {
  String? _lastMessagingUid;

  @override
  Widget build(BuildContext context) {
    // Keep FCM token registration and foreground/tap handling in sync with
    // the signed-in user, without re-initializing on every rebuild.
    ref.listen(authStateChangesProvider, (previous, next) {
      final uid = next.valueOrNull?.uid;
      if (uid != null && uid != _lastMessagingUid) {
        _lastMessagingUid = uid;
        final router = ref.read(routerProvider);
        ref
            .read(messagingServiceProvider)
            .init(
              onTapNotification: (jobId) {
                if (jobId != null) router.push(AppRoutes.jobDetailPath(jobId));
              },
            );
        ref.read(messagingServiceProvider).syncToken(uid);
      } else if (uid == null) {
        _lastMessagingUid = null;
      }
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'İş & Tahsilat Takip',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
