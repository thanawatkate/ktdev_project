import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/di/service_locator.dart';
import 'package:saccm/core/utils/user_error_message.dart';
import 'package:saccm/features/approval/data/repositories/approval_repository.dart';
import 'package:saccm/widgets/widgets.dart';

class ApprovalLogSheet extends StatefulWidget {
  const ApprovalLogSheet({
    super.key,
    required this.refId,
    required this.docNo,
  });

  final String refId;
  final String docNo;

  @override
  State<ApprovalLogSheet> createState() => _ApprovalLogSheetState();
}

class _ApprovalLogSheetState extends State<ApprovalLogSheet> {
  bool _loading = true;
  String? _error;
  List<dynamic> _rows = const [];

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
    try {
      final repo = ServiceLocator.instance.get<ApprovalRepository>();
      _rows = await repo.fetchApprovalLog(widget.refId);
    } catch (e) {
      _error = toUserErrorMessage(e);
      _rows = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'submit':
        return TransactionUiText.approvalLogActionSubmit;
      case 'approve':
        return TransactionUiText.approvalLogActionApprove;
      case 'reject':
        return TransactionUiText.approvalLogActionReject;
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveContentSheet(
      title: '${TransactionUiText.approvalLogTitle} — ${widget.docNo}',
      child: _buildLogBody(c, scheme),
    );
  }

  Widget _buildLogBody(AppColors c, ColorScheme scheme) {
    if (_loading) {
      return SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            _error!,
            style: TextStyle(fontFamily: 'Kanit', color: c.expenseRed),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            TransactionUiText.approvalLogEmpty,
            style: TextStyle(fontFamily: 'Kanit', color: c.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp16,
        vertical: AppTheme.sp8,
      ),
      itemCount: _rows.length,
      itemBuilder: (_, i) {
        final row = Map<String, dynamic>.from(_rows[i] as Map);
        final created = row['created']?.toString();
        final when = created == null
            ? '-'
            : ThaiDateFormatter.formatDateTime(
                DateTime.tryParse(created)?.toLocal() ?? created,
              );
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _actionLabel(row['action']?.toString() ?? ''),
            style: TextStyle(
              fontFamily: 'Kanit',
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row['actor_name'] != null)
                Text(
                  row['actor_name'].toString(),
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
              if (row['note'] != null && row['note'].toString().isNotEmpty)
                Text(
                  row['note'].toString(),
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
            ],
          ),
          trailing: Text(
            when,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 11,
              color: c.textHint,
            ),
          ),
        );
      },
    );
  }
}
