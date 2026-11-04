import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pinKey = 'daybook_pin_hash';
const _enabledKey = 'daybook_pin_on';

class AppLock {
  static bool unlockedThisSession = false;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) == true && (prefs.getString(_pinKey)?.isNotEmpty ?? false);
  }

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey)?.isNotEmpty ?? false;
  }

  static String _hash(String pin) => sha256.convert(utf8.encode('wendo-daybook|$pin')).toString();

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, _hash(pin));
    await prefs.setBool(_enabledKey, true);
    unlockedThisSession = true;
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_enabledKey, false);
    unlockedThisSession = true;
  }

  static Future<bool> unlock(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_pinKey);
    if (saved == null || saved.isEmpty) return true;
    final ok = saved == _hash(pin);
    if (ok) unlockedThisSession = true;
    return ok;
  }

  static void lockSession() {
    unlockedThisSession = false;
  }
}

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, required this.onUnlocked, this.setup = false});

  final VoidCallback onUnlocked;
  final bool setup;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  String? _first;
  String? _error;

  Future<void> _tap(String digit) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length < 4) return;
    if (widget.setup) {
      if (_first == null) {
        setState(() {
          _first = _pin;
          _pin = '';
        });
        return;
      }
      if (_first != _pin) {
        setState(() {
          _error = 'The numbers did not match. Try again.';
          _first = null;
          _pin = '';
        });
        return;
      }
      await AppLock.setPin(_pin);
      widget.onUnlocked();
      return;
    }
    final ok = await AppLock.unlock(_pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'Wrong PIN.';
        _pin = '';
      });
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.setup
        ? (_first == null ? 'Choose a 4-digit PIN' : 'Enter the PIN again')
        : 'Enter your PIN';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.lock_outline, size: 42, color: Color(0xFF9C1B4E)),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1C1917))),
              const SizedBox(height: 8),
              const Text(
                'Keeps this app private if someone opens your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF44403C), height: 1.35),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? const Color(0xFFE72570) : const Color(0xFFE7DCCB),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Color(0xFF9C1B4E))),
              ],
              const Spacer(),
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', '⌫'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final key in row)
                        SizedBox(
                          width: 76,
                          height: 56,
                          child: key.isEmpty
                              ? const SizedBox.shrink()
                              : TextButton(
                                  onPressed: () => key == '⌫' ? _backspace() : _tap(key),
                                  child: Text(key, style: const TextStyle(fontSize: 26, color: Color(0xFF1C1917))),
                                ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
