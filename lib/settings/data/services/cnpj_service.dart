import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Modelo de Dados Completo Retornado pela Consulta Gratuita de CNPJ da Receita Federal
class CnpjData {
  final String cnpj;
  final String razaoSocial;
  final String? nomeFantasia;
  final String? situacaoCadastral;
  final String? dataInicioAtividade;
  final String? porte;
  final String? cnaePrincipal;
  final String? cnaesSecundarios;
  final String? naturezaJuridica;
  final String? capitalSocial;
  final String? phone;
  final String? email;
  final String? zipCode;
  final String? street;
  final String? number;
  final String? complement;
  final String? neighborhood;
  final String? city;
  final String? state;

  CnpjData({
    required this.cnpj,
    required this.razaoSocial,
    this.nomeFantasia,
    this.situacaoCadastral,
    this.dataInicioAtividade,
    this.porte,
    this.cnaePrincipal,
    this.cnaesSecundarios,
    this.naturezaJuridica,
    this.capitalSocial,
    this.phone,
    this.email,
    this.zipCode,
    this.street,
    this.number,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
  });

  /// Nome amigável de exibição (Nome Fantasia se existir, senão Razão Social)
  String get displayName {
    if (nomeFantasia != null && nomeFantasia!.trim().isNotEmpty) {
      return nomeFantasia!.trim();
    }
    return razaoSocial.trim();
  }

  factory CnpjData.fromJson(Map<String, dynamic> json) {
    // Formatação de DDD + Telefone
    String? phoneStr;
    final dddPhone = json['ddd_telefone_1'] as String? ?? json['telefone'] as String?;
    if (dddPhone != null && dddPhone.trim().isNotEmpty) {
      final cleanPhone = dddPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length >= 10) {
        final ddd = cleanPhone.substring(0, 2);
        final num = cleanPhone.substring(2);
        phoneStr = '($ddd) ${num.length == 9 ? "${num.substring(0, 5)}-${num.substring(5)}" : "${num.substring(0, 4)}-${num.substring(4)}"}';
      } else {
        phoneStr = dddPhone.trim();
      }
    }

    // CNAE Principal
    String? cnaeMain;
    final cnaeCode = json['cnae_fiscal']?.toString();
    final cnaeDesc = json['cnae_fiscal_descricao'] as String?;
    if (cnaeCode != null && cnaeDesc != null) {
      cnaeMain = '$cnaeCode - $cnaeDesc';
    } else if (cnaeDesc != null) {
      cnaeMain = cnaeDesc;
    }

    // CNAEs Secundários
    String? cnaesSec;
    final rawSec = json['cnaes_secundarios'] as List?;
    if (rawSec != null && rawSec.isNotEmpty) {
      final list = <String>[];
      for (final item in rawSec) {
        if (item is Map) {
          final code = item['codigo']?.toString();
          final desc = item['descricao'] as String?;
          if (code != null && desc != null) {
            list.add('$code - $desc');
          } else if (desc != null) {
            list.add(desc);
          }
        }
      }
      if (list.isNotEmpty) cnaesSec = list.join('\n');
    }

    // Capital Social
    String? capSocial;
    final rawCap = json['capital_social'];
    if (rawCap != null) {
      final val = double.tryParse(rawCap.toString());
      if (val != null) {
        capSocial = 'R\$ ${val.toStringAsFixed(2)}';
      } else {
        capSocial = rawCap.toString();
      }
    }

    return CnpjData(
      cnpj: (json['cnpj'] as String? ?? '').replaceAll(RegExp(r'\D'), ''),
      razaoSocial: json['razao_social'] as String? ?? json['nome'] as String? ?? '',
      nomeFantasia: json['nome_fantasia'] as String? ?? json['fantasia'] as String?,
      situacaoCadastral: json['descricao_situacao_cadastral'] as String? ?? json['situacao'] as String?,
      dataInicioAtividade: json['data_inicio_atividade'] as String?,
      porte: json['descricao_porte'] as String? ?? json['porte'] as String?,
      cnaePrincipal: cnaeMain,
      cnaesSecundarios: cnaesSec,
      naturezaJuridica: json['natureza_juridica'] as String?,
      capitalSocial: capSocial,
      phone: phoneStr,
      email: json['email'] as String?,
      zipCode: (json['cep'] as String? ?? '').replaceAll(RegExp(r'\D'), ''),
      street: json['logradouro'] as String?,
      number: json['numero'] as String?,
      complement: json['complemento'] as String?,
      neighborhood: json['bairro'] as String?,
      city: json['municipio'] as String? ?? json['cidade'] as String?,
      state: json['uf'] as String?,
    );
  }
}

/// Serviço gratuito para Consulta de CNPJ na Receita Federal via BrasilAPI / ReceitaWS
class CnpjService {
  /// Consulta gratuita de CNPJ via BrasilAPI com fallback
  static Future<CnpjData?> lookupCnpj(String rawCnpj) async {
    final clean = rawCnpj.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 14) return null;

    try {
      // 1. Consulta principal via BrasilAPI (Gratuito, sem API key, CORS nativo)
      final uri = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$clean');
      final response = await http.get(uri).timeout(const Duration(seconds: 9));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CnpjData.fromJson(data);
      } else if (response.statusCode == 404) {
        debugPrint('[CnpjService] CNPJ $clean não encontrado na base da Receita.');
        return null;
      }
    } catch (e) {
      debugPrint('[CnpjService] Erro na consulta BrasilAPI: $e. Tentando fallback...');
    }

    // 2. Fallback via ReceitaWS pública
    try {
      final fallbackUri = Uri.parse('https://publica.cnpj.ws/cnpj/$clean');
      final response = await http.get(fallbackUri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String name = data['razao_social'] as String? ?? '';
        final String? fantasy = data['estabelecimento']?['nome_fantasia'] as String?;
        final String? phone = data['estabelecimento']?['telefone1'] as String?;
        final String? email = data['estabelecimento']?['email'] as String?;
        final String? cep = data['estabelecimento']?['cep'] as String?;
        final String? street = data['estabelecimento']?['logradouro'] as String?;
        final String? num = data['estabelecimento']?['numero'] as String?;
        final String? comp = data['estabelecimento']?['complemento'] as String?;
        final String? neigh = data['estabelecimento']?['bairro'] as String?;
        final String? city = data['estabelecimento']?['cidade']?['nome'] as String?;
        final String? uf = data['estabelecimento']?['estado']?['sigla'] as String?;

        if (name.isNotEmpty) {
          return CnpjData(
            cnpj: clean,
            razaoSocial: name,
            nomeFantasia: fantasy,
            phone: phone,
            email: email,
            zipCode: cep,
            street: street,
            number: num,
            complement: comp,
            neighborhood: neigh,
            city: city,
            state: uf,
          );
        }
      }
    } catch (e) {
      debugPrint('[CnpjService] Erro no fallback de CNPJ: $e');
    }

    return null;
  }
}
