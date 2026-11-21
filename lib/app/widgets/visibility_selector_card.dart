import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/domain/models/user_model.dart';

/// Card reutilizável para Admin e Manager definirem a visibilidade de um registro:
/// - Privado (apenas o criador)
/// - Público para toda a empresa (todos os níveis)
/// - Compartilhado com operadores / gerentes específicos
class VisibilitySelectorCard extends StatefulWidget {
  final UserModel? currentUser;
  final bool isPublicForCompany;
  final List<String> sharedWithUserIds;
  final ValueChanged<bool> onPublicChanged;
  final ValueChanged<List<String>> onSharedUsersChanged;

  const VisibilitySelectorCard({
    super.key,
    required this.currentUser,
    required this.isPublicForCompany,
    required this.sharedWithUserIds,
    required this.onPublicChanged,
    required this.onSharedUsersChanged,
  });

  @override
  State<VisibilitySelectorCard> createState() => _VisibilitySelectorCardState();
}

class _VisibilitySelectorCardState extends State<VisibilitySelectorCard> {
  List<UserModel> _teamMembers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final user = widget.currentUser;
    if (user == null || (!user.isAdmin && !user.isManager)) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final companyId = user.effectiveCompanyId;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('companyId', isEqualTo: companyId)
          .get();

      final list = snap.docs
          .map((d) => UserModel.fromMap(d.data(), d.id))
          .where((u) => u.uid != user.uid && u.isActive)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _teamMembers = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    if (user == null || (!user.isAdmin && !user.isManager)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.65)
        : const Color(0xFFF8FAFC);
    final borderColor = widget.isPublicForCompany
        ? const Color(0xFF10B981).withValues(alpha: 0.45)
        : const Color(0xFF6366F1).withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.isPublicForCompany
                    ? Icons.public_rounded
                    : Icons.lock_person_rounded,
                size: 18,
                color: widget.isPublicForCompany
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Visibilidade & Compartilhamento',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: const Color(0xFF10B981),
            value: widget.isPublicForCompany,
            onChanged: (val) => widget.onPublicChanged(val ?? false),
            title: Text(
              'Tornar público para toda a empresa (todos os níveis)',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              widget.isPublicForCompany
                  ? 'Qualquer gerente ou vendedor da empresa poderá visualizar.'
                  : 'Visível apenas para você e para os usuários marcados abaixo.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          if (!widget.isPublicForCompany) ...[
            const SizedBox(height: 6),
            Text(
              'Compartilhar com usuários específicos (opcional):',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_teamMembers.isEmpty)
              Text(
                'Nenhum outro gerente ou vendedor ativo na empresa.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _teamMembers.map((member) {
                  final selected =
                      widget.sharedWithUserIds.contains(member.uid);
                  final roleLabel = member.role.toLowerCase() == 'manager'
                      ? 'Gerente'
                      : 'Vendedor';
                  return FilterChip(
                    selected: selected,
                    label: Text(
                      '${member.name.isNotEmpty ? member.name : member.email} ($roleLabel)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    selectedColor:
                        const Color(0xFF6366F1).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF6366F1),
                    onSelected: (isSelected) {
                      final next = List<String>.from(widget.sharedWithUserIds);
                      if (isSelected) {
                        if (!next.contains(member.uid)) next.add(member.uid);
                      } else {
                        next.remove(member.uid);
                      }
                      widget.onSharedUsersChanged(next);
                    },
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }
}
