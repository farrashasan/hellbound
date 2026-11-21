import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/pact.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/hellbound_repository.dart';
import 'screens/create_pact_screen.dart';
import 'theme/hellbound_theme.dart';

part 'screens/welcome_screen.dart';
part 'screens/auth_screen.dart';
part 'screens/home_screen.dart';
part 'screens/pacts_screen.dart';
part 'screens/pact_detail_screen.dart';
part 'screens/evidence_screen.dart';
part 'screens/verification_screen.dart';
part 'screens/wall_of_shame_screen.dart';
part 'screens/ban_chamber_screen.dart';
part 'screens/profile_screen.dart';
part 'widgets/hellbound_components.dart';

class Hellbound extends StatefulWidget {
  const Hellbound({super.key});
  @override
  State<Hellbound> createState() => _HellboundState();
}

class _HellboundState extends State<Hellbound> {
  String page = 'welcome', name = '', email = '', filter = 'Active';
  bool obscure = true;
  final preferences = [true, true, true];
  final username = TextEditingController(),
      mail = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      evidence = TextEditingController(),
      notes = TextEditingController();
  final authKey = GlobalKey<FormState>();
  final repository = HellboundRepository(Supabase.instance.client);
  List<Pact> pacts = [];
  List<Map<String, dynamic>> community = [], alerts = [];
  bool busy = false;
  String? loadError;
  String? loginError;
  String? loginEmailError;
  String? registrationEmailError;

  void clearRegistrationEmailError() {
    if (registrationEmailError != null) {
      setState(() => registrationEmailError = null);
    }
  }

  void clearLoginError() {
    if (loginError != null || loginEmailError != null) {
      setState(() {
        loginError = null;
        loginEmailError = null;
      });
    }
  }

  String photoMime = 'image/png';
  StreamSubscription<AuthState>? authSubscription;
  String get uid => repository.client.auth.currentUser?.id ?? '';
  void notify(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      notify(
        e is AuthException
            ? e.message
            : e is PostgrestException
            ? e.message
            : 'Operation failed. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    final sessionId = uid;
    if (sessionId.isEmpty) return;
    final failures = <String>[];
    Future<T?> read<T>(String section, Future<T> Function() request) async {
      try {
        return await request();
      } catch (error) {
        final code = error is PostgrestException ? error.code : null;
        debugPrint(
          'Hellbound load [$section]: ${error.runtimeType}${code == null ? '' : ' ($code)'}',
        );
        failures.add(section);
        return null;
      }
    }

    final profile = await read('Profile', repository.profile);
    final settings = await read('Settings', repository.settings);
    // Expiry failure must remain visible, but must not block reading existing pacts.
    await read('Deadline updates', repository.expireDue);
    final data = await read('Pacts', repository.pacts);
    final feed = await read('Wall of Shame', repository.wall);
    final notices = await read('Notifications', repository.notifications);
    if (!mounted || sessionId != uid) return;
    setState(() {
      if (profile != null) name = profile['username'];
      email = repository.client.auth.currentUser?.email ?? '';
      if (settings != null) {
        preferences[0] = settings['deadline_reminders'];
        preferences[1] = settings['pact_invitations'];
        preferences[2] = settings['verification_results'];
      }
      if (data != null) pacts = data;
      if (feed != null) community = feed;
      if (notices != null) alerts = notices;
      loadError = failures.isEmpty
          ? null
          : 'Could not refresh: ${failures.join(', ')}. Data may be out of date. Please try again.';
      if (selected != null && data != null) {
        final matches = data.where((p) => p.id == selected!.id);
        final photo = selected!.photo;
        selected = matches.isEmpty ? null : matches.first;
        selected?.photo = photo;
        if (selected == null) page = 'home';
      }
    });
  }

  Future<void> reload() => perform(load);

  Future<void> authenticate(bool register) => perform(() async {
    clearLoginError();
    clearRegistrationEmailError();
    if (!authKey.currentState!.validate()) return;
    if (register) {
      final AuthResponse response;
      try {
        response = await repository.client.auth.signUp(
          email: mail.text.trim(),
          password: password.text,
          data: {'username': username.text.trim()},
        );
      } on AuthException catch (error) {
        if (!['user_already_exists', 'email_exists'].contains(error.code) &&
            error.message.toLowerCase() != 'user already registered') {
          rethrow;
        }
        if (mounted) {
          setState(() => registrationEmailError = 'Email already registered');
        }
        return;
      }
      // With confirmation enabled, an existing confirmed account can return
      // an obfuscated user with an explicitly empty identities list.
      if (response.session == null &&
          response.user?.identities?.isEmpty == true) {
        if (mounted) {
          setState(() => registrationEmailError = 'Email already registered');
        }
        return;
      }
      if (response.session == null) {
        notify('Check your email to confirm your account, then log in.');
        go('login');
        return;
      }
    } else {
      try {
        await repository.client.auth.signInWithPassword(
          email: mail.text.trim(),
          password: password.text,
        );
      } on AuthException catch (error) {
        if (error.code == 'email_not_confirmed') {
          if (mounted) {
            setState(
              () => loginEmailError =
                  'Confirm your email first. Check your inbox or spam folder.',
            );
          }
          return;
        }
        if (error.code != 'invalid_credentials') rethrow;
        if (!mounted) return;
        setState(() => loginError = 'Invalid email or password');
        return;
      }
    }
    password.clear();
    confirm.clear();
    go('home');
    await load();
  });
  Future<void> logout() => perform(() async {
    await repository.client.auth.signOut();
  });
  Pact? selected;
  Timer? ticker;
  Uint8List? pendingPhoto;
  @override
  void initState() {
    super.initState();
    authSubscription = repository.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.session == null) {
        setState(() {
          page = 'welcome';
          pacts = [];
          selected = null;
          community = [];
          alerts = [];
          name = '';
          email = '';
          loadError = null;
          password.clear();
          confirm.clear();
        });
      }
    });
    if (uid.isNotEmpty) {
      page = 'home';
      WidgetsBinding.instance.addPostFrameCallback((_) => reload());
    }

    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ['ban', 'detail'].contains(page)) setState(() {});
    });
  }

  String remaining(DateTime until) {
    final d = until.difference(DateTime.now());
    if (d.isNegative) return '00:00:00';
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ext = file.name.toLowerCase().split('.').last;
      photoMime =
          {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'webp': 'image/webp',
          }[ext] ??
          '';
      if (photoMime.isEmpty || bytes.length > 10485760) {
        notify('Choose a PNG, JPEG or WebP under 10 MiB.');
        return;
      }
      if (mounted) setState(() => pendingPhoto = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this photo. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> acceptPact() => perform(() async {
    await repository.respond(selected!, true);
    await load();
  });
  void refresh(VoidCallback action) => setState(action);
  void go(String next) => setState(() {
    loginError = null;
    loginEmailError = null;
    registrationEmailError = null;
    page = next;
  });
  @override
  void dispose() {
    ticker?.cancel();
    authSubscription?.cancel();
    for (final c in [username, mail, password, confirm, evidence, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String date(DateTime value) =>
      '${value.day}/${value.month}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  void open(Pact pact) {
    selected = pact;
    notes.text = pact.notes;
    if (pact.photoPath != null) {
      repository
          .photo(pact.photoPath!)
          .then((bytes) {
            if (mounted && selected?.id == pact.id) {
              setState(() => selected!.photo = bytes);
            }
          })
          .catchError((Object e) {
            notify('Could not load evidence photo.');
          });
    }
    go('detail');
  }

  Future<void> updateStatus(String status) => perform(() async {
    if (status == 'Declined') {
      await repository.respond(selected!, false);
    } else if (status == 'Under Verification') {
      await repository.submit(
        selected!,
        evidence.text.trim(),
        pendingPhoto,
        photoMime,
      );
    } else if (status == 'Completed' || status == 'Breached') {
      await repository.review(selected!, status == 'Completed', notes.text);
    }
    await load();
    if (mounted) go('detail');
  });
  @override
  Widget build(BuildContext context) {
    final auth = ['welcome', 'login', 'register'].contains(page);
    final content = switch (page) {
      'welcome' => welcome(),
      'login' || 'register' => authentication(),
      'home' => home(),
      'pacts' => pactList(),
      'profile' => profile(),
      'detail' => detail(),
      'evidence' => submitEvidence(),
      'review' => review(),
      'wall' => wall(),
      'ban' => ban(),
      _ => home(),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (!['welcome', 'home', 'pacts', 'profile'].contains(page))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => go(auth ? 'welcome' : 'home'),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  if (busy) const LinearProgressIndicator(),
                  if (loadError != null) ...[
                    Text(loadError!),
                    TextButton(onPressed: reload, child: const Text('Retry')),
                  ],
                  AbsorbPointer(absorbing: busy, child: content),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: auth
          ? null
          : NavigationBar(
              selectedIndex: page == 'profile'
                  ? 2
                  : ['pacts', 'detail', 'evidence', 'review'].contains(page)
                  ? 1
                  : 0,
              onDestinationSelected: (i) => go(['home', 'pacts', 'profile'][i]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  label: 'My Pacts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }

  Future<void> create() async {
    try {
      final people = await repository.users();
      if (!mounted) return;
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePact(
            users: people,
            currentUserId: uid,
            repository: repository,
          ),
        ),
      );
      if (result != null && mounted) {
        await reload();
        final found = pacts.where((p) => p.id == result);
        if (found.isNotEmpty) open(found.first);
      }
    } catch (e) {
      notify('Could not load participants. Please try again.');
    }
  }
}
