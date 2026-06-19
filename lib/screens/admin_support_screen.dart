// lib/screens/admin/admin_support_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/token_service.dart';
import '../../theme/app_theme.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String _filter = 'all';
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _loadTickets();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        final tickets = await ApiService.getAdminTickets(token);
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      print('Error loading tickets: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text('Failed to load tickets'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  List<dynamic> get _filteredTickets {
    if (_filter == 'all') return _tickets;
    return _tickets.where((t) => t['status'] == _filter).toList();
  }

  int _getStatusCount(String status) {
    if (status == 'all') return _tickets.length;
    return _tickets.where((t) => t['status'] == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111318) : const Color(0xFFF7F8FA);
    final cardColor = isDark ? const Color(0xFF1C1F26) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Support',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.3),
            ),
            Text(
              '${_tickets.length} ticket${_tickets.length == 1 ? '' : 's'} total',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.4)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadTickets,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.sageGreen.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            color: AppColors.sageGreen,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // ── Summary strip ────────────────────────────────────────────────
          if (!_isLoading && _tickets.isNotEmpty)
            _SummaryStrip(
              tickets: _tickets,
              getStatusCount: _getStatusCount,
            ),

          // ── Filter bar ───────────────────────────────────────────────────
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterPill(
                      label: 'All',
                      value: 'all',
                      count: _getStatusCount('all'),
                      selected: _filter == 'all',
                      color: AppColors.sageGreen,
                      onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterPill(
                      label: 'Open',
                      value: 'open',
                      count: _getStatusCount('open'),
                      selected: _filter == 'open',
                      color: Colors.orange,
                      onTap: () => setState(() => _filter = 'open')),
                  const SizedBox(width: 8),
                  _FilterPill(
                      label: 'In Progress',
                      value: 'in_progress',
                      count: _getStatusCount('in_progress'),
                      selected: _filter == 'in_progress',
                      color: Colors.blue,
                      onTap: () => setState(() => _filter = 'in_progress')),
                  const SizedBox(width: 8),
                  _FilterPill(
                      label: 'Resolved',
                      value: 'resolved',
                      count: _getStatusCount('resolved'),
                      selected: _filter == 'resolved',
                      color: Colors.green,
                      onTap: () => setState(() => _filter = 'resolved')),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.4)),

          // ── Ticket list ──────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
                      strokeWidth: 2.5,
                    ),
                  )
                : _filteredTickets.isEmpty
                    ? _EmptyTickets(filter: _filter)
                    : FadeTransition(
                        opacity: _fadeCtrl,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: _filteredTickets.length,
                          itemBuilder: (context, index) {
                            final ticket = _filteredTickets[index];
                            return _TicketCard(
                              ticket: ticket,
                              onTap: () => _openTicketDetail(ticket),
                              onStatusChanged: _loadTickets,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTicketDetail(dynamic ticket) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _TicketDetailScreen(ticket: ticket, onReply: _loadTickets),
      ),
    );
    if (result == true) _loadTickets();
  }
}

// ── Summary Strip ────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final List<dynamic> tickets;
  final int Function(String) getStatusCount;

  const _SummaryStrip({required this.tickets, required this.getStatusCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _SummaryChip(count: getStatusCount('open'), label: 'Open', color: Colors.orange),
          const SizedBox(width: 12),
          _SummaryChip(count: getStatusCount('in_progress'), label: 'In Progress', color: Colors.blue),
          const SizedBox(width: 12),
          _SummaryChip(count: getStatusCount('resolved'), label: 'Resolved', color: Colors.green),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _SummaryChip({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Pill ───────────────────────────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  final String label;
  final String value;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.value,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.15) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ticket Card ───────────────────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final dynamic ticket;
  final VoidCallback onTap;
  final VoidCallback onStatusChanged;

  const _TicketCard({
    required this.ticket,
    required this.onTap,
    required this.onStatusChanged,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'open': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'resolved': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open': return 'Open';
      case 'in_progress': return 'In Progress';
      case 'resolved': return 'Resolved';
      default: return status;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1F26) : Colors.white;
    final status = ticket['status'] as String? ?? 'open';
    final color = _statusColor(status);
    final createdAt = DateTime.parse(ticket['created_at']);
    final hasReply = ticket['admin_reply'] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.sageGreen.withOpacity(0.05),
          highlightColor: AppColors.sageGreen.withOpacity(0.03),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: status == 'open'
                    ? color.withOpacity(0.25)
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status accent line
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket['subject'] ?? '',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(label: _statusLabel(status), color: color),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // From user
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.sageGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (ticket['user_name'] as String? ?? '?')
                                    .isNotEmpty
                                    ? (ticket['user_name'] as String)
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sageGreen,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ticket['user_name']}  ·  ${ticket['user_email']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Message preview
                      Text(
                        ticket['message'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Footer
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            _timeAgo(createdAt),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                          const Spacer(),
                          if (hasReply)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.sageGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.reply_rounded,
                                      size: 11, color: AppColors.sageGreen),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Replied',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.sageGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: Colors.grey.shade400),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyTickets extends StatelessWidget {
  final String filter;
  const _EmptyTickets({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.sageGreen.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 48,
              color: AppColors.sageGreen.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filter == 'all' ? 'No tickets yet' : 'No ${filter.replaceAll('_', ' ')} tickets',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filter == 'all'
                ? 'All support tickets will appear here.'
                : 'Check other filters to see more.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Ticket Detail Screen ──────────────────────────────────────────────────────
class _TicketDetailScreen extends StatefulWidget {
  final dynamic ticket;
  final VoidCallback onReply;

  const _TicketDetailScreen({required this.ticket, required this.onReply});

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  final _replyController = TextEditingController();
  bool _isReplying = false;
  String _selectedStatus = 'open';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.ticket['status'];
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'resolved': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111318) : const Color(0xFFF7F8FA);
    final cardColor = isDark ? const Color(0xFF1C1F26) : Colors.white;
    final createdAt = DateTime.parse(widget.ticket['created_at']);
    final updatedAt = DateTime.parse(widget.ticket['updated_at']);
    final statusColor = _statusColor(_selectedStatus);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ticket Detail',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.4)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main ticket card ───────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status stripe
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject + status dropdown
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.ticket['subject'] ?? '',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusDropdown(
                              value: _selectedStatus,
                              color: statusColor,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedStatus = val);
                                  _updateStatus(val);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: theme.dividerColor.withOpacity(0.4)),
                        const SizedBox(height: 12),

                        // Meta info
                        _InfoRow(label: 'From', value: widget.ticket['user_name']),
                        _InfoRow(label: 'Email', value: widget.ticket['user_email']),
                        _InfoRow(label: 'Created', value: _formatDate(createdAt)),
                        if (widget.ticket['admin_reply'] != null)
                          _InfoRow(label: 'Replied', value: _formatDate(updatedAt)),

                        const SizedBox(height: 16),

                        // Message
                        _SectionLabel(label: 'Message'),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: theme.dividerColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            widget.ticket['message'] ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.6),
                          ),
                        ),

                        // Admin reply (if any)
                        if (widget.ticket['admin_reply'] != null) ...[
                          const SizedBox(height: 20),
                          _SectionLabel(label: 'Your Reply'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.sageGreen.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.sageGreen.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.admin_panel_settings_rounded,
                                    size: 16,
                                    color: AppColors.sageGreen.withOpacity(0.7)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.ticket['admin_reply'],
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Reply card ─────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply_rounded,
                          color: AppColors.sageGreen, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Send Reply',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _replyController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your reply to the user…',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.sageGreen, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isReplying ? null : _sendReply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sageGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isReplying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Send Reply',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.updateTicketStatus(token, widget.ticket['id'], status);
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;
    setState(() => _isReplying = true);
    try {
      final token = await TokenService.getToken();
      if (token != null) {
        await ApiService.replyToTicket(
          token,
          widget.ticket['id'],
          _replyController.text.trim(),
          _selectedStatus,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Reply sent'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          widget.onReply();
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }
}

// ── Status Dropdown ───────────────────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  final String value;
  final Color color;
  final ValueChanged<String?> onChanged;

  const _StatusDropdown({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        isDense: true,
        icon: Icon(Icons.expand_more_rounded, size: 16, color: color),
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color),
        dropdownColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C1F26)
            : Colors.white,
        items: const [
          DropdownMenuItem(value: 'open', child: Text('Open')),
          DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
          DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    );
  }
}