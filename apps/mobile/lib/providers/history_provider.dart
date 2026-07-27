import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/transfer_history.dart';

const String _kHistoryStorageKey = 'swiftbeam_transfer_history_v1';

class HistoryNotifier extends StateNotifier<List<TransferHistoryRecord>> {
  HistoryNotifier() : super([]) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_kHistoryStorageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final records = jsonList
            .map((item) =>
                TransferHistoryRecord.fromMap(item as Map<String, dynamic>))
            .toList();
        state = records;
      }
    } catch (e) {
      debugPrint("Failed to load history from storage: $e");
    }
  }

  Future<void> _saveToStorage(List<TransferHistoryRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = records.map((r) => r.toMap()).toList();
      await prefs.setString(_kHistoryStorageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Failed to save history to storage: $e");
    }
  }

  Future<void> addRecord(TransferHistoryRecord record) async {
    // Avoid duplicate insertions for the same transfer ID
    final existingIndex = state.indexWhere((r) => r.id == record.id);
    List<TransferHistoryRecord> updated;

    if (existingIndex >= 0) {
      updated = [...state];
      updated[existingIndex] = record;
    } else {
      updated = [record, ...state];
    }

    state = updated;
    await _saveToStorage(updated);
  }

  Future<void> removeRecord(String id) async {
    final updated = state.where((r) => r.id != id).toList();
    state = updated;
    await _saveToStorage(updated);
  }

  Future<void> clearHistory() async {
    state = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kHistoryStorageKey);
    } catch (e) {
      debugPrint("Failed to clear history storage: $e");
    }
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<TransferHistoryRecord>>((ref) {
  return HistoryNotifier();
});
