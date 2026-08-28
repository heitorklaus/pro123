import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../app/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/services/gemini_energy_bill_service.dart';
import '../../domain/models/client_model.dart';
import '../../domain/models/parsed_energy_bill.dart';
import 'energy_bill_summary_dialog.dart';

/// Modal dialog elegante, espaçoso e com suporte a IA Gemini Vision para análise de contas de energia
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

  // ── Controllers de Dados Básicos ─────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _documentCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();

  // ── Controllers de Energia & UC ──────────────────────────────────────────
  final _ucNumberCtrl = TextEditingController();
  final _utilityCompanyCtrl = TextEditingController();
  final _connectionTypeCtrl = TextEditingController(text: 'Trifásico');
  final _avgKwhCtrl = TextEditingController();
  final _solarKwPCtrl = TextEditingController();

  // ── Controllers de Endereço Estruturado ──────────────────────────────────
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
  bool _isAiAnalyzing = false;
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
    _ucNumberCtrl.dispose();
    _utilityCompanyCtrl.dispose();
    _connectionTypeCtrl.dispose();
    _avgKwhCtrl.dispose();
    _solarKwPCtrl.dispose();
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

  // ── Importação com IA Gemini Vision ───────────────────────────────────────
  Future<void> _importEnergyBillWithAi() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        setState(() => _errorMessage = 'Erro ao ler arquivo: $e');
        return;
      }

      if (bytes.isEmpty) {
        setState(() => _errorMessage = 'Não foi possível ler o arquivo selecionado.');
        return;
      }

      setState(() {
        _isAiAnalyzing = true;
        _errorMessage = null;
      });

      final parsedBill = await GeminiEnergyBillService.analyzeEnergyBill(
        fileBytes: bytes,
        fileExtension: file.extension ?? 'pdf',
      );

      if (!mounted) return;
      setState(() {
        _isAiAnalyzing = false;
      });

      // Abre modal de resumo para o usuário revisar e aceitar
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => EnergyBillSummaryDialog(
          parsedBill: parsedBill,
          onAccept: () => _applyParsedBill(parsedBill),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiAnalyzing = false;
        _errorMessage = 'Falha ao analisar conta: ${e.toString()}';
      });
    }
  }

  void _applyParsedBill(ParsedEnergyBill bill) {
    setState(() {
      if (bill.clientName != null && bill.clientName!.isNotEmpty) {
        _nameCtrl.text = bill.clientName!;
      }
      if (bill.document != null && bill.document!.isNotEmpty) {
        _documentCtrl.text = bill.document!;
      }
      _type = bill.clientType;

      if (bill.email != null && bill.email!.isNotEmpty) {
        _emailCtrl.text = bill.email!;
      }
      if (bill.phone != null && bill.phone!.isNotEmpty) {
        _phoneCtrl.text = bill.phone!;
      }

      // Endereço
      if (bill.zipCode != null && bill.zipCode!.isNotEmpty) {
        _zipCtrl.text = bill.zipCode!;
      }
      if (bill.street != null && bill.street!.isNotEmpty) {
        _streetCtrl.text = bill.street!;
        _addressLocked = true;
      }
      if (bill.addressNumber != null && bill.addressNumber!.isNotEmpty) {
        _numberCtrl.text = bill.addressNumber!;
      }
      if (bill.complement != null && bill.complement!.isNotEmpty) {
        _complementCtrl.text = bill.complement!;
      }
      if (bill.neighborhood != null && bill.neighborhood!.isNotEmpty) {
        _neighborhoodCtrl.text = bill.neighborhood!;
      }
      if (bill.city != null && bill.city!.isNotEmpty) {
        _cityCtrl.text = bill.city!;
      }
      if (bill.state != null && bill.state!.isNotEmpty) {
        _stateCtrl.text = bill.state!;
      }

      // Dados Técnicos da UC
      if (bill.ucNumber != null && bill.ucNumber!.isNotEmpty) {
        _ucNumberCtrl.text = bill.ucNumber!;
      }
      if (bill.utilityCompany != null && bill.utilityCompany!.isNotEmpty) {
        _utilityCompanyCtrl.text = bill.utilityCompany!;
      }
      if (bill.connectionType != null && bill.connectionType!.isNotEmpty) {
        _connectionTypeCtrl.text = bill.connectionType!;
      }
      if (bill.averageMonthlyConsumptionKwh > 0) {
        _avgKwhCtrl.text = bill.averageMonthlyConsumptionKwh.toStringAsFixed(0);
      }
      if (bill.suggestedSolarKwP > 0) {
        _solarKwPCtrl.text = bill.suggestedSolarKwP.toStringAsFixed(2);
      }

      // Diagnóstico em Notas
      final diagnosticNotes = StringBuffer();
      diagnosticNotes.writeln('⚡ Diagnóstico de Conta de Energia (IA Gemini):');
      if (bill.ucNumber != null) {
        diagnosticNotes.writeln('• Unidade Consumidora: ${bill.ucNumber} (${bill.utilityCompany ?? ""})');
      }
      if (bill.averageMonthlyConsumptionKwh > 0) {
        diagnosticNotes.writeln('• Consumo Médio Mensal: ${bill.averageMonthlyConsumptionKwh.toStringAsFixed(0)} kWh/mês');
      }
      if (bill.suggestedSolarKwP > 0) {
        diagnosticNotes.writeln('• Potência Solar Recomendada: ${bill.suggestedSolarKwP.toStringAsFixed(2)} kWp');
      }
      if (bill.estimatedMonthlyGenerationKwh > 0) {
        diagnosticNotes.writeln('• Geração Estimada: ${bill.estimatedMonthlyGenerationKwh.toStringAsFixed(0)} kWh/mês');
      }
      if (bill.connectionType != null) {
        diagnosticNotes.writeln('• Tipo de Ligação: ${bill.connectionType}');
      }

      if (_notesCtrl.text.trim().isEmpty) {
        _notesCtrl.text = diagnosticNotes.toString().trim();
      } else {
        _notesCtrl.text = '${_notesCtrl.text}\n\n${diagnosticNotes.toString().trim()}';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conta de energia analisada! Dados e previsão solar preenchidos.'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Cálculo reativo de Potência Solar a partir do consumo ──────────────────
  void _onAvgKwhChanged(String val) {
    final avg = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
    if (avg > 0) {
      final kwp = avg / 110.0;
      setState(() {
        _solarKwPCtrl.text = kwp.toStringAsFixed(2);
      });
    }
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
    final isMobile = MediaQuery.of(context).size.width < 640;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 24, vertical: isMobile ? 12 : 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header do Diálogo ─────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28, vertical: isMobile ? 14 : 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Editar Cadastro' : 'Novo Cliente',
                            style: GoogleFonts.outfit(
                              fontSize: isMobile ? 17 : 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Dados cadastrais, endereço e diagnóstico solar',
                            style: GoogleFonts.inter(fontSize: isMobile ? 11.5 : 13, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── Corpo Rolável ─────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 14 : 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── BANNER DE IMPORTAÇÃO COM IA GEMINI VISION ─────────
                      Container(
                        padding: EdgeInsets.all(isMobile ? 14 : 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF334155)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              'Importar Conta com IA',
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFF59E0B)),
                                              ),
                                              child: const Text(
                                                'GEMINI',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFFCD34D),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Envie a conta (PDF ou Foto) para autocompletar titular, endereço e consumo.',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: _isAiAnalyzing ? null : _importEnergyBillWithAi,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF59E0B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: _isAiAnalyzing
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                              ),
                                              SizedBox(width: 8),
                                              Text('ANALISANDO...', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.upload_file_rounded, size: 16),
                                              SizedBox(width: 6),
                                              Text('ENVIAR CONTA', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Importação Inteligente de Conta de Energia',
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFF59E0B)),
                                              ),
                                              child: Text(
                                                'IA GEMINI OCR',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFFFCD34D),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Envie a conta (PDF ou Foto). A IA lê o titular, CPF/CNPJ, endereço, UC e calcula a média de consumo em kWh e potência solar recomendada em kWp!',
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isAiAnalyzing ? null : _importEnergyBillWithAi,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                        child: _isAiAnalyzing
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'ANALISANDO...',
                                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'ENVIAR CONTA',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      letterSpacing: 0.4,
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
                      const SizedBox(height: 18),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── SEÇÃO 1: DADOS CADASTRAIS DO CLIENTE ──────────────
                      _sectionTitle(Icons.person_outline_rounded, 'Identificação do Cliente', 'Defina o tipo de pessoa e os dados principais'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _typeRadio(
                              type: ClientType.person,
                              label: isMobile ? 'Pessoa Física' : 'Pessoa Física (CPF)',
                              icon: Icons.person_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _typeRadio(
                              type: ClientType.company,
                              label: isMobile ? 'Pessoa Jurídica' : 'Pessoa Jurídica (CNPJ)',
                              icon: Icons.business_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Nome e Documento
                      if (isMobile) ...[
                        _fieldLabel(_type == ClientType.company ? 'Razão Social / Nome *' : 'Nome Completo *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            hintText: _type == ClientType.company ? 'Nome da Empresa' : 'Nome Completo',
                            prefixIcon: Icon(_type == ClientType.company ? Icons.business_outlined : Icons.person_outline, color: const Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                      ] else ...[
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
                            const SizedBox(width: 14),
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
                      ],
                      const SizedBox(height: 14),

                      // E-mail, Telefone e Nome Fantasia
                      if (isMobile) ...[
                        _fieldLabel('E-mail *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'contato@cliente.com.br',
                            prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        if (_type == ClientType.company) ...[
                          const SizedBox(height: 12),
                          _fieldLabel('Nome Fantasia'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _companyCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Estrela Alimentos',
                              prefixIcon: Icon(Icons.storefront_outlined, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ] else ...[
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
                                      hintText: 'contato@cliente.com.br',
                                      prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
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
                            if (_type == ClientType.company) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _fieldLabel('Nome Fantasia'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _companyCtrl,
                                      decoration: const InputDecoration(
                                        hintText: 'Ex: Estrela Alimentos',
                                        prefixIcon: Icon(Icons.storefront_outlined, color: Color(0xFF64748B)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      // ── SEÇÃO 2: DADOS DA CONTA DE ENERGIA & DIMENSIONAMENTO SOLAR ──
                      _sectionTitle(Icons.bolt_rounded, 'Unidade Consumidora & Previsão Solar', 'Informações elétricas e estimativa fotovoltaica'),
                      const SizedBox(height: 12),

                      Container(
                        padding: EdgeInsets.all(isMobile ? 14 : 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          children: [
                            if (isMobile) ...[
                              _fieldLabel('Nº Unidade Consumidora (UC)'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _ucNumberCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Ex: 833.185.017-11',
                                  prefixIcon: Icon(Icons.tag_rounded, color: Color(0xFFD97706)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _fieldLabel('Distribuidora / Concessionária'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _utilityCompanyCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Ex: Energisa, CPFL, Enel...',
                                  prefixIcon: Icon(Icons.domain_rounded, color: Color(0xFFD97706)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _fieldLabel('Tipo de Ligação'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _connectionTypeCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Trifásico / Bifásico / Monofásico',
                                  prefixIcon: Icon(Icons.settings_input_component_rounded, color: Color(0xFFD97706)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _fieldLabel('Consumo Médio Mensal (kWh/mês)'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _avgKwhCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: _onAvgKwhChanged,
                                decoration: const InputDecoration(
                                  hintText: 'Ex: 600',
                                  suffixText: 'kWh/mês',
                                  prefixIcon: Icon(Icons.electric_meter_outlined, color: Color(0xFFD97706)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _fieldLabel('Potência Solar Sugerida (kWp)'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _solarKwPCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  hintText: 'Ex: 5.45',
                                  suffixText: 'kWp',
                                  prefixIcon: Icon(Icons.solar_power_rounded, color: Color(0xFF059669)),
                                ),
                              ),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel('Nº Unidade Consumidora (UC)'),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _ucNumberCtrl,
                                          decoration: const InputDecoration(
                                            hintText: 'Ex: 833.185.017-11',
                                            prefixIcon: Icon(Icons.tag_rounded, color: Color(0xFFD97706)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel('Distribuidora / Concessionária'),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _utilityCompanyCtrl,
                                          decoration: const InputDecoration(
                                            hintText: 'Ex: Energisa, CPFL, Enel, Cemig...',
                                            prefixIcon: Icon(Icons.domain_rounded, color: Color(0xFFD97706)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel('Tipo de Ligação'),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _connectionTypeCtrl,
                                          decoration: const InputDecoration(
                                            hintText: 'Trifásico / Bifásico / Monofásico',
                                            prefixIcon: Icon(Icons.settings_input_component_rounded, color: Color(0xFFD97706)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel('Consumo Médio Mensal (kWh/mês)'),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _avgKwhCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: _onAvgKwhChanged,
                                          decoration: const InputDecoration(
                                            hintText: 'Ex: 600',
                                            suffixText: 'kWh/mês',
                                            prefixIcon: Icon(Icons.electric_meter_outlined, color: Color(0xFFD97706)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel('Potência Solar Sugerida (kWp)'),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _solarKwPCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            hintText: 'Ex: 5.45',
                                            suffixText: 'kWp',
                                            prefixIcon: Icon(Icons.solar_power_rounded, color: Color(0xFF059669)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── SEÇÃO 3: ENDEREÇO COM AUTOCEP ─────────────────────
                      Row(
                        children: [
                          _sectionTitle(Icons.location_on_outlined, 'Endereço da Unidade', 'Consulta via CEP'),
                          const Spacer(),
                          if (_addressLocked) ...[
                            InkWell(
                              onTap: _unlockAddress,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFC7D2FE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.lock_open_rounded, size: 13, color: Color(0xFF6366F1)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Editar campos',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // CEP e Número
                      if (isMobile) ...[
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
                        const SizedBox(height: 12),
                        _fieldLabel('Número'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _numberCtrl,
                          focusNode: _numberFocus,
                          decoration: const InputDecoration(
                            hintText: '123',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fieldLabel('Complemento'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _complementCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Apto 42, Bloco B...',
                          ),
                        ),
                      ] else ...[
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
                            const SizedBox(width: 14),
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
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Complemento'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _complementCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'Apto 42, Bloco B, Galpão 3...',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Logradouro, Bairro, Cidade e UF
                      if (isMobile) ...[
                        _fieldLabel('Logradouro / Rua'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _streetCtrl,
                          readOnly: _addressLocked,
                          decoration: InputDecoration(
                            hintText: 'Av. Paulista, Rua...',
                            fillColor: _addressLocked ? const Color(0xFFF1F5F9) : null,
                            filled: _addressLocked,
                            prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        _fieldLabel('Cidade'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _cityCtrl,
                          readOnly: _addressLocked,
                          decoration: InputDecoration(
                            hintText: 'Cidade',
                            fillColor: _addressLocked ? const Color(0xFFF1F5F9) : null,
                            filled: _addressLocked,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
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
                            const SizedBox(width: 12),
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
                            const SizedBox(width: 12),
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
                      const SizedBox(height: 20),

                      // ── SEÇÃO 4: OBSERVAÇÕES ───────────────────────────────
                      _sectionTitle(Icons.notes_rounded, 'Observações & Histórico', 'Anotações gerais e diagnóstico'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Cliente tem interesse em usina solar de 5 kWp. Telhado cerâmico.',
                          prefixIcon: Icon(Icons.comment_outlined, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Rodapé de Ações ───────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28, vertical: isMobile ? 12 : 18),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: isMobile
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                'CANCELAR',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B), fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      _isEditing ? 'SALVAR' : 'CADASTRAR',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'CANCELAR',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _submit,
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
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
                                              fontSize: 13,
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

  Widget _sectionTitle(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5, color: const Color(0xFF1E293B)),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                  fontSize: 12.5,
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
