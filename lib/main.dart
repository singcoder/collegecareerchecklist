import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'College & Career Checklist',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const AuthGate(),
    );
  }
}

/// Shows either the sign-in screen or the checklist depending on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data?.session;
        if (session == null) {
          return const EmailCodeSignInScreen();
        }
        return const ChecklistScreen();
      },
    );
  }
}

/// Email-only sign-in: enter email → we send a code → they enter code → signed in.
class EmailCodeSignInScreen extends StatefulWidget {
  const EmailCodeSignInScreen({super.key});

  @override
  State<EmailCodeSignInScreen> createState() => _EmailCodeSignInScreenState();
}

const String _savedLoginEmailKey = 'saved_login_email';

class _EmailCodeSignInScreenState extends State<EmailCodeSignInScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _pendingEmail;
  bool _codeSent = false;
  DateTime? _resendAvailableAfter;
  Timer? _resendCooldownTimer;
  static const int _resendCooldownSeconds = 90;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _clearVerificationState() {
    _resendCooldownTimer?.cancel();
    _resendCooldownTimer = null;
    setState(() {
      _pendingEmail = null;
      _codeSent = false;
      _resendAvailableAfter = null;
      _codeController.clear();
      _error = null;
    });
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedLoginEmailKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _emailController.text = saved);
    }
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedLoginEmailKey, email);
  }

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _sendVerificationCode() async {
    final email = (_pendingEmail ?? _emailController.text.trim()).trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: email);
      if (mounted) {
        _resendCooldownTimer?.cancel();
        _resendAvailableAfter = DateTime.now().add(const Duration(seconds: _resendCooldownSeconds));
        _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          if (DateTime.now().isAfter(_resendAvailableAfter!)) {
            _resendCooldownTimer?.cancel();
            _resendCooldownTimer = null;
            setState(() => _resendAvailableAfter = null);
            return;
          }
          setState(() {});
        });
        setState(() {
          _pendingEmail = email;
          _codeSent = true;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        final msg = e.message ?? 'Failed to send code';
        final isRateLimit = msg.toLowerCase().contains('limit') ||
            msg.toLowerCase().contains('rate') ||
            msg.toLowerCase().contains('too many');
        setState(() {
          _error = isRateLimit
              ? 'Email limit reached. Supabase limits how often codes can be sent. Please try again in 30–60 minutes.'
              : msg;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _error = 'Failed to send code: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyCodeAndSignIn() async {
    final email = _pendingEmail;
    final code = _codeController.text.trim();
    if (email == null || code.isEmpty) {
      setState(() => _error = 'Enter the verification code');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: code,
      );
      await _saveEmail(email);
      _clearVerificationState();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Invalid or expired code. Request a new one.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCodeStep = _codeSent;

    return Scaffold(
      appBar: AppBar(
        title: Text(showCodeStep ? 'Verify email' : 'Sign in'),
        leading: showCodeStep
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isLoading ? null : _clearVerificationState,
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!showCodeStep) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendVerificationCode,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send verification code'),
              ),
            ] else ...[
              Text(
                'Enter the verification code we sent to $_pendingEmail',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Emails can take 1–2 minutes. Check spam. Resend is available after the countdown.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  hintText: '00000000',
                ),
                keyboardType: TextInputType.number,
                maxLength: 8,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyCodeAndSignIn,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify and sign in'),
              ),
              const SizedBox(height: 16),
              Text(
                "Didn't get the email? Check spam or resend the code.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _isLoading || (_resendAvailableAfter != null && DateTime.now().isBefore(_resendAvailableAfter!))
                    ? null
                    : _sendVerificationCode,
                child: Text(
                  _resendAvailableAfter != null && DateTime.now().isBefore(_resendAvailableAfter!)
                      ? 'Resend code (in ${_resendAvailableAfter!.difference(DateTime.now()).inSeconds}s)'
                      : 'Resend code',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tracks which users we've already initialized so we don't overwrite.
final Set<String> _initializedUserChecklists = {};

/// Shows the shared checklist with per-user completion and optional URLs.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  List<Map<String, dynamic>> _items = [];
  Map<String, bool> _completionMap = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final itemsRes = await client
          .from('checklist_items')
          .select()
          .eq('checklist_id', 'global')
          .order('sort_order');

      final items = List<Map<String, dynamic>>.from(itemsRes as List);
      items.sort((a, b) {
        final aOrder = (a['sort_order'] as num?)?.toInt() ?? 0;
        final bOrder = (b['sort_order'] as num?)?.toInt() ?? 0;
        return aOrder.compareTo(bOrder);
      });

      final ucRes = await client
          .from('user_checklist')
          .select('item_id, is_complete')
          .eq('user_id', user.id)
          .eq('checklist_id', 'global');

      final completionMap = <String, bool>{};
      for (final row in ucRes as List) {
        final map = row as Map<String, dynamic>;
        final itemId = map['item_id'] as String?;
        if (itemId != null) {
          completionMap[itemId] = map['is_complete'] == true;
        }
      }

      if (items.isNotEmpty && completionMap.isEmpty && !_initializedUserChecklists.contains(user.id)) {
        _initializedUserChecklists.add(user.id);
        await _createUserChecklistRecords(
          userId: user.id,
          checklistId: 'global',
          itemIds: items.map<String>((e) => e['id'] as String).toList(),
        );
        for (final item in items) {
          completionMap[item['id'] as String] = false;
        }
      }

      if (mounted) {
        setState(() {
          _items = items;
          _completionMap = completionMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _createUserChecklistRecords({
    required String userId,
    required String checklistId,
    required List<String> itemIds,
  }) async {
    final client = Supabase.instance.client;
    for (final itemId in itemIds) {
      final docId = '${userId}_${checklistId}_$itemId';
      await client.from('user_checklist').insert({
        'id': docId,
        'user_id': userId,
        'checklist_id': checklistId,
        'item_id': itemId,
        'is_complete': false,
        'completed_at': null,
      });
    }
  }

  Future<void> _updateCompletion({
    required String userId,
    required String checklistId,
    required String itemId,
    required bool isComplete,
  }) async {
    final docId = '${userId}_${checklistId}_$itemId';
    await Supabase.instance.client.from('user_checklist').upsert({
      'id': docId,
      'user_id': userId,
      'checklist_id': checklistId,
      'item_id': itemId,
      'is_complete': isComplete,
      'completed_at': isComplete ? DateTime.now().toIso8601String() : null,
      'created_at': DateTime.now().toIso8601String(),
    });
    setState(() {
      _completionMap[itemId] = isComplete;
    });
  }

  static Future<void> _openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final urlWithScheme = trimmed.contains(RegExp(r'^https?://', caseSensitive: false))
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(urlWithScheme);
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser!;
    final uid = user.id;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Checklist')),
        body: Center(child: Text('Error: $_error')),
      );
    }
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Checklist'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Supabase.instance.client.auth.signOut(),
              tooltip: 'Sign out',
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No checklist items. Add rows to checklist_items in Supabase.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final id = item['id'] as String;
          final title = item['title'] as String? ?? '';
          final url = item['url'] as String? ?? '';
          final isComplete = _completionMap[id] ?? false;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: Checkbox(
                value: isComplete,
                onChanged: (value) {
                  if (value == null) return;
                  _updateCompletion(
                    userId: uid,
                    checklistId: 'global',
                    itemId: id,
                    isComplete: value,
                  );
                },
              ),
              title: url.isNotEmpty
                  ? InkWell(
                      onTap: () => _openUrl(url),
                      child: Text(
                        title,
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue,
                        ),
                      ),
                    )
                  : Text(title),
            ),
          );
        },
      ),
    );
  }
}
