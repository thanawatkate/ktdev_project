import 'package:dio/dio.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:sqflite/sqflite.dart';

String toUserErrorMessage(
  Object error, {
  String fallback = TransactionUiText.genericTryAgain,
}) {
  final message = error.toString();
  if (message.contains('SqfliteFfiWebException') ||
      message.contains('SqfliteFfiWebWorkerException')) {
    return TransactionUiText.sqfliteWebSetupRequired;
  }

  if (error is DatabaseException) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('foreign key constraint') ||
        raw.contains('fk constraint') ||
        (raw.contains('constraint') && raw.contains('foreign'))) {
      return TransactionUiText.sqliteForeignKeyBlocked;
    }
    if (raw.contains('unique constraint')) {
      return TransactionUiText.sqliteUniqueConstraint;
    }
    if (raw.contains('readonly') || raw.contains('read-only')) {
      return TransactionUiText.sqliteReadOnlyDb;
    }
    if (raw.contains('locked') ||
        raw.contains('busy') ||
        raw.contains('sqlite_busy') ||
        raw.contains('cannot open')) {
      return TransactionUiText.sqliteDatabaseLocked;
    }
    if (raw.contains('disk i/o') || raw.contains('full disk')) {
      return TransactionUiText.sqliteDiskIo;
    }
    if (raw.contains('no such column') ||
        raw.contains('no such table') ||
        raw.contains('has no column named')) {
      return TransactionUiText.sqliteSchemaOutdated;
    }

    return TransactionUiText.genericTryAgain;
  }

  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
    } else if (data is String && data.trim().isNotEmpty) {
      final trimmed = data.trim().toLowerCase();
      if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
        // server returned an HTML error page — fall through to status-code handling
      } else {
        return data;
      }
    }

    if (statusCode == 500) return TransactionUiText.temporarySystemIssue;
    if (statusCode == 404) return TransactionUiText.requestedDataNotFound;
    if (statusCode == 401 || statusCode == 403) {
      return TransactionUiText.noPermissionData;
    }
    if (statusCode == 400) return TransactionUiText.invalidDataPleaseCheck;
    if (statusCode == 408) return TransactionUiText.connectionTimeout;

    return TransactionUiText.cannotConnectServer;
  }

  return fallback;
}
