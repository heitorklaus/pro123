import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/layout/app_sidebar.dart';
import '../../../auth/domain/models/user_model.dart';

class _SearchHit {
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  final AppSidebarItem targetSection;
  final String searchBlob;

  const _SearchHit({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    required this.targetSection,
    required this.searchBlob,
  });
}

/// Modal de Busca Global Rápida Gold (Ctrl+K) — pesquisa clientes, propostas, usinas e contratos.
class GlobalSearchDialog extends StatefulWidget {
  final UserModel? currentUser;
  final ValueChanged<AppSidebarItem> onNavigate;

  const GlobalSearchDialog({
    super.key,
    required this.currentUser,
    required this.onNavigate,
  });

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final TextEditingController _ctrl = TextEditingController();
  final _brlFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  bool _loading = true;
  List<_SearchHit> _allHits = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadIndex() async {
    final user = widget.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final db = FirebaseFirestore.instance;
    final companyId = user.effectiveCompanyId;
    final isMaster = user.isSuperAdmin;
    final hits = <_SearchHit>[];

    try {
      final futures = <Future<void>>[];

      if (user.canViewClients) {
        Query<Map<String, dynamic>> q = db.collection('clients');
        if (!isMaster && companyId.isNotEmpty) {
          q = q.where('companyId', isEqualTo: companyId);
        }
        futures.add(q.limit(120).get().then((snap) {
          for (final doc in snap.docs) {
            final d = doc.data();
            if (!user.canAccessRecord(
              viewAllPermission: user.canViewAllClients,
              createdByUserId: d['createdByUserId'] as String?,
              isPublicForCompany: d['isPublicForCompany'] as bool? ?? false,
              sharedWithUserIds: List<String>.from(
                  d['sharedWithUserIds'] as List? ?? const []),
            )) {
              continue;
            }
            final name = (d['name'] ?? '').toString().trim();
            if (name.isEmpty) continue;
            final docNum = (d['document'] ?? '').toString().trim();
            final phone = (d['phone'] ?? '').toString().trim();
            final city = (d['city'] ?? '').toString().trim();
            final parts = [
              if (docNum.isNotEmpty) docNum,
              if (phone.isNotEmpty) phone,
              if (city.isNotEmpty) city,
            ];
            hits.add(_SearchHit(
              title: name,
              subtitle: parts.isEmpty ? 'Cliente cadastrado' : parts.join(' • '),
              category: 'Cliente',
              icon: Icons.person_outline_rounded,
              color: const Color(0xFF38BDF8),
              targetSection: AppSidebarItem.clients,
              searchBlob: '$name $docNum $phone $city'.toLowerCase(),
            ));
          }
        }).catchError((_) {}));
      }

      if (user.canViewProposals) {
        Query<Map<String, dynamic>> q = db.collection('proposals');
        if (!isMaster && companyId.isNotEmpty) {
          q = q.where('companyId', isEqualTo: companyId);
        }
        futures.add(q.limit(120).get().then((snap) {
          for (final doc in snap.docs) {
            final d = doc.data();
            if (!user.canAccessRecord(
              viewAllPermission: user.canViewAllProposals,
              createdByUserId: d['createdByUserId'] as String?,
              isPublicForCompany: d['isPublicForCompany'] as bool? ?? false,
              sharedWithUserIds: List<String>.from(
                  d['sharedWithUserIds'] as List? ?? const []),
            )) {
              continue;
            }
            final numStr = (d['proposalNumber'] ?? '').toString().trim();
            final client = (d['clientName'] ?? '').toString().trim();
            final total = (d['totalAmount'] as num?)?.toDouble() ?? 0;
            final title = numStr.isNotEmpty
                ? '$numStr • ${client.isEmpty ? 'Sem cliente' : client}'
                : (client.isEmpty ? 'Proposta' : client);
            hits.add(_SearchHit(
              title: title,
              subtitle:
                  '${_brlFmt.format(total)} • ${(d['status'] ?? 'draft').toString().toUpperCase()}',
              category: 'Proposta',
              icon: Icons.description_outlined,
              color: const Color(0xFF818CF8),
              targetSection: AppSidebarItem.proposals,
              searchBlob: '$numStr $client ${d['title'] ?? ''}'.toLowerCase(),
            ));
          }
        }).catchError((_) {}));
      }

      if (user.canViewProducts) {
        Query<Map<String, dynamic>> q = db.collection('products');
        if (!isMaster && companyId.isNotEmpty) {
          q = q.where('companyId', isEqualTo: companyId);
        }
        futures.add(q.limit(120).get().then((snap) {
          for (final doc in snap.docs) {
            final d = doc.data();
            if (!user.canAccessRecord(
              viewAllPermission: user.canViewAllProducts,
              createdByUserId: d['createdByUserId'] as String?,
              isPublicForCompany: d['isPublicForCompany'] as bool? ?? false,
              sharedWithUserIds: List<String>.from(
                  d['sharedWithUserIds'] as List? ?? const []),
            )) {
              continue;
            }
            final name = (d['name'] ?? '').toString().trim();
            if (name.isEmpty) continue;
            final isPlant = d['isSolarPlant'] == true;
            final kwp = (d['solarKilowatts'] as num?)?.toDouble() ?? 0;
            final price = (d['price'] as num?)?.toDouble() ?? 0;
            hits.add(_SearchHit(
              title: name,
              subtitle: isPlant && kwp > 0
                  ? '${kwp.toStringAsFixed(2)} kWp • ${_brlFmt.format(price)}'
                  : _brlFmt.format(price),
              category: isPlant ? 'Usina Solar' : 'Produto',
              icon: isPlant
                  ? Icons.solar_power_rounded
                  : Icons.inventory_2_outlined,
              color: const Color(0xFFF59E0B),
              targetSection: AppSidebarItem.products,
              searchBlob: '$name ${d['sku'] ?? ''} $kwp'.toLowerCase(),
            ));
          }
        }).catchError((_) {}));
      }

      if (user.canViewContracts) {
        Query<Map<String, dynamic>> q = db.collection('contracts');
        if (!isMaster && companyId.isNotEmpty) {
          q = q.where('companyId', isEqualTo: companyId);
        }
        futures.add(q.limit(80).get().then((snap) {
          for (final doc in snap.docs) {
            final d = doc.data();
            if (!user.canAccessRecord(
              viewAllPermission: user.canViewAllContracts,
              createdByUserId: d['createdByUserId'] as String?,
              isPublicForCompany: d['isPublicForCompany'] as bool? ?? false,
              sharedWithUserIds: List<String>.from(
                  d['sharedWithUserIds'] as List? ?? const []),
            )) {
              continue;
            }
            final cNum = (d['contractNumber'] ?? '').toString().trim();
            final client = (d['clientName'] ?? '').toString().trim();
            final title = cNum.isNotEmpty
                ? '$cNum • ${client.isEmpty ? 'Cliente' : client}'
                : (client.isEmpty ? 'Contrato' : client);
            hits.add(_SearchHit(
              title: title,
              subtitle: 'Contrato jurídico',
              category: 'Contrato',
              icon: Icons.gavel_rounded,
              color: const Color(0xFF10B981),
              targetSection: AppSidebarItem.contracts,
              searchBlob: '$cNum $client'.toLowerCase(),
            ));
          }
        }).catchError((_) {}));
      }

      await Future.wait(futures);
    } finally {
      if (mounted) {
        setState(() {
          _allHits = hits;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _allHits.take(15).toList()
        : _allHits.where((h) => h.searchBlob.contains(q)).take(25).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: SizedBox(
        width: 580,
        height: 480,
        child: Column(
          children: [
            // Campo de busca Gold
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    const Color(0xFF0F172A).withValues(alpha: isDark ? 0.9 : 0.04),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Buscar cliente, proposta, usina ou contrato...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GOLD • CTRL+K',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 19),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF59E0B),
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            q.isEmpty
                                ? 'Nenhum registro encontrado.'
                                : 'Nenhum resultado para "$_query".',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(10),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final hit = filtered[index];
                            return ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: hit.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(hit.icon,
                                    color: hit.color, size: 18),
                              ),
                              title: Text(
                                hit.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                hit.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 11.5),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hit.color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hit.category,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: hit.color,
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onNavigate(hit.targetSection);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
