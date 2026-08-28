import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import '../../../proposals/domain/models/proposal_item_model.dart';
import '../../domain/models/product_model.dart';

/// Tipos de componentes fotovoltaicos detectados
enum SolarComponentType {
  module('Módulo / Placa Solar', Icons.solar_power_rounded, Color(0xFFF59E0B)),
  inverter('Inversor / Microinversor', Icons.electric_meter_rounded, Color(0xFF2563EB)),
  structure('Estrutura de Fixação', Icons.handyman_rounded, Color(0xFF475569)),
  cable('Cabo Solar Fotovoltaico', Icons.cable_rounded, Color(0xFFDC2626)),
  connector('Conector Solar / MC4', Icons.electrical_services_rounded, Color(0xFFD97706)),
  protection('Aterramento & Proteção', Icons.shield_rounded, Color(0xFF059669)),
  battery('Bateria / Armazenamento', Icons.battery_charging_full_rounded, Color(0xFF8B5CF6)),
  other('Acessórios & Outros', Icons.inventory_2_rounded, Color(0xFF64748B));

  final String label;
  final IconData icon;
  final Color color;

  const SolarComponentType(this.label, this.icon, this.color);
}

/// Item fotovoltaico extraído do PDF / Cotação
class ParsedSolarItem {
  final String? productId;
  final String name;
  final String? sku;
  final String? manufacturer;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final SolarComponentType componentType;
  final double? moduleWatts;

  const ParsedSolarItem({
    this.productId,
    required this.name,
    this.sku,
    this.manufacturer,
    required this.quantity,
    this.unit = 'UN',
    this.unitPrice = 0.0,
    this.totalPrice = 0.0,
    required this.componentType,
    this.moduleWatts,
  });

  /// Extrai a potência do módulo em Watts
  double? get effectiveModuleWatts {
    if (moduleWatts != null && moduleWatts! > 0) return moduleWatts;
    final isMod = componentType == SolarComponentType.module ||
        name.toLowerCase().contains('modulo') ||
        name.toLowerCase().contains('módulo') ||
        name.toLowerCase().contains('painel') ||
        name.toLowerCase().contains('placa') ||
        name.toLowerCase().contains('bifacial') ||
        name.toLowerCase().contains('cel.');

    if (isMod) {
      final text = '$name ${sku ?? ""}';
      final match = RegExp(r'(\d{3,4}(?:\.\d+)?)\s*(?:w|watts|wp)\b', caseSensitive: false).firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  ParsedSolarItem copyWith({
    String? productId,
    String? name,
    String? sku,
    String? manufacturer,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
    SolarComponentType? componentType,
    double? moduleWatts,
  }) {
    return ParsedSolarItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      manufacturer: manufacturer ?? this.manufacturer,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      componentType: componentType ?? this.componentType,
      moduleWatts: moduleWatts ?? this.moduleWatts,
    );
  }

  ProposalItemModel toProposalItem() {
    final watts = effectiveModuleWatts;
    return ProposalItemModel(
      productId: productId,
      name: name,
      sku: sku,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      moduleWatts: watts,
    );
  }

  ProductModel toProductModel({String? supplierId, String? supplierName}) {
    final isMod = componentType == SolarComponentType.module ||
        name.toLowerCase().contains('modulo') ||
        name.toLowerCase().contains('módulo') ||
        name.toLowerCase().contains('painel') ||
        name.toLowerCase().contains('placa') ||
        name.toLowerCase().contains('bifacial') ||
        name.toLowerCase().contains('cel.');

    final subcat = isMod
        ? 'MÓDULO SOLAR'
        : (componentType == SolarComponentType.inverter
            ? 'INVERSOR SOLAR'
            : (componentType == SolarComponentType.structure
                ? 'ESTRUTURA'
                : (componentType == SolarComponentType.cable || componentType == SolarComponentType.connector
                    ? 'CABOS & CONECTORES'
                    : (componentType == SolarComponentType.battery
                        ? 'BATERIA'
                        : (componentType == SolarComponentType.protection
                            ? 'STRING BOX'
                            : componentType.label)))));

    final watts = effectiveModuleWatts;

    return ProductModel(
      id: productId ?? '',
      name: name,
      sku: sku,
      sector: ProductSector.solarPlant,
      categoryTitle: 'Usina Solar',
      subcategory: subcat,
      description: 'Item de usina solar fotovoltaica. Fabricante: ${manufacturer ?? "Padrão"}.',
      supplierId: supplierId,
      supplierName: supplierName ?? manufacturer,
      salePrice: 0.0,
      costPrice: 0.0,
      stockQuantity: 100.0,
      minStock: 1.0,
      unit: ProductUnit.fromString(unit),
      status: ProductStatus.active,
      specificAttributes: {
        'componentType': isMod ? 'module' : componentType.name,
        if (manufacturer != null) 'manufacturer': manufacturer,
        if (watts != null && watts > 0) 'moduleWatts': watts,
        'solarComponent': true,
        'isSolarComponent': true,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

/// Resultado consolidado da análise de uma Cotação / Usina Solar
class ParsedSolarProposal {
  final String proposalNumber;
  final String distributorName;
  final String plantName;
  final double kilowatts;
  final double? generationKwh;
  final String roofType;
  final double productsPrice;
  final double shippingFee;
  final double totalAmount;
  final List<ParsedSolarItem> items;
  final String? rawText;

  const ParsedSolarProposal({
    required this.proposalNumber,
    required this.distributorName,
    required this.plantName,
    required this.kilowatts,
    this.generationKwh,
    required this.roofType,
    required this.productsPrice,
    required this.shippingFee,
    required this.totalAmount,
    required this.items,
    this.rawText,
  });

  ParsedSolarProposal copyWith({
    String? proposalNumber,
    String? distributorName,
    String? plantName,
    double? kilowatts,
    double? generationKwh,
    String? roofType,
    double? productsPrice,
    double? shippingFee,
    double? totalAmount,
    List<ParsedSolarItem>? items,
    String? rawText,
  }) {
    return ParsedSolarProposal(
      proposalNumber: proposalNumber ?? this.proposalNumber,
      distributorName: distributorName ?? this.distributorName,
      plantName: plantName ?? this.plantName,
      kilowatts: kilowatts ?? this.kilowatts,
      generationKwh: generationKwh ?? this.generationKwh,
      roofType: roofType ?? this.roofType,
      productsPrice: productsPrice ?? this.productsPrice,
      shippingFee: shippingFee ?? this.shippingFee,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      rawText: rawText ?? this.rawText,
    );
  }
}

/// Extrator e Parser dinâmico de cotações fotovoltaicas (PDF / Imagem / OCR)
class SolarProposalParserService {
  /// Extrai texto de bytes de arquivos PDF descompactando streams
  static String extractTextFromPdfBytes(Uint8List bytes) {
    final StringBuffer extracted = StringBuffer();

    // 1. Tenta extrair strings legíveis do binário
    final printable = _extractPrintable(bytes);
    if (printable.isNotEmpty) {
      extracted.writeln(printable);
    }

    // 2. Procura e descompacta streams FlateDecode
    try {
      final rawLatin = latin1.decode(bytes);
      final streamRegex = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
      for (final match in streamRegex.allMatches(rawLatin)) {
        final streamData = match.group(1);
        if (streamData != null && streamData.isNotEmpty) {
          try {
            final streamBytes = Uint8List.fromList(streamData.codeUnits);
            final decompressed = ZLibDecoder().decodeBytes(streamBytes);
            final textInStream = latin1.decode(decompressed);

            // Procura comandos de texto PDF: (texto) Tj ou [(array)] TJ
            final tjRegex = RegExp(r'\((.*?)\)\s*Tj');
            for (final m in tjRegex.allMatches(textInStream)) {
              final s = m.group(1);
              if (s != null && s.trim().isNotEmpty) {
                extracted.writeln(s);
              }
            }

            final arrayTjRegex = RegExp(r'\[(.*?)\]\s*TJ');
            for (final m in arrayTjRegex.allMatches(textInStream)) {
              final content = m.group(1);
              if (content != null) {
                final innerStrings = RegExp(r'\((.*?)\)').allMatches(content);
                final line = innerStrings.map((im) => im.group(1) ?? '').join();
                if (line.trim().isNotEmpty) {
                  extracted.writeln(line);
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    return extracted.toString();
  }

  static String _extractPrintable(Uint8List bytes) {
    final buffer = StringBuffer();
    final current = <int>[];

    for (final b in bytes) {
      if ((b >= 32 && b <= 126) || (b >= 160 && b <= 255) || b == 10 || b == 13 || b == 9) {
        current.add(b);
      } else {
        if (current.length >= 3) {
          try {
            buffer.writeln(utf8.decode(current, allowMalformed: true));
          } catch (_) {
            buffer.writeln(String.fromCharCodes(current));
          }
        }
        current.clear();
      }
    }
    if (current.length >= 3) {
      buffer.writeln(String.fromCharCodes(current));
    }
    return buffer.toString();
  }

  /// Analisa dinamicamente qualquer cotação fotovoltaica sem dados fixos de teste
  static ParsedSolarProposal parseRawText(String text) {
    // 1. Extração do Número da Cotação / Orçamento
    String proposalNumber = 'COT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final cotMatch = RegExp(r'(?:Cotação|Orçamento|Proposta|Pedido|Quote)\s*[:#\s]?\s*([\w\-]+)', caseSensitive: false).firstMatch(text);
    if (cotMatch != null && cotMatch.group(1) != null) {
      proposalNumber = cotMatch.group(1)!.trim();
    }

    // 2. Identificação da Distribuidora
    String distributor = 'Distribuidora Solar';
    final lower = text.toLowerCase();
    if (lower.contains('belenergy') || lower.contains('belenus')) {
      distributor = 'BelEnergy / Belenus';
    } else if (lower.contains('edeltec')) {
      distributor = 'Edeltec Solar';
    } else if (lower.contains('fortlev')) {
      distributor = 'Fortlev Solar';
    } else if (lower.contains('weg')) {
      distributor = 'WEG Solar';
    } else if (lower.contains('aldo')) {
      distributor = 'Aldo Solar';
    } else if (lower.contains('sou energy')) {
      distributor = 'Sou Energy';
    } else if (lower.contains('canadian')) {
      distributor = 'Canadian Solar';
    } else if (lower.contains('elgin')) {
      distributor = 'Elgin Solar';
    } else if (lower.contains('intelbras')) {
      distributor = 'Intelbras Solar';
    } else if (lower.contains('neosolar')) {
      distributor = 'Neosolar';
    }

    // 3. Extração da Potência do Sistema (kWp)
    double kwp = 0.0;
    final kwpMatch = RegExp(r'Potência.*?:\s*([\d\.,]+)\s*kWp', caseSensitive: false).firstMatch(text) ??
        RegExp(r'([\d\.,]+)\s*kWp', caseSensitive: false).firstMatch(text) ??
        RegExp(r'([\d\.,]+)\s*KWP', caseSensitive: false).firstMatch(text);
    if (kwpMatch != null && kwpMatch.group(1) != null) {
      kwp = double.tryParse(kwpMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
    }

    // 4. Extração do Tipo de Cobertura / Telhado
    String roofType = 'Cerâmico';
    if (lower.contains('colonial') || lower.contains('cerâm') || lower.contains('ceram')) {
      roofType = 'Cerâmico';
    } else if (lower.contains('metálic') || lower.contains('metalic') || lower.contains('trapezoidal') || lower.contains('ondulad')) {
      roofType = 'Metálico';
    } else if (lower.contains('fibrocimento')) {
      roofType = 'Fibrocimento';
    } else if (lower.contains('isotérmic') || lower.contains('isotermic') || lower.contains('sanduiche') || lower.contains('sanduíche')) {
      roofType = 'Isotérmico';
    } else if (lower.contains('solo') || lower.contains('chão')) {
      roofType = 'Solo';
    } else if (lower.contains('laje') || lower.contains('plano')) {
      roofType = 'Laje';
    } else if (lower.contains('sem estrutura')) {
      roofType = 'Sem Estrutura';
    }

    // 5. Extração Financeira com Prioridade Soberana no VALOR TOTAL
    double shippingFee = 0.0;
    double totalAmount = 0.0;

    // Busca Frete (se houver no documento)
    final fretePatterns = [
      RegExp(r'(?:Valor\s+)?Frete\s*[:=]?\s*R\$\s*([\d\.,]+)', caseSensitive: false),
      RegExp(r'Frete\s+(?:CIF|FOB)?\s*[:=]?\s*R\$\s*([\d\.,]+)', caseSensitive: false),
      RegExp(r'\+\s*Valor\s+Frete\s*[:=]?\s*R\$\s*([\d\.,]+)', caseSensitive: false),
    ];
    for (final p in fretePatterns) {
      final m = p.firstMatch(text);
      if (m != null && m.group(1) != null) {
        shippingFee = _parsePrice(m.group(1)!);
        break;
      }
    }

    // Busca Valor Total da Cotação
    final totalPatterns = [
      RegExp(r'Valor\s+Total\s*[:=]?\s*(?:R\$\s*)?([\d\.,]+)', caseSensitive: false),
      RegExp(r'Total\s+Geral\s*[:=]?\s*(?:R\$\s*)?([\d\.,]+)', caseSensitive: false),
      RegExp(r'Total\s+da\s+Cotação\s*[:=]?\s*(?:R\$\s*)?([\d\.,]+)', caseSensitive: false),
      RegExp(r'Total\s+do\s+Pedido\s*[:=]?\s*(?:R\$\s*)?([\d\.,]+)', caseSensitive: false),
      RegExp(r'Total\s+Final\s*[:=]?\s*(?:R\$\s*)?([\d\.,]+)', caseSensitive: false),
      RegExp(r'Total\s*[:=]?\s*R\$\s*([\d\.,]+)', caseSensitive: false),
    ];
    for (final p in totalPatterns) {
      final m = p.firstMatch(text);
      if (m != null && m.group(1) != null) {
        totalAmount = _parsePrice(m.group(1)!);
        break;
      }
    }

    // Se não encontrou Valor Total, busca Total de Produtos + Frete
    if (totalAmount <= 0) {
      final prodPriceMatch = RegExp(r'Total\s+de\s+Produtos\s*[:=]?\s*R\$\s*([\d\.,]+)', caseSensitive: false).firstMatch(text);
      if (prodPriceMatch != null && prodPriceMatch.group(1) != null) {
        final prodPrice = _parsePrice(prodPriceMatch.group(1)!);
        totalAmount = prodPrice + shippingFee;
      }
    }

    // 6. Extração e Explosão Dinâmica dos Itens / Produtos do arquivo
    final items = _parseItemsFromText(text);

    // Se a potência não estava explícita, calcula pela soma dos módulos
    if (kwp <= 0) {
      for (final item in items) {
        if (item.componentType == SolarComponentType.module) {
          final matchWatts = RegExp(r'(\d+)\s*W', caseSensitive: false).firstMatch(item.name);
          if (matchWatts != null && matchWatts.group(1) != null) {
            final watts = double.tryParse(matchWatts.group(1)!) ?? 0.0;
            kwp += (watts * item.quantity) / 1000.0;
          }
        }
      }
    }

    // 7. Descrição Gerada da Usina
    String plantDesc = 'Usina Solar ${kwp > 0 ? "${kwp.toStringAsFixed(2)} kWp" : ""}';
    final mainModule = items.firstWhere(
      (i) => i.componentType == SolarComponentType.module,
      orElse: () => const ParsedSolarItem(name: '', quantity: 0, componentType: SolarComponentType.module),
    );
    final mainInverter = items.firstWhere(
      (i) => i.componentType == SolarComponentType.inverter,
      orElse: () => const ParsedSolarItem(name: '', quantity: 0, componentType: SolarComponentType.inverter),
    );

    if (mainInverter.name.isNotEmpty && mainModule.name.isNotEmpty) {
      plantDesc += ' - ${mainInverter.manufacturer ?? "Inversor"} + ${mainModule.quantity.toInt()}x Módulos ${mainModule.manufacturer ?? ""}';
    } else if (proposalNumber.isNotEmpty) {
      plantDesc += ' - $distributor ($proposalNumber)';
    }

    return ParsedSolarProposal(
      proposalNumber: proposalNumber,
      distributorName: distributor,
      plantName: plantDesc,
      kilowatts: kwp > 0 ? kwp : 0.0,
      roofType: roofType,
      productsPrice: totalAmount,
      shippingFee: shippingFee,
      totalAmount: totalAmount,
      items: items,
      rawText: text,
    );
  }

  /// Parser dinâmico de itens a partir do texto
  static List<ParsedSolarItem> _parseItemsFromText(String text) {
    final List<ParsedSolarItem> list = [];
    final lines = text.split('\n');

    String? currentName;
    String? currentSku;
    String? currentManufacturer;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Detecta fabricante
      if (line.toLowerCase().startsWith('fabricante:')) {
        currentManufacturer = line.replaceFirst(RegExp(r'fabricante:\s*', caseSensitive: false), '').trim();
        if (currentManufacturer.isEmpty && i + 1 < lines.length) {
          currentManufacturer = lines[i + 1].trim();
        }
        continue;
      }

      // Detecta quantidade com unidade isolada (ex: "14 PC", "1 PC", "2 JG", "10 PC", "12 JG", "35 M", "3 PT", "1 UN")
      final qtyMatch = RegExp(r'^(\d+(?:[\.,]\d+)?)\s+(PC|JG|M|PT|UN|CX|PCT|KG|PAR|CJ)$', caseSensitive: false).firstMatch(line);
      if (qtyMatch != null && currentName != null) {
        final qty = double.tryParse(qtyMatch.group(1)!.replaceAll(',', '.')) ?? 1.0;
        final unit = qtyMatch.group(2)!.toUpperCase();
        final type = _detectComponentType(currentName);

        list.add(ParsedSolarItem(
          name: currentName,
          sku: currentSku,
          manufacturer: currentManufacturer,
          quantity: qty,
          unit: unit,
          unitPrice: 0.0,
          totalPrice: 0.0,
          componentType: type,
        ));

        currentName = null;
        currentSku = null;
        currentManufacturer = null;
        continue;
      }

      // Detecta quantidade no formato inline (ex: "14x Modulo...", "1 UN - Inversor...", "10 PC Suporte...")
      final inlineQtyMatch = RegExp(r'^(\d+(?:[\.,]\d+)?)\s*(?:x|X|\s+(?:UN|PC|JG|M|PT|CX|PCT|KG))\s*[-–:]?\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (inlineQtyMatch != null) {
        final qty = double.tryParse(inlineQtyMatch.group(1)!.replaceAll(',', '.')) ?? 1.0;
        final name = inlineQtyMatch.group(2)!.trim();
        if (_isSolarProduct(name)) {
          final type = _detectComponentType(name);
          list.add(ParsedSolarItem(
            name: name,
            quantity: qty,
            unit: 'UN',
            unitPrice: 0.0,
            totalPrice: 0.0,
            componentType: type,
          ));
          continue;
        }
      }

      // Detecta linhas com nomes de produtos solares
      if (_isSolarProduct(line)) {
        currentName = line;
        if (i + 1 < lines.length && _isSkuCandidate(lines[i + 1])) {
          currentSku = lines[i + 1].trim();
          i++;
        }
      }
    }

    return list;
  }

  static SolarComponentType _detectComponentType(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('modulo') || lower.contains('módulo') || lower.contains('painel') || lower.contains('placa') || lower.contains('bifacial') || lower.contains('cel.') || lower.contains('half-cell')) {
      return SolarComponentType.module;
    }
    if (lower.contains('inversor') || lower.contains('microinversor') || lower.contains('mppt') || lower.contains('string box') || lower.contains('inverter')) {
      return SolarComponentType.inverter;
    }
    if (lower.contains('bateria') || lower.contains('acumulador') || lower.contains('lifepo4') || lower.contains('lithium') || lower.contains('lítio')) {
      return SolarComponentType.battery;
    }
    if (lower.contains('cabo') || lower.contains('cbsol') || lower.contains('cabos')) {
      return SolarComponentType.cable;
    }
    if (lower.contains('conector') || lower.contains('mc4') || lower.contains('conecsolar') || lower.contains('conectores')) {
      return SolarComponentType.connector;
    }
    if (lower.contains('aterramento') || lower.contains('garra') || lower.contains('dps') || lower.contains('disjuntor') || lower.contains('proteção') || lower.contains('protecao') || lower.contains('fusivel') || lower.contains('fusível')) {
      return SolarComponentType.protection;
    }
    if (lower.contains('perfil') || lower.contains('grampo') || lower.contains('gancho') || lower.contains('suporte') || lower.contains('juncao') || lower.contains('junção') || lower.contains('estrutura') || lower.contains('trilho') || lower.contains('parafuso') || lower.contains('abraçadeira')) {
      return SolarComponentType.structure;
    }

    return SolarComponentType.other;
  }

  static bool _isSolarProduct(String line) {
    final upper = line.toUpperCase();
    return upper.contains('MODULO') ||
        upper.contains('MÓDULO') ||
        upper.contains('PAINEL') ||
        upper.contains('PLACA SOLAR') ||
        upper.contains('INVERSOR') ||
        upper.contains('MICROINVERSOR') ||
        upper.contains('BATERIA') ||
        upper.contains('GARRA') ||
        upper.contains('SUPORTE') ||
        upper.contains('GRAMPO') ||
        upper.contains('JUNCAO') ||
        upper.contains('JUNÇÃO') ||
        upper.contains('PERFIL') ||
        upper.contains('TRILHO') ||
        upper.contains('CABO SOLAR') ||
        upper.contains('CABO 4MM') ||
        upper.contains('CABO 6MM') ||
        upper.contains('CONECTOR') ||
        upper.contains('MC4') ||
        upper.contains('STRING BOX') ||
        upper.contains('ATERRAMENTO');
  }

  static bool _isSkuCandidate(String line) {
    final clean = line.trim();
    if (clean.length < 3 || clean.length > 35) return false;
    if (clean.toLowerCase().startsWith('fabricante:')) return false;
    if (clean.toLowerCase().startsWith('quantidade:')) return false;
    return RegExp(r'^[A-Z0-9\.\-_]+$').hasMatch(clean);
  }

  static double _parsePrice(String str) {
    final clean = str.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}
