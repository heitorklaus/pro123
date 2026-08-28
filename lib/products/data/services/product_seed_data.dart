import '../../domain/models/product_model.dart';

/// Gerador com 200 produtos de teste realistas divididos proporcionalmente
/// entre os 20 setores comerciais mais comuns do Brasil (10 produtos por segmento).
List<Map<String, dynamic>> generate200TestProducts() {
  final List<Map<String, dynamic>> products = [];

  final sectorData = [
    // 0. Usina Solar
    {
      'sector': ProductSector.solarPlant,
      'prefix': 'SOL',
      'items': [
        {
          'name': 'Usina Solar 5.5 kWp Residencial (Microinversor + 10x 550W)',
          'sub': 'Kits Completos',
          'unit': ProductUnit.un,
          'sale': 18900.00,
          'cost': 13500.00,
          'stock': 8.0,
          'min': 2.0,
          'attrs': <String, dynamic>{
            'isSolarPlantKit': true,
            'kilowatts': 5.5,
            'roofType': 'Cerâmico',
            'productsPrice': 15900.00,
            'servicePrice': 3000.00,
            'items': [
              {
                'name': 'Painel Solar Fotovoltaico 550W Monocristalino Tier 1',
                'sku': 'SOL-003',
                'quantity': 10.0,
                'unit': 'UN',
                'unitPrice': 680.00,
                'totalPrice': 6800.00,
              },
              {
                'name': 'Microinversor Solar 2000W 4 Entradas MPPT Independentes',
                'sku': 'SOL-005',
                'quantity': 3.0,
                'unit': 'UN',
                'unitPrice': 2850.00,
                'totalPrice': 8550.00,
              },
              {
                'name': 'Estrutura de Fixação para Telhado Cerâmico (Kit 4 Módulos)',
                'sku': 'SOL-006',
                'quantity': 3.0,
                'unit': 'UN',
                'unitPrice': 183.33,
                'totalPrice': 550.00,
              },
            ],
            'additionalServices': [
              {'type': 'Instalação e Homologação', 'price': 3000.00},
            ],
          },
        },
        {
          'name': 'Usina Solar 10.0 kWp Comercial Trifásico 220V/380V',
          'sub': 'Kits Completos',
          'unit': ProductUnit.un,
          'sale': 34500.00,
          'cost': 25000.00,
          'stock': 5.0,
          'min': 1.0,
          'attrs': <String, dynamic>{
            'isSolarPlantKit': true,
            'kilowatts': 10.0,
            'roofType': 'Metálico',
            'productsPrice': 28500.00,
            'servicePrice': 6000.00,
            'items': [
              {
                'name': 'Painel Solar Fotovoltaico 550W Monocristalino Tier 1',
                'sku': 'SOL-003',
                'quantity': 18.0,
                'unit': 'UN',
                'unitPrice': 680.00,
                'totalPrice': 12240.00,
              },
              {
                'name': 'Inversor Solar On-Grid 10kW Trifásico com Wi-Fi Integrado',
                'sku': 'SOL-004',
                'quantity': 1.0,
                'unit': 'UN',
                'unitPrice': 8900.00,
                'totalPrice': 8900.00,
              },
              {
                'name': 'Estrutura de Fixação para Telha Metálica (Kit 4 Módulos)',
                'sku': 'SOL-007',
                'quantity': 5.0,
                'unit': 'UN',
                'unitPrice': 360.00,
                'totalPrice': 1800.00,
              },
              {
                'name': 'String Box Solar CC 1000V 2 Entradas / 2 Saídas',
                'sku': 'SOL-010',
                'quantity': 1.0,
                'unit': 'UN',
                'unitPrice': 690.00,
                'totalPrice': 690.00,
              },
            ],
            'additionalServices': [
              {'type': 'Engenharia, Projeto e Homologação na Concessionária', 'price': 3500.00},
              {'type': 'Instalação Elétrica e Montagem Estrutural', 'price': 2500.00},
            ],
          },
        },
        {'name': 'Painel Solar Fotovoltaico 550W Monocristalino Tier 1', 'sub': 'Módulos Solares', 'unit': ProductUnit.un, 'sale': 680.00, 'cost': 490.00, 'stock': 150.0, 'min': 30.0},
        {'name': 'Inversor Solar On-Grid 5kW Monofásico com Wi-Fi Integrado', 'sub': 'Inversores', 'unit': ProductUnit.un, 'sale': 4200.00, 'cost': 3100.00, 'stock': 12.0, 'min': 3.0},
        {'name': 'Microinversor Solar 2000W 4 Entradas MPPT Independentes', 'sub': 'Microinversores', 'unit': ProductUnit.un, 'sale': 2850.00, 'cost': 2100.00, 'stock': 18.0, 'min': 4.0},
        {'name': 'Estrutura de Fixação para Telhado Cerâmico (Kit 4 Módulos)', 'sub': 'Estruturas', 'unit': ProductUnit.un, 'sale': 420.00, 'cost': 280.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Estrutura de Fixação para Telha Metálica / Fibrocimento', 'sub': 'Estruturas', 'unit': ProductUnit.un, 'sale': 360.00, 'cost': 240.00, 'stock': 35.0, 'min': 10.0},
        {'name': 'Cabo Solar Fotovoltaico 6mm² Vermelho/Preto (Rolo 100m)', 'sub': 'Cabeamento', 'unit': ProductUnit.pct, 'sale': 520.00, 'cost': 370.00, 'stock': 25.0, 'min': 5.0},
        {'name': 'Par de Conectores MC4 Macho/Fêmea 1000V/1500V DC (10 Pares)', 'sub': 'Conectores', 'unit': ProductUnit.pct, 'sale': 65.00, 'cost': 35.00, 'stock': 80.0, 'min': 20.0},
        {'name': 'String Box Solar CC 1000V 2 Entradas / 2 Saídas com DPS', 'sub': 'Proteção Elétrica', 'unit': ProductUnit.un, 'sale': 690.00, 'cost': 450.00, 'stock': 20.0, 'min': 5.0},
      ],
    },

    // 1. Limpeza & Higiene
    {
      'sector': ProductSector.cleaning,
      'prefix': 'LIM',
      'items': [
        {'name': 'Detergente Líquido Neutro 5 Litros', 'sub': 'Detergentes', 'unit': ProductUnit.lt, 'sale': 28.90, 'cost': 14.50, 'stock': 45.0, 'min': 10.0},
        {'name': 'Desinfetante Floral Concentrado 5L', 'sub': 'Desinfetantes', 'unit': ProductUnit.lt, 'sale': 32.50, 'cost': 16.00, 'stock': 38.0, 'min': 10.0},
        {'name': 'Água Sanitária 5L com Bico Dosador', 'sub': 'Alvejantes', 'unit': ProductUnit.lt, 'sale': 19.90, 'cost': 9.80, 'stock': 60.0, 'min': 15.0},
        {'name': 'Sabão Líquido Lava Roupas Premium 5L', 'sub': 'Lavanderia', 'unit': ProductUnit.lt, 'sale': 46.90, 'cost': 24.00, 'stock': 25.0, 'min': 8.0},
        {'name': 'Amaciante de Roupas Toque de Maciez 5L', 'sub': 'Lavanderia', 'unit': ProductUnit.lt, 'sale': 38.90, 'cost': 19.50, 'stock': 30.0, 'min': 10.0},
        {'name': 'Desengordurante Industrial Alta Eficiência 5L', 'sub': 'Desengordurantes', 'unit': ProductUnit.lt, 'sale': 54.00, 'cost': 28.00, 'stock': 18.0, 'min': 5.0},
        {'name': 'Limpa Vidros Anti-embaçante 500ml Gatilho', 'sub': 'Superfícies', 'unit': ProductUnit.un, 'sale': 12.90, 'cost': 5.80, 'stock': 75.0, 'min': 20.0},
        {'name': 'Saco de Lixo Reforçado 100L (Fardo c/ 100un)', 'sub': 'Descartáveis', 'unit': ProductUnit.pct, 'sale': 42.00, 'cost': 22.00, 'stock': 50.0, 'min': 12.0},
        {'name': 'Papel Toalha Interfolhado 2 Dobras (Pct 1000fls)', 'sub': 'Papéis', 'unit': ProductUnit.pct, 'sale': 26.50, 'cost': 13.90, 'stock': 40.0, 'min': 10.0},
        {'name': 'Álcool em Gel 70% Antisséptico 1 Litro', 'sub': 'Higiene das Mãos', 'unit': ProductUnit.un, 'sale': 15.90, 'cost': 7.50, 'stock': 85.0, 'min': 25.0},
      ],
    },

    // 2. Alimentos & Mercearia
    {
      'sector': ProductSector.food,
      'prefix': 'ALI',
      'items': [
        {'name': 'Arroz Tipo 1 Grão Nobre Pacote 5kg', 'sub': 'Grãos e Cereais', 'unit': ProductUnit.pct, 'sale': 29.90, 'cost': 21.50, 'stock': 120.0, 'min': 30.0},
        {'name': 'Feijão Carioca Selecionado 1kg', 'sub': 'Grãos e Cereais', 'unit': ProductUnit.pct, 'sale': 8.90, 'cost': 5.80, 'stock': 95.0, 'min': 25.0},
        {'name': 'Azeite de Oliva Extra Virgem 500ml Vidro', 'sub': 'Óleos e Condimentos', 'unit': ProductUnit.un, 'sale': 39.90, 'cost': 27.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Café Torrado e Moído Gourmet 500g', 'sub': 'Matinais', 'unit': ProductUnit.pct, 'sale': 22.50, 'cost': 14.80, 'stock': 65.0, 'min': 15.0},
        {'name': 'Açúcar Cristal Pacote 5kg', 'sub': 'Mercearia', 'unit': ProductUnit.pct, 'sale': 18.90, 'cost': 13.20, 'stock': 80.0, 'min': 20.0},
        {'name': 'Macarrão Espaguete Grano Duro 500g', 'sub': 'Massas', 'unit': ProductUnit.pct, 'sale': 9.50, 'cost': 5.90, 'stock': 110.0, 'min': 30.0},
        {'name': 'Molho de Tomate Tradicional Sachê 300g', 'sub': 'Molhos', 'unit': ProductUnit.un, 'sale': 3.80, 'cost': 2.10, 'stock': 150.0, 'min': 40.0},
        {'name': 'Leite Integral UHT Caixa com 12 Litros', 'sub': 'Laticínios', 'unit': ProductUnit.cx, 'sale': 58.90, 'cost': 43.50, 'stock': 35.0, 'min': 10.0},
        {'name': 'Farinha de Trigo Especial 1kg', 'sub': 'Farinhas', 'unit': ProductUnit.pct, 'sale': 5.50, 'cost': 3.40, 'stock': 90.0, 'min': 20.0},
        {'name': 'Biscoito Recheado Chocolate 130g', 'sub': 'Biscoitos e Snacks', 'unit': ProductUnit.un, 'sale': 4.20, 'cost': 2.40, 'stock': 130.0, 'min': 35.0},
      ],
    },

    // 3. Moda & Vestuário
    {
      'sector': ProductSector.fashion,
      'prefix': 'MOD',
      'items': [
        {'name': 'Camiseta Básica Algodão Egípcio Masculina', 'sub': 'Camisetas', 'unit': ProductUnit.un, 'sale': 79.90, 'cost': 34.00, 'stock': 55.0, 'min': 15.0},
        {'name': 'Calça Jeans Skinny Feminina com Elastano', 'sub': 'Calças', 'unit': ProductUnit.un, 'sale': 149.90, 'cost': 68.00, 'stock': 32.0, 'min': 10.0},
        {'name': 'Vestido Midi Estampa Floral Verão', 'sub': 'Vestidos', 'unit': ProductUnit.un, 'sale': 189.00, 'cost': 85.00, 'stock': 20.0, 'min': 5.0},
        {'name': 'Camisa Social Manga Longa Slim Fit', 'sub': 'Camisas', 'unit': ProductUnit.un, 'sale': 139.90, 'cost': 58.00, 'stock': 28.0, 'min': 8.0},
        {'name': 'Bermuda Sarja Masculina Casual', 'sub': 'Bermudas', 'unit': ProductUnit.un, 'sale': 99.90, 'cost': 42.00, 'stock': 40.0, 'min': 12.0},
        {'name': 'Jaqueta Corta-Vento Esportiva Unissex', 'sub': 'Casacos', 'unit': ProductUnit.un, 'sale': 169.90, 'cost': 75.00, 'stock': 18.0, 'min': 5.0},
        {'name': 'Tênis Casual Slip-On Conforto', 'sub': 'Calçados', 'unit': ProductUnit.par, 'sale': 199.90, 'cost': 92.00, 'stock': 24.0, 'min': 6.0},
        {'name': 'Meia Soquete Algodão (Kit com 3 pares)', 'sub': 'Acessórios', 'unit': ProductUnit.pct, 'sale': 24.90, 'cost': 9.80, 'stock': 85.0, 'min': 20.0},
        {'name': 'Cinto Masculino Couro Legítimo Dupla Face', 'sub': 'Acessórios', 'unit': ProductUnit.un, 'sale': 69.90, 'cost': 28.00, 'stock': 30.0, 'min': 8.0},
        {'name': 'Blusa de Tricot Gola Alta Feminina', 'sub': 'Inverno', 'unit': ProductUnit.un, 'sale': 129.90, 'cost': 55.00, 'stock': 22.0, 'min': 6.0},
      ],
    },

    // 4. Material de Construção
    {
      'sector': ProductSector.construction,
      'prefix': 'MAT',
      'items': [
        {'name': 'Cimento Portland CP-II 50kg', 'sub': 'Básico', 'unit': ProductUnit.un, 'sale': 36.90, 'cost': 26.50, 'stock': 150.0, 'min': 40.0},
        {'name': 'Tinta Látex Acrílica Fosca Branco Neve 18L', 'sub': 'Tintas e Vernizes', 'unit': ProductUnit.un, 'sale': 289.00, 'cost': 165.00, 'stock': 22.0, 'min': 6.0},
        {'name': 'Argamassa AC-III Piso Sobre Piso 20kg', 'sub': 'Argamassas', 'unit': ProductUnit.un, 'sale': 34.50, 'cost': 21.00, 'stock': 70.0, 'min': 20.0},
        {'name': 'Porcelanato Polido Retificado 60x60 (Caixa 1.80m²)', 'sub': 'Pisos e Revestimentos', 'unit': ProductUnit.cx, 'sale': 98.90, 'cost': 56.00, 'stock': 45.0, 'min': 15.0},
        {'name': 'Tubo PVC Soldável para Água Fria 25mm 6m', 'sub': 'Hidráulica', 'unit': ProductUnit.un, 'sale': 23.90, 'cost': 13.50, 'stock': 80.0, 'min': 25.0},
        {'name': 'Fio Cabo Flexível 2,5mm 750V Rolo 100m Azul', 'sub': 'Elétrica', 'unit': ProductUnit.pct, 'sale': 189.00, 'cost': 118.00, 'stock': 28.0, 'min': 8.0},
        {'name': 'Disjuntor Bipolar Din 32A Curva C', 'sub': 'Elétrica', 'unit': ProductUnit.un, 'sale': 32.90, 'cost': 16.50, 'stock': 50.0, 'min': 15.0},
        {'name': 'Torneira Monocomando para Bancada Cromada', 'sub': 'Metais Sanitários', 'unit': ProductUnit.un, 'sale': 149.00, 'cost': 72.00, 'stock': 16.0, 'min': 5.0},
        {'name': 'Lâmpada LED Bulbo 12W Bivolt 6500K Branco Frio', 'sub': 'Iluminação', 'unit': ProductUnit.un, 'sale': 11.90, 'cost': 5.20, 'stock': 120.0, 'min': 30.0},
        {'name': 'Impermeabilizante Asfáltico para Lajes 18L', 'sub': 'Impermeabilização', 'unit': ProductUnit.un, 'sale': 245.00, 'cost': 142.00, 'stock': 14.0, 'min': 4.0},
      ],
    },

    // 5. Farmácia & Cosméticos
    {
      'sector': ProductSector.pharmacy,
      'prefix': 'FAR',
      'items': [
        {'name': 'Protetor Solar Facial Toque Seco FPS 50 50g', 'sub': 'Dermocosméticos', 'unit': ProductUnit.un, 'sale': 68.90, 'cost': 38.00, 'stock': 35.0, 'min': 10.0},
        {'name': 'Vitamina C Pura com Zinco Efervescente 30 comp', 'sub': 'Suplementos', 'unit': ProductUnit.un, 'sale': 34.90, 'cost': 17.50, 'stock': 60.0, 'min': 15.0},
        {'name': 'Shampoo Antiqueda e Fortalecedor 300ml', 'sub': 'Cabelos', 'unit': ProductUnit.un, 'sale': 42.00, 'cost': 22.00, 'stock': 48.0, 'min': 12.0},
        {'name': 'Hidratante Corporal Pele Seca com Ceramidas 400ml', 'sub': 'Corpo', 'unit': ProductUnit.un, 'sale': 52.90, 'cost': 28.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Fralda Descartável Conforto Tamanho G (Pct c/ 48)', 'sub': 'Infantil', 'unit': ProductUnit.pct, 'sale': 59.90, 'cost': 39.00, 'stock': 50.0, 'min': 15.0},
        {'name': 'Sabonete Líquido Íntimo Suave 200ml', 'sub': 'Higiene', 'unit': ProductUnit.un, 'sale': 18.50, 'cost': 9.20, 'stock': 65.0, 'min': 18.0},
        {'name': 'Enxaguante Bucal Antisséptico Menta 500ml', 'sub': 'Higiene Bucal', 'unit': ProductUnit.un, 'sale': 23.90, 'cost': 12.50, 'stock': 70.0, 'min': 20.0},
        {'name': 'Soro Fisiológico 0,9% 500ml', 'sub': 'Primeiros Socorros', 'unit': ProductUnit.un, 'sale': 7.90, 'cost': 3.40, 'stock': 110.0, 'min': 30.0},
        {'name': 'Termômetro Digital Clínico Ponta Flexível', 'sub': 'Aparelhos', 'unit': ProductUnit.un, 'sale': 28.00, 'cost': 12.50, 'stock': 32.0, 'min': 8.0},
        {'name': 'Curativo Adesivo Flexível Caixa c/ 30 Unidades', 'sub': 'Primeiros Socorros', 'unit': ProductUnit.cx, 'sale': 9.90, 'cost': 4.10, 'stock': 95.0, 'min': 25.0},
      ],
    },

    // 6. Informática & Eletrônicos
    {
      'sector': ProductSector.tech,
      'prefix': 'TEC',
      'items': [
        {'name': 'Teclado Mecânico Gamer RGB Switch Blue ABNT2', 'sub': 'Periféricos', 'unit': ProductUnit.un, 'sale': 249.00, 'cost': 135.00, 'stock': 20.0, 'min': 5.0},
        {'name': 'Mouse Sem Fio Ergonômico 1600 DPI Recarregável', 'sub': 'Periféricos', 'unit': ProductUnit.un, 'sale': 89.90, 'cost': 42.00, 'stock': 45.0, 'min': 12.0},
        {'name': 'SSD NVMe M.2 1TB Leitura 3500MB/s', 'sub': 'Armazenamento', 'unit': ProductUnit.un, 'sale': 389.00, 'cost': 245.00, 'stock': 18.0, 'min': 5.0},
        {'name': 'Monitor LED 24 Polegadas Full HD 75Hz HDMI/VGA', 'sub': 'Monitores', 'unit': ProductUnit.un, 'sale': 649.00, 'cost': 430.00, 'stock': 12.0, 'min': 3.0},
        {'name': 'Headset Gamer com Microfone Noise Cancelling', 'sub': 'Áudio', 'unit': ProductUnit.un, 'sale': 179.90, 'cost': 88.00, 'stock': 26.0, 'min': 6.0},
        {'name': 'Roteador Wi-Fi 6 Gigabit Dual Band AX1800', 'sub': 'Redes', 'unit': ProductUnit.un, 'sale': 299.00, 'cost': 175.00, 'stock': 15.0, 'min': 4.0},
        {'name': 'Cabo HDMI 2.1 Ultra High Speed 4K/8K 2 Metros', 'sub': 'Cabos e Conectores', 'unit': ProductUnit.un, 'sale': 45.00, 'cost': 18.00, 'stock': 60.0, 'min': 15.0},
        {'name': 'Webcam Full HD 1080p com Microfone Embutido', 'sub': 'Vídeo', 'unit': ProductUnit.un, 'sale': 159.00, 'cost': 78.00, 'stock': 22.0, 'min': 6.0},
        {'name': 'Pen Drive USB 3.0 128GB Resistente a Choque', 'sub': 'Armazenamento', 'unit': ProductUnit.un, 'sale': 58.00, 'cost': 29.00, 'stock': 50.0, 'min': 15.0},
        {'name': 'Filtro de Linha 6 Tomadas Bivolt com Proteção DPS', 'sub': 'Energia', 'unit': ProductUnit.un, 'sale': 49.90, 'cost': 23.50, 'stock': 40.0, 'min': 10.0},
      ],
    },

    // 7. Autopeças & Manutenção
    {
      'sector': ProductSector.autoparts,
      'prefix': 'AUT',
      'items': [
        {'name': 'Óleo de Motor 5W30 100% Sintético 1 Litro', 'sub': 'Lubrificantes', 'unit': ProductUnit.lt, 'sale': 48.90, 'cost': 28.00, 'stock': 85.0, 'min': 20.0},
        {'name': 'Pastilha de Freio Dianteira Cerâmica (Jogo)', 'sub': 'Freios', 'unit': ProductUnit.pct, 'sale': 129.00, 'cost': 68.00, 'stock': 24.0, 'min': 6.0},
        {'name': 'Filtro de Óleo Blindado Motor 1.0/1.6', 'sub': 'Filtros', 'unit': ProductUnit.un, 'sale': 32.00, 'cost': 14.50, 'stock': 65.0, 'min': 15.0},
        {'name': 'Aditivo de Radiador Concentrado Orgânico 1L', 'sub': 'Arrefecimento', 'unit': ProductUnit.un, 'sale': 36.50, 'cost': 18.00, 'stock': 50.0, 'min': 12.0},
        {'name': 'Bateria Automotiva 60Ah Livre de Manutenção', 'sub': 'Elétrica', 'unit': ProductUnit.un, 'sale': 449.00, 'cost': 280.00, 'stock': 14.0, 'min': 4.0},
        {'name': 'Jogo de Velas de Ignição Iridium (4 Unidades)', 'sub': 'Ignição', 'unit': ProductUnit.pct, 'sale': 169.00, 'cost': 92.00, 'stock': 20.0, 'min': 5.0},
        {'name': 'Palheta Limpador de Para-brisa Silicone 22 Pol', 'sub': 'Acessórios', 'unit': ProductUnit.par, 'sale': 45.00, 'cost': 19.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Lâmpada Automotiva H4 Super Branca 55W 12V (Par)', 'sub': 'Iluminação', 'unit': ProductUnit.par, 'sale': 79.90, 'cost': 38.00, 'stock': 30.0, 'min': 8.0},
        {'name': 'Fluido de Freio DOT 4 Alta Performance 500ml', 'sub': 'Freios', 'unit': ProductUnit.un, 'sale': 29.90, 'cost': 14.20, 'stock': 45.0, 'min': 12.0},
        {'name': 'Desengripante Spray Aerossol Multiuso 300ml', 'sub': 'Químicos', 'unit': ProductUnit.un, 'sale': 18.90, 'cost': 8.50, 'stock': 90.0, 'min': 25.0},
      ],
    },

    // 8. Papelaria & Escritório
    {
      'sector': ProductSector.stationery,
      'prefix': 'PAP',
      'items': [
        {'name': 'Papel Sulfite A4 75g Caixa com 5 Resmas (2500fls)', 'sub': 'Papéis', 'unit': ProductUnit.cx, 'sale': 139.90, 'cost': 98.00, 'stock': 30.0, 'min': 10.0},
        {'name': 'Caderno Universitário Espiral 10 Matérias 160fls', 'sub': 'Cadernos', 'unit': ProductUnit.un, 'sale': 24.90, 'cost': 12.00, 'stock': 75.0, 'min': 20.0},
        {'name': 'Caneta Esferográfica Azul 1.0mm (Caixa c/ 50un)', 'sub': 'Escrita', 'unit': ProductUnit.cx, 'sale': 48.00, 'cost': 24.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Marca Texto Pastel com 6 Cores Sortidas', 'sub': 'Escrita', 'unit': ProductUnit.pct, 'sale': 29.90, 'cost': 13.50, 'stock': 60.0, 'min': 15.0},
        {'name': 'Grampeador de Mesa Médio Metal 26/6', 'sub': 'Organização', 'unit': ProductUnit.un, 'sale': 34.00, 'cost': 16.00, 'stock': 35.0, 'min': 8.0},
        {'name': 'Pasta Sanfonada A4 com 12 Divisórias Plásticas', 'sub': 'Arquivos', 'unit': ProductUnit.un, 'sale': 28.50, 'cost': 13.20, 'stock': 45.0, 'min': 10.0},
        {'name': 'Calculadora Científica 240 Funções Display Duplo', 'sub': 'Eletrônicos', 'unit': ProductUnit.un, 'sale': 59.90, 'cost': 28.00, 'stock': 25.0, 'min': 6.0},
        {'name': 'Fita Adesiva Transparente Larga 45mm x 50m', 'sub': 'Embalagem', 'unit': ProductUnit.un, 'sale': 6.50, 'cost': 2.80, 'stock': 120.0, 'min': 30.0},
        {'name': 'Bloco de Notas Autoadesivas 76x76mm Amarelo', 'sub': 'Anotações', 'unit': ProductUnit.pct, 'sale': 7.90, 'cost': 3.20, 'stock': 90.0, 'min': 25.0},
        {'name': 'Tesoura Escolar Inox sem Ponta com Régua', 'sub': 'Corte', 'unit': ProductUnit.un, 'sale': 8.90, 'cost': 3.80, 'stock': 70.0, 'min': 18.0},
      ],
    },

    // 9. Pet Shop
    {
      'sector': ProductSector.pet,
      'prefix': 'PET',
      'items': [
        {'name': 'Ração Super Premium Cães Adultos Porte Médio 15kg', 'sub': 'Alimentação Cães', 'unit': ProductUnit.pct, 'sale': 259.00, 'cost': 168.00, 'stock': 25.0, 'min': 8.0},
        {'name': 'Ração Premium Gatos Castrados Salmão 10kg', 'sub': 'Alimentação Gatos', 'unit': ProductUnit.pct, 'sale': 189.00, 'cost': 118.00, 'stock': 30.0, 'min': 10.0},
        {'name': 'Tapete Higiênico Super Absorvente 60x80 (Pct 30un)', 'sub': 'Higiene', 'unit': ProductUnit.pct, 'sale': 79.90, 'cost': 44.00, 'stock': 40.0, 'min': 12.0},
        {'name': 'Antipulgas e Carrapatos Comprimido Mastigável Cão 10-20kg', 'sub': 'Medicamentos', 'unit': ProductUnit.un, 'sale': 119.00, 'cost': 72.00, 'stock': 35.0, 'min': 8.0},
        {'name': 'Areia Sanitária Sílica para Gatos 3,8kg', 'sub': 'Higiene Gatos', 'unit': ProductUnit.pct, 'sale': 49.90, 'cost': 26.00, 'stock': 45.0, 'min': 10.0},
        {'name': 'Shampoo e Condicionador Pet Hipoalergênico 500ml', 'sub': 'Banho e Tosa', 'unit': ProductUnit.un, 'sale': 34.00, 'cost': 15.50, 'stock': 50.0, 'min': 15.0},
        {'name': 'Brinquedo Mordedor Resistente com Apito', 'sub': 'Brinquedos', 'unit': ProductUnit.un, 'sale': 26.00, 'cost': 10.80, 'stock': 60.0, 'min': 15.0},
        {'name': 'Caminha Pet Conforto Lavável Tamanho G', 'sub': 'Acessórios', 'unit': ProductUnit.un, 'sale': 149.00, 'cost': 74.00, 'stock': 15.0, 'min': 4.0},
        {'name': 'Guia Retrátil para Passeio 5 Metros até 25kg', 'sub': 'Passeio', 'unit': ProductUnit.un, 'sale': 68.00, 'cost': 31.00, 'stock': 28.0, 'min': 6.0},
        {'name': 'Petisco Bifinho de Carne para Cães 500g', 'sub': 'Petiscos', 'unit': ProductUnit.pct, 'sale': 19.90, 'cost': 9.20, 'stock': 80.0, 'min': 20.0},
      ],
    },

    // 10. Móveis & Decoração
    {
      'sector': ProductSector.furniture,
      'prefix': 'MOV',
      'items': [
        {'name': 'Cadeira Gamer Ergonômica com Apoio de Braço 3D', 'sub': 'Escritório', 'unit': ProductUnit.un, 'sale': 899.00, 'cost': 540.00, 'stock': 10.0, 'min': 2.0},
        {'name': 'Mesa para Computador em L com Gaveteiro', 'sub': 'Escritório', 'unit': ProductUnit.un, 'sale': 549.00, 'cost': 310.00, 'stock': 8.0, 'min': 2.0},
        {'name': 'Poltrona Decorativa Pés Palito Tecido Suede', 'sub': 'Sala de Estar', 'unit': ProductUnit.un, 'sale': 429.00, 'cost': 240.00, 'stock': 12.0, 'min': 3.0},
        {'name': 'Rack para TV até 65 Polegadas com LED', 'sub': 'Sala de Estar', 'unit': ProductUnit.un, 'sale': 689.00, 'cost': 395.00, 'stock': 6.0, 'min': 2.0},
        {'name': 'Luminária de Chão Tripé Madeira com Cúpula', 'sub': 'Iluminação Decorativa', 'unit': ProductUnit.un, 'sale': 249.00, 'cost': 125.00, 'stock': 15.0, 'min': 4.0},
        {'name': 'Quadro Decorativo Abstrato Canvas 120x80cm', 'sub': 'Quadros', 'unit': ProductUnit.un, 'sale': 189.00, 'cost': 82.00, 'stock': 20.0, 'min': 5.0},
        {'name': 'Espelho Redondo Adnet com Alça de Couro 60cm', 'sub': 'Espelhos', 'unit': ProductUnit.un, 'sale': 149.00, 'cost': 68.00, 'stock': 18.0, 'min': 4.0},
        {'name': 'Tapete Sala de Estar Aveludado Geométrico 200x250', 'sub': 'Tapetes', 'unit': ProductUnit.un, 'sale': 379.00, 'cost': 195.00, 'stock': 9.0, 'min': 2.0},
        {'name': 'Mesa Lateral de Apoio Redonda Tampo Off-White', 'sub': 'Mesas', 'unit': ProductUnit.un, 'sale': 129.00, 'cost': 58.00, 'stock': 22.0, 'min': 5.0},
        {'name': 'Cortina Blecaute em Tecido com Ilhós 3,00x2,60m', 'sub': 'Cortinas', 'unit': ProductUnit.un, 'sale': 219.00, 'cost': 105.00, 'stock': 14.0, 'min': 3.0},
      ],
    },

    // 11. Restaurantes & Delivery
    {
      'sector': ProductSector.restaurant,
      'prefix': 'RES',
      'items': [
        {'name': 'Hambúrguer Artesanal Blend 180g com Queijo Cheddar', 'sub': 'Lanches', 'unit': ProductUnit.un, 'sale': 36.90, 'cost': 14.50, 'stock': 50.0, 'min': 15.0},
        {'name': 'Pizza Grande Especial Calabresa com Catupiry', 'sub': 'Pizzas', 'unit': ProductUnit.un, 'sale': 64.90, 'cost': 24.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Porção de Batata Frita Rústica Crocante 500g', 'sub': 'Porções', 'unit': ProductUnit.un, 'sale': 28.00, 'cost': 8.50, 'stock': 60.0, 'min': 15.0},
        {'name': 'Marmitex Executivo Filé de Frango Grelhado', 'sub': 'Almoço', 'unit': ProductUnit.un, 'sale': 24.50, 'cost': 9.80, 'stock': 70.0, 'min': 20.0},
        {'name': 'Refrigerante Lata 350ml Diversos Sabores', 'sub': 'Bebidas', 'unit': ProductUnit.un, 'sale': 6.50, 'cost': 3.10, 'stock': 150.0, 'min': 40.0},
        {'name': 'Suco Natural de Laranja Garrafa 1 Litro', 'sub': 'Bebidas Naturais', 'unit': ProductUnit.lt, 'sale': 16.00, 'cost': 6.20, 'stock': 35.0, 'min': 10.0},
        {'name': 'Cerveja Artesanal IPA Long Neck 355ml', 'sub': 'Bebidas Alcoólicas', 'unit': ProductUnit.un, 'sale': 18.90, 'cost': 8.90, 'stock': 80.0, 'min': 20.0},
        {'name': 'Sobremesa Petit Gâteau com Sorvete de Creme', 'sub': 'Sobremesas', 'unit': ProductUnit.un, 'sale': 22.00, 'cost': 7.50, 'stock': 45.0, 'min': 10.0},
        {'name': 'Combo 2 Burgers + Batata + 2 Refris', 'sub': 'Combos Promocionais', 'unit': ProductUnit.un, 'sale': 89.90, 'cost': 36.00, 'stock': 30.0, 'min': 8.0},
        {'name': 'Molho Especial da Casa Frasco 250ml', 'sub': 'Acompanhamentos', 'unit': ProductUnit.un, 'sale': 12.00, 'cost': 4.20, 'stock': 55.0, 'min': 15.0},
      ],
    },

    // 12. Serviços Gerais & Facilities
    {
      'sector': ProductSector.generalServices,
      'prefix': 'SER',
      'items': [
        {'name': 'Serviço de Limpeza Pós-Obra Residencial/Comercial', 'sub': 'Limpeza Técnica', 'unit': ProductUnit.sv, 'sale': 450.00, 'cost': 180.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Instalação e Manutenção de Ar Condicionado Split', 'sub': 'Climatização', 'unit': ProductUnit.sv, 'sale': 350.00, 'cost': 120.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Consultoria em Gestão de Processos e Produtividade', 'sub': 'Consultorias', 'unit': ProductUnit.hr, 'sale': 180.00, 'cost': 60.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Higienização e Impermeabilização de Estofados', 'sub': 'Higienização', 'unit': ProductUnit.sv, 'sale': 280.00, 'cost': 95.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Serviço de Pintura Imobiliária Interna por m²', 'sub': 'Pintura', 'unit': ProductUnit.m2, 'sale': 28.00, 'cost': 11.00, 'stock': 999.0, 'min': 50.0},
        {'name': 'Manutenção Elétrica Preventiva e Corretiva', 'sub': 'Elétrica Predial', 'unit': ProductUnit.hr, 'sale': 120.00, 'cost': 45.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Dedetização e Controle de Pragas Urbanas', 'sub': 'Dedetização', 'unit': ProductUnit.sv, 'sale': 320.00, 'cost': 110.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Instalação de Câmeras CFTV e Segurança Eletrônica', 'sub': 'Segurança', 'unit': ProductUnit.sv, 'sale': 480.00, 'cost': 190.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Desentupimento de Tubulações e Esgoto', 'sub': 'Desentupimentos', 'unit': ProductUnit.sv, 'sale': 250.00, 'cost': 80.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Serviço de Montagem e Desmontagem de Móveis', 'sub': 'Montagem', 'unit': ProductUnit.sv, 'sale': 150.00, 'cost': 50.00, 'stock': 99.0, 'min': 5.0},
      ],
    },

    // 13. Saúde & Estética
    {
      'sector': ProductSector.healthServices,
      'prefix': 'SAU',
      'items': [
        {'name': 'Sessão de Limpeza de Pele Profunda com Fototerapia', 'sub': 'Estética Facial', 'unit': ProductUnit.sv, 'sale': 160.00, 'cost': 45.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Consulta com Nutricionista Esportiva + Bioimpedância', 'sub': 'Nutrição', 'unit': ProductUnit.sv, 'sale': 220.00, 'cost': 80.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Sessão de Drenagem Linfática Corporal Manual', 'sub': 'Massoterapia', 'unit': ProductUnit.sv, 'sale': 130.00, 'cost': 40.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Aplicação de Toxina Botulínica (Botox) por Região', 'sub': 'Harmonização', 'unit': ProductUnit.sv, 'sale': 850.00, 'cost': 380.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Sessão de Depilação a Laser Soprano Ice', 'sub': 'Laser', 'unit': ProductUnit.sv, 'sale': 190.00, 'cost': 65.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Procedimento de Clareamento Dental a Laser', 'sub': 'Odontologia', 'unit': ProductUnit.sv, 'sale': 600.00, 'cost': 210.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Sessão de Fisioterapia e Reabilitação Postural', 'sub': 'Fisioterapia', 'unit': ProductUnit.sv, 'sale': 140.00, 'cost': 50.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Massagem Relaxante com Pedras Quentes 60min', 'sub': 'SPA', 'unit': ProductUnit.sv, 'sale': 170.00, 'cost': 55.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Design de Sobrancelhas com Henna e Epilação', 'sub': 'Estética', 'unit': ProductUnit.sv, 'sale': 65.00, 'cost': 18.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Tratamento de Microagulhamento com Drug Delivery', 'sub': 'Estética Avançada', 'unit': ProductUnit.sv, 'sale': 350.00, 'cost': 120.00, 'stock': 99.0, 'min': 5.0},
      ],
    },

    // 14. Educação & Treinamentos
    {
      'sector': ProductSector.education,
      'prefix': 'EDU',
      'items': [
        {'name': 'Curso Online de Gestão Comercial e Vendas B2B', 'sub': 'Cursos Online', 'unit': ProductUnit.un, 'sale': 497.00, 'cost': 80.00, 'stock': 999.0, 'min': 10.0},
        {'name': 'Workshop Presencial de Oratória e Apresentações', 'sub': 'Workshops', 'unit': ProductUnit.un, 'sale': 350.00, 'cost': 110.00, 'stock': 30.0, 'min': 5.0},
        {'name': 'Mentoria Individual de Carreira e Liderança (4 Encontros)', 'sub': 'Mentorias', 'unit': ProductUnit.un, 'sale': 1200.00, 'cost': 300.00, 'stock': 10.0, 'min': 2.0},
        {'name': 'Curso de Marketing Digital e Tráfego Pago 2026', 'sub': 'Cursos Online', 'unit': ProductUnit.un, 'sale': 697.00, 'cost': 95.00, 'stock': 999.0, 'min': 10.0},
        {'name': 'Treinamento Corporativo de Atendimento ao Cliente (In Company)', 'sub': 'Treinamentos', 'unit': ProductUnit.sv, 'sale': 2500.00, 'cost': 600.00, 'stock': 99.0, 'min': 2.0},
        {'name': 'Aulas Particulares de Inglês Instrumental para Negócios', 'sub': 'Idiomas', 'unit': ProductUnit.hr, 'sale': 95.00, 'cost': 35.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Apostila Completa Preparatória em PDF com Questões', 'sub': 'Materiais Didáticos', 'unit': ProductUnit.un, 'sale': 49.90, 'cost': 10.00, 'stock': 999.0, 'min': 20.0},
        {'name': 'Bootcamp de Programação Flutter e Dart Avançado', 'sub': 'Tecnologia', 'unit': ProductUnit.un, 'sale': 890.00, 'cost': 150.00, 'stock': 50.0, 'min': 5.0},
        {'name': 'Curso de Excel Avançado e Dashboards Corporativos', 'sub': 'Softwares', 'unit': ProductUnit.un, 'sale': 299.00, 'cost': 45.00, 'stock': 999.0, 'min': 10.0},
        {'name': 'Certificação Profissional em Gestão Ágil Scrum', 'sub': 'Certificações', 'unit': ProductUnit.un, 'sale': 550.00, 'cost': 120.00, 'stock': 99.0, 'min': 5.0},
      ],
    },

    // 15. Oficina Mecânica
    {
      'sector': ProductSector.mechanic,
      'prefix': 'MEC',
      'items': [
        {'name': 'Serviço de Alinhamento 3D e Balanceamento 4 Rodas', 'sub': 'Alinhamento', 'unit': ProductUnit.sv, 'sale': 120.00, 'cost': 35.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Mão de Obra de Troca de Correia Dentada e Tensores', 'sub': 'Motor', 'unit': ProductUnit.sv, 'sale': 280.00, 'cost': 90.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Higienização de Ar Condicionado Automotivo com Ozônio', 'sub': 'Ar Condicionado', 'unit': ProductUnit.sv, 'sale': 90.00, 'cost': 25.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Limpeza de Bicos Injetores por Ultrassom', 'sub': 'Injeção Eletrônica', 'unit': ProductUnit.sv, 'sale': 150.00, 'cost': 40.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Revisão Preventiva de Freios e Troca de Fluido', 'sub': 'Freios', 'unit': ProductUnit.sv, 'sale': 180.00, 'cost': 55.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Diagnóstico Eletrônico Computadorizado com Scanner', 'sub': 'Diagnósticos', 'unit': ProductUnit.sv, 'sale': 100.00, 'cost': 20.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Mão de Obra de Troca de Amortecedores Dianteiros', 'sub': 'Suspensão', 'unit': ProductUnit.sv, 'sale': 220.00, 'cost': 70.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Polimento Técnico e Cristalização de Pintura', 'sub': 'Estética Automotiva', 'unit': ProductUnit.sv, 'sale': 450.00, 'cost': 140.00, 'stock': 99.0, 'min': 3.0},
        {'name': 'Regulagem Eletrônica de Faróis com Luxímetro', 'sub': 'Iluminação', 'unit': ProductUnit.sv, 'sale': 60.00, 'cost': 15.00, 'stock': 99.0, 'min': 5.0},
        {'name': 'Sangria e Substituição do Líquido de Arrefecimento', 'sub': 'Arrefecimento', 'unit': ProductUnit.sv, 'sale': 110.00, 'cost': 35.00, 'stock': 99.0, 'min': 5.0},
      ],
    },

    // 16. Gráfica & Brindes
    {
      'sector': ProductSector.printing,
      'prefix': 'GRA',
      'items': [
        {'name': 'Cartão de Visita Couché 300g Laminação Fosca (Milheiro)', 'sub': 'Impressos', 'unit': ProductUnit.pct, 'sale': 89.90, 'cost': 42.00, 'stock': 60.0, 'min': 15.0},
        {'name': 'Banner em Lona 440g com Bastão e Corda 100x80cm', 'sub': 'Comunicação Visual', 'unit': ProductUnit.un, 'sale': 65.00, 'cost': 26.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Panfletos / Flyers Couché 90g 10x15cm (2500 unidades)', 'sub': 'Impressos', 'unit': ProductUnit.pct, 'sale': 145.00, 'cost': 78.00, 'stock': 30.0, 'min': 8.0},
        {'name': 'Adesivo Vinil Personalizado Corte Especial (m²)', 'sub': 'Adesivos', 'unit': ProductUnit.m2, 'sale': 55.00, 'cost': 22.00, 'stock': 80.0, 'min': 20.0},
        {'name': 'Caneca de Porcelana Personalizada Sublimação 325ml', 'sub': 'Brindes', 'unit': ProductUnit.un, 'sale': 28.00, 'cost': 11.50, 'stock': 120.0, 'min': 30.0},
        {'name': 'Placa em ACM 3mm com Vinil Impresso 100x50cm', 'sub': 'Fachadas', 'unit': ProductUnit.un, 'sale': 180.00, 'cost': 85.00, 'stock': 25.0, 'min': 5.0},
        {'name': 'Bloco de Pedidos / Receituário 100 folhas 1x0', 'sub': 'Papelaria Personalizada', 'unit': ProductUnit.un, 'sale': 14.50, 'cost': 5.80, 'stock': 100.0, 'min': 25.0},
        {'name': 'Agenda Corporativa Personalizada Capa Dura 2026', 'sub': 'Brindes', 'unit': ProductUnit.un, 'sale': 42.00, 'cost': 19.00, 'stock': 50.0, 'min': 15.0},
        {'name': 'Crachá em PVC 0,76mm com Cordão Personalizado', 'sub': 'Identificação', 'unit': ProductUnit.un, 'sale': 16.00, 'cost': 6.20, 'stock': 90.0, 'min': 20.0},
        {'name': 'Sacola Ecológica Ecobag Algodão Cru com Silk', 'sub': 'Embalagens', 'unit': ProductUnit.un, 'sale': 18.50, 'cost': 7.90, 'stock': 70.0, 'min': 20.0},
      ],
    },

    // 17. Óticas & Visual
    {
      'sector': ProductSector.optics,
      'prefix': 'OTI',
      'items': [
        {'name': 'Armação de Grau Acetato Unissex Design Italiano', 'sub': 'Armações', 'unit': ProductUnit.un, 'sale': 289.00, 'cost': 110.00, 'stock': 25.0, 'min': 6.0},
        {'name': 'Óculos de Sol Polarizado Proteção UV400 Retrô', 'sub': 'Solares', 'unit': ProductUnit.un, 'sale': 199.00, 'cost': 75.00, 'stock': 35.0, 'min': 8.0},
        {'name': 'Lente de Contato Gelatinosa Mensal (Caixa c/ 6 Lentes)', 'sub': 'Lentes de Contato', 'unit': ProductUnit.cx, 'sale': 145.00, 'cost': 82.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Solução Multiuso para Lentes de Contato 360ml + Estojo', 'sub': 'Cuidados', 'unit': ProductUnit.un, 'sale': 48.00, 'cost': 24.00, 'stock': 60.0, 'min': 15.0},
        {'name': 'Armação de Grau Titanium Ultraleve Flexível', 'sub': 'Armações Premium', 'unit': ProductUnit.un, 'sale': 450.00, 'cost': 180.00, 'stock': 15.0, 'min': 4.0},
        {'name': 'Spray Limpa Lentes Anti-estático 60ml com Flanela', 'sub': 'Acessórios', 'unit': ProductUnit.un, 'sale': 15.00, 'cost': 4.50, 'stock': 120.0, 'min': 30.0},
        {'name': 'Estojo Rígido para Óculos com Forro de Veludo', 'sub': 'Estojos', 'unit': ProductUnit.un, 'sale': 25.00, 'cost': 8.80, 'stock': 80.0, 'min': 20.0},
        {'name': 'Cordão Salva-Óculos Corrente Dourada Fashion', 'sub': 'Acessórios', 'unit': ProductUnit.un, 'sale': 29.90, 'cost': 9.20, 'stock': 50.0, 'min': 12.0},
        {'name': 'Armação Infantil Silicone Inquebrável com Elástico', 'sub': 'Infantil', 'unit': ProductUnit.un, 'sale': 179.00, 'cost': 65.00, 'stock': 22.0, 'min': 5.0},
        {'name': 'Óculos de Sol Esportivo com Lente Espelhada', 'sub': 'Solares Esportivos', 'unit': ProductUnit.un, 'sale': 229.00, 'cost': 88.00, 'stock': 28.0, 'min': 6.0},
      ],
    },

    // 18. Brinquedos & Presentes
    {
      'sector': ProductSector.toys,
      'prefix': 'BRI',
      'items': [
        {'name': 'Jogo de Tabuleiro Estratégia e Conquista Familiar', 'sub': 'Jogos de Tabuleiro', 'unit': ProductUnit.un, 'sale': 129.90, 'cost': 68.00, 'stock': 20.0, 'min': 5.0},
        {'name': 'Blocos de Montar Castelo Medieval 500 Peças', 'sub': 'Construção', 'unit': ProductUnit.un, 'sale': 149.00, 'cost': 72.00, 'stock': 25.0, 'min': 6.0},
        {'name': 'Boneca Colecionável com Acessórios e Vestido Fashion', 'sub': 'Bonecas', 'unit': ProductUnit.un, 'sale': 89.90, 'cost': 41.00, 'stock': 35.0, 'min': 8.0},
        {'name': 'Carrinho de Controle Remoto Recarregável 4x4', 'sub': 'Veículos RC', 'unit': ProductUnit.un, 'sale': 169.00, 'cost': 82.00, 'stock': 18.0, 'min': 4.0},
        {'name': 'Quebra-Cabeça 1000 Peças Paisagem Turística', 'sub': 'Puzzles', 'unit': ProductUnit.un, 'sale': 49.90, 'cost': 22.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Massa de Modelar Colorida Atóxica (Pote com 12 Cores)', 'sub': 'Artesanato Infantil', 'unit': ProductUnit.pct, 'sale': 19.90, 'cost': 8.50, 'stock': 70.0, 'min': 20.0},
        {'name': 'Urso de Pelúcia Antialérgico Gigante 80cm', 'sub': 'Pelúcias', 'unit': ProductUnit.un, 'sale': 189.00, 'cost': 88.00, 'stock': 12.0, 'min': 3.0},
        {'name': 'Lousa Mágica Digital LCD Infantil para Desenho 8.5"', 'sub': 'Educativos', 'unit': ProductUnit.un, 'sale': 39.90, 'cost': 16.50, 'stock': 55.0, 'min': 15.0},
        {'name': 'Pista de Corrida com Loopings e Carrinho Exclusivo', 'sub': 'Pistas', 'unit': ProductUnit.un, 'sale': 119.00, 'cost': 58.00, 'stock': 22.0, 'min': 5.0},
        {'name': 'Instrumento Musical Teclado Eletrônico Infantil com Microfone', 'sub': 'Musicais', 'unit': ProductUnit.un, 'sale': 99.00, 'cost': 46.00, 'stock': 24.0, 'min': 6.0},
      ],
    },

    // 19. Jardinagem & Plantas
    {
      'sector': ProductSector.gardening,
      'prefix': 'JAR',
      'items': [
        {'name': 'Substrato Especial para Plantas e Flores Saco 20kg', 'sub': 'Terras e Substratos', 'unit': ProductUnit.pct, 'sale': 32.90, 'cost': 16.00, 'stock': 45.0, 'min': 12.0},
        {'name': 'Adubo Fertilizante NPK 10-10-10 Concentrado 1kg', 'sub': 'Fertilizantes', 'unit': ProductUnit.pct, 'sale': 18.50, 'cost': 8.90, 'stock': 60.0, 'min': 15.0},
        {'name': 'Vaso Auto-irrigável Polietileno Rústico 35cm', 'sub': 'Vasos', 'unit': ProductUnit.un, 'sale': 64.00, 'cost': 29.00, 'stock': 30.0, 'min': 8.0},
        {'name': 'Tesoura de Poda Profissional em Aço Forjado', 'sub': 'Ferramentas', 'unit': ProductUnit.un, 'sale': 49.90, 'cost': 22.50, 'stock': 35.0, 'min': 10.0},
        {'name': 'Mangueira de Jardim Flexível Trançada 30m com Esguicho', 'sub': 'Irrigação', 'unit': ProductUnit.un, 'sale': 89.00, 'cost': 44.00, 'stock': 25.0, 'min': 6.0},
        {'name': 'Pulverizador Manual de Pressão Prévia 2 Litros', 'sub': 'Pulverizadores', 'unit': ProductUnit.un, 'sale': 38.00, 'cost': 17.20, 'stock': 40.0, 'min': 10.0},
        {'name': 'Orquídea Phalaenopsis Vaso Duplo com Cachepô', 'sub': 'Plantas Vivas', 'unit': ProductUnit.un, 'sale': 69.00, 'cost': 32.00, 'stock': 20.0, 'min': 5.0},
        {'name': 'Sementes de Hortaliças Variadas (Envelope)', 'sub': 'Sementes', 'unit': ProductUnit.un, 'sale': 4.50, 'cost': 1.60, 'stock': 150.0, 'min': 40.0},
        {'name': 'Regador Plástico Bico Fino 5 Litros Ergonômico', 'sub': 'Irrigação', 'unit': ProductUnit.un, 'sale': 24.90, 'cost': 10.50, 'stock': 50.0, 'min': 12.0},
        {'name': 'Luva de Jardinagem com Garras de Escavação', 'sub': 'Acessórios', 'unit': ProductUnit.par, 'sale': 19.90, 'cost': 7.80, 'stock': 65.0, 'min': 18.0},
      ],
    },

    // 20. Indústria & Metalmecânica
    {
      'sector': ProductSector.industry,
      'prefix': 'IND',
      'items': [
        {'name': 'Disco de Corte Fino Inox 4.1/2 x 1.0mm (Caixa c/ 25un)', 'sub': 'Abrasivos', 'unit': ProductUnit.cx, 'sale': 75.00, 'cost': 38.00, 'stock': 50.0, 'min': 15.0},
        {'name': 'Eletrodo Revestido AWS E6013 2.50mm Caixa 5kg', 'sub': 'Solda', 'unit': ProductUnit.cx, 'sale': 89.00, 'cost': 52.00, 'stock': 40.0, 'min': 10.0},
        {'name': 'Óleo Protetivo Anticorrosivo Industrial 5 Litros', 'sub': 'Químicos Industriais', 'unit': ProductUnit.lt, 'sale': 120.00, 'cost': 65.00, 'stock': 22.0, 'min': 5.0},
        {'name': 'Parafuso Sextavado Aço Zincado 1/2 x 2 Pol (Cento)', 'sub': 'Fixadores', 'unit': ProductUnit.pct, 'sale': 68.00, 'cost': 34.00, 'stock': 60.0, 'min': 15.0},
        {'name': 'Barra Chata de Aço Carbono 1 x 1/8 Pol 6 Metros', 'sub': 'Metais', 'unit': ProductUnit.un, 'sale': 45.00, 'cost': 26.00, 'stock': 70.0, 'min': 20.0},
        {'name': 'Graxa de Lítio Multiuso Azul EP-2 Balde 1kg', 'sub': 'Lubrificantes', 'unit': ProductUnit.un, 'sale': 42.50, 'cost': 21.00, 'stock': 38.0, 'min': 10.0},
        {'name': 'Óculos de Segurança com Proteção Lateral e UV', 'sub': 'EPI', 'unit': ProductUnit.un, 'sale': 12.50, 'cost': 4.80, 'stock': 130.0, 'min': 35.0},
        {'name': 'Luva de Vaqueta Mista Cano Curto para Soldador', 'sub': 'EPI', 'unit': ProductUnit.par, 'sale': 28.00, 'cost': 13.50, 'stock': 85.0, 'min': 20.0},
        {'name': 'Broca HSS Aço Rápido 8.0mm para Metal', 'sub': 'Usinagem', 'unit': ProductUnit.un, 'sale': 18.00, 'cost': 7.50, 'stock': 90.0, 'min': 25.0},
        {'name': 'Macho Manual Aço Rápido M8 x 1.25mm (Jogo 3 Peças)', 'sub': 'Rosqueamento', 'unit': ProductUnit.pct, 'sale': 54.00, 'cost': 26.00, 'stock': 32.0, 'min': 8.0},
      ],
    },
  ];

  int productCounter = 1;

  for (final sec in sectorData) {
    final sector = sec['sector'] as ProductSector;
    final prefix = sec['prefix'] as String;
    final items = sec['items'] as List<Map<String, dynamic>>;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final skuNumber = (i + 1).toString().padLeft(3, '0');
      final barcodeSuffix = (productCounter).toString().padLeft(6, '0');

      products.add({
        'name': item['name'] as String,
        'sku': '$prefix-$skuNumber',
        'barcode': '7898000$barcodeSuffix',
        'sector': sector.name,
        'categoryTitle': sector.title,
        'subcategory': item['sub'] as String,
        'description': '${item['name']} com excelente custo-benefício e garantia de fábrica.',
        'salePrice': (item['sale'] as num).toDouble(),
        'costPrice': (item['cost'] as num).toDouble(),
        'stockQuantity': (item['stock'] as num).toDouble(),
        'minStock': (item['min'] as num).toDouble(),
        'unit': (item['unit'] as ProductUnit).symbol,
        'ncm': '3924.90.00',
        'status': ProductStatus.active.name,
        'specificAttributes': <String, dynamic>{
          'modelo': 'Linha 2026',
          'garantia': '90 dias',
          if (item['attrs'] != null) ...(item['attrs'] as Map<String, dynamic>),
        },
      });

      productCounter++;
    }
  }

  return products;
}
