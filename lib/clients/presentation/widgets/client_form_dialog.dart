import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../app/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/client_repository.dart';
import '../../domain/models/client_model.dart';

/// Modal dialog elegante e completo para cadastro rápido de novos clientes
class ClientFormDialog extends StatefulWidget {
  final ClientModel? client;
  final ValueChanged<ClientModel> onClientSaved;

  const ClientFormDialog({
    super.key,
    this.client,
    required this.onClientSaved,
  });

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  late final ClientRepository _repo;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _documentCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();

  // Endereço
  final _zipCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _numberFocus = FocusNode();

  ClientType _type = ClientType.person;
  ClientStatus _status = ClientStatus.active;
  bool _isLoading = false;
  bool _isCepLoading = false;
  String? _errorMessage;
  String? _cepError;
  bool _addressLocked = false;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ClientRepository>();
    } catch (_) {
      _repo = ClientRepository();
    }

    if (_isEditing) {
      final c = widget.client!;
      _nameCtrl.text = c.name;
      _emailCtrl.text = c.email;
      _phoneCtrl.text = c.phone ?? '';
      _documentCtrl.text = c.document ?? '';
      _companyCtrl.text = c.company ?? '';
      _zipCtrl.text = c.zipCode ?? '';
      _streetCtrl.text = c.street ?? '';
      _numberCtrl.text = c.addressNumber ?? '';
      _complementCtrl.text = c.complement ?? '';
      _neighborhoodCtrl.text = c.neighborhood ?? '';
      _cityCtrl.text = c.city ?? '';
      _stateCtrl.text = c.state ?? '';
      _notesCtrl.text = c.notes ?? '';
      _type = c.type;
      _status = c.status;
      if (c.street != null && c.street!.isNotEmpty) {
        _addressLocked = true;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _documentCtrl.dispose();
    _companyCtrl.dispose();
    _zipCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _complementCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _notesCtrl.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  // ── Busca ViaCEP ───────────────────────────────────────────────────────────
  Future<void> _searchCep(String rawCep) async {
    final cep = rawCep.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;

    setState(() {
      _isCepLoading = true;
      _cepError = null;
    });

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(uri);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data.containsKey('erro') && data['erro'] == true) {
          setState(() {
            _isCepLoading = false;
            _cepError = 'CEP não encontrado.';
          });
          return;
        }

        setState(() {
          _isCepLoading = false;
          _streetCtrl.text = data['logradouro'] as String? ?? '';
          _neighborhoodCtrl.text = data['bairro'] as String? ?? '';
          _cityCtrl.text = data['localidade'] as String? ?? '';
          _stateCtrl.text = data['uf'] as String? ?? '';
          final comp = data['complemento'] as String? ?? '';
          if (comp.isNotEmpty && _complementCtrl.text.isEmpty) {
            _complementCtrl.text = comp;
          }
          _addressLocked = true;
          _cepError = null;
        });

        _numberFocus.requestFocus();
      } else {
        setState(() {
          _isCepLoading = false;
          _cepError = 'Erro ao consultar CEP.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCepLoading = false;
        _cepError = 'Sem conexão para buscar CEP.';
      });
    }
  }

  void _unlockAddress() {
    setState(() {
      _addressLocked = false;
    });
  }

  // ── Salvar Cliente ─────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Informe o nome do cliente.');
      return;
    }

    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _errorMessage = 'Informe um e-mail válido.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

    try {
      ClientModel savedClient;
      if (_isEditing) {
        savedClient = widget.client!.copyWith(
          name: name,
          email: email,
          phone: n(_phoneCtrl.text),
          document: n(_documentCtrl.text),
          type: _type,
          status: _status,
          company: n(_companyCtrl.text),
          zipCode: n(_zipCtrl.text),
          street: n(_streetCtrl.text),
          addressNumber: n(_numberCtrl.text),
          complement: n(_complementCtrl.text),
          neighborhood: n(_neighborhoodCtrl.text),
          city: n(_cityCtrl.text),
          state: n(_stateCtrl.text),
          notes: n(_notesCtrl.text),
          updatedAt: DateTime.now(),
        );
        await _repo.updateClient(savedClient);
      } else {
        AuthRepository auth;
        try {
          auth = Modular.get<AuthRepository>();
        } catch (_) {
          auth = AuthRepository();
        }
        final companyId = await auth.getCurrentCompanyId();

        savedClient = await _repo.createClient(
          name: name,
          email: email,
          phone: n(_phoneCtrl.text),
          document: n(_documentCtrl.text),
          type: _type,
          company: n(_companyCtrl.text),
          zipCode: n(_zipCtrl.text),
          street: n(_streetCtrl.text),
          addressNumber: n(_numberCtrl.text),
          complement: n(_complementCtrl.text),
          neighborhood: n(_neighborhoodCtrl.text),
          city: n(_cityCtrl.text),
          state: n(_stateCtrl.text),
          notes: n(_notesCtrl.text),
          companyId: companyId,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onClientSaved(savedClient);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Erro ao salvar: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header do Diálogo ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Editar Cliente' : 'Novo Cliente',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Cadastre os dados de contato e endereço para vincular à proposta',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── Corpo com Rolagem ─────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF991B1B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Tipo de Pessoa (PF / PJ) ───────────────────────────
                      _fieldLabel('Tipo de Cliente *'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _typeRadio(
                              type: ClientType.person,
                              label: 'Pessoa Física (CPF)',
                              icon: Icons.person_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _typeRadio(
                              type: ClientType.company,
                              label: 'Pessoa Jurídica (CNPJ)',
                              icon: Icons.business_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Nome e Documento ──────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel(_type == ClientType.company ? 'Razão Social / Nome da Empresa *' : 'Nome Completo *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    hintText: _type == ClientType.company ? 'Ex: Supermercados Estrela Ltda' : 'Ex: Carlos Eduardo Silva',
                                    prefixIcon: Icon(_type == ClientType.company ? Icons.business_outlined : Icons.person_outline, color: const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel(_type == ClientType.company ? 'CNPJ' : 'CPF'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _documentCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: _type == ClientType.company ? '00.000.000/0001-00' : '000.000.000-00',
                                    prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── E-mail e Telefone / WhatsApp ──────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('E-mail *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    hintText: 'contato@email.com',
                                    prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Telefone / WhatsApp'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    hintText: '(11) 98765-4321',
                                    prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Empresa / Nome Fantasia (se PJ ou adicional) ───────
                      if (_type == ClientType.company) ...[
                        _fieldLabel('Nome Fantasia'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _companyCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Ex: Estrela Supermercados',
                            prefixIcon: Icon(Icons.storefront_outlined, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Seção Endereço com ViaCEP ─────────────────────────
                      const Divider(color: AppColors.divider, height: 28),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Endereço (Auto ViaCEP)',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1E293B)),
                          ),
                          if (_addressLocked) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _unlockAddress,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.lock_open_rounded, size: 12, color: Color(0xFF6366F1)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Editar campos',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),

                      // CEP e Número
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('CEP (8 dígitos)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _zipCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 9,
                                  onChanged: (v) {
                                    if (v.replaceAll(RegExp(r'\D'), '').length == 8) {
                                      _searchCep(v);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: '00000-000',
                                    counterText: '',
                                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                                    suffixIcon: _isCepLoading
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                if (_cepError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _cepError!,
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFDC2626)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Número'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _numberCtrl,
                                  focusNode: _numberFocus,
                                  decoration: const InputDecoration(
                                    hintText: '123',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Logradouro / Rua
                      _fieldLabel('Logradouro / Rua'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _streetCtrl,
                        readOnly: _addressLocked,
                        decoration: InputDecoration(
                          hintText: 'Av. Paulista, Rua das Flores...',
                          fillColor: _addressLocked ? const Color(0xFFF1F5F9) : null,
                          filled: _addressLocked,
                          prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Bairro, Cidade e UF
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Bairro'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _neighborhoodCtrl,
                                  readOnly: _addressLocked,
                                  decoration: InputDecoration(
                                    hintText: 'Centro',
                                    fillColor: _addressLocked ? const Color(0xFFF1F5F9) : null,
                                    filled: _addressLocked,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Cidade'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cityCtrl,
                                  readOnly: _addressLocked,
                                  decoration: InputDecoration(
                                    hintText: 'São Paulo',
                                    fillColor: _addressLocked ? const Color(0xFFF1F5F9) : null,
                                    filled: _addressLocked,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('UF'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _stateCtrl,
                                  readOnly: _addressLocked,
                                  textCapitalization: TextCapitalization.characters,
                                  maxLength: 2,
                                  decoration: InputDecoration(
                                    hintText: 'SP',
                                    counterText: '',
                                    fillColor: _addressLocked ? const Color(0xFFF1F5F9) : null,
                                    filled: _addressLocked,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Rodapé de Ações ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CANCELAR',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _submit,
                        borderRadius: BorderRadius.circular(10),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isEditing ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR E SELECIONAR',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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

  Widget _typeRadio({
    required ClientType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
              size: 18,
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
    );
  }
}
