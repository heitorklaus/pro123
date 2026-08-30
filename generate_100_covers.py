import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

# Configuracoes de resolucao A4 (1240 x 1754 a 150 DPI)
# Usamos supersampling 2x (2480 x 3508) para anti-aliasing perfeito de curvas e fitas
RENDER_W = 2480
RENDER_H = 3508
FINAL_W = 1240
FINAL_H = 1754

BG_DIR = 'c:/mavis/assets/background_web'
OUT_DIR = 'c:/mavis/assets/modelo_propostas'

os.makedirs(OUT_DIR, exist_ok=True)

# Listar todas as fotos de background disponiveis
bg_files = [os.path.join(BG_DIR, f) for f in os.listdir(BG_DIR) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
if not bg_files:
    raise RuntimeError("Nenhuma imagem de fundo encontrada em " + BG_DIR)

print(f"Encontradas {len(bg_files)} imagens de background.")

# Paletas de Cores Corporativas para os Separadores e Fitas
PALETTES = [
    # 1. Electric Blue & Sapphire
    {
        'id': 'blue',
        'ribbon1': (2, 132, 199),      # Sky 600
        'ribbon2': (56, 189, 248),     # Sky 400
        'ribbon3': (15, 23, 42),       # Dark Slate
    },
    # 2. Solar Amber & Gold
    {
        'id': 'gold',
        'ribbon1': (245, 158, 11),     # Amber 500
        'ribbon2': (251, 191, 36),     # Amber 400
        'ribbon3': (30, 41, 59),       # Slate 800
    },
    # 3. Emerald Green & Teal
    {
        'id': 'emerald',
        'ribbon1': (16, 185, 129),     # Emerald 500
        'ribbon2': (52, 211, 153),     # Emerald 400
        'ribbon3': (6, 78, 59),        # Emerald 900
    },
    # 4. Royal Indigo & Electric Cyan
    {
        'id': 'indigo',
        'ribbon1': (79, 70, 229),      # Indigo 600
        'ribbon2': (129, 140, 248),    # Indigo 400
        'ribbon3': (15, 23, 42),       # Dark Slate
    },
    # 5. Sunburst Orange & Dark Steel
    {
        'id': 'orange',
        'ribbon1': (249, 115, 22),     # Orange 500
        'ribbon2': (253, 186, 116),    # Orange 300
        'ribbon3': (30, 41, 59),       # Slate 800
    },
    # 6. Tech Cyan & Midnight Blue
    {
        'id': 'cyan',
        'ribbon1': (6, 182, 212),      # Cyan 500
        'ribbon2': (103, 232, 249),    # Cyan 300
        'ribbon3': (15, 23, 42),       # Slate 900
    },
    # 7. Modern Rose / Crimson & Graphite
    {
        'id': 'rose',
        'ribbon1': (244, 63, 94),      # Rose 500
        'ribbon2': (251, 113, 133),    # Rose 400
        'ribbon3': (30, 41, 59),       # Slate 800
    },
    # 8. High-Tech Slate & Neon Lime
    {
        'id': 'lime',
        'ribbon1': (132, 204, 22),     # Lime 500
        'ribbon2': (190, 242, 100),    # Lime 300
        'ribbon3': (15, 23, 42),       # Slate 900
    }
]

def create_gradient_curve_mask(width, height, divider_type, split_y_ratio=0.72):
    """
    Gera as mascaras e coordenadas para os 10 separadores de design.
    divider_type: 0 a 9
    Retorna uma lista de fitas com cores e o poligono da mascara da foto.
    """
    split_y = int(height * split_y_ratio)
    ribbons = []
    
    # 0. Classic Smooth S-Wave
    if divider_type == 0:
        pts_photo = [(0, 0), (width, 0)]
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 1.5) * (height * 0.05) - (t * height * 0.04)
            pts_photo.append((x, y))
        
        # Ribbon 1 (Accent)
        ribbon_1 = []
        for x in range(0, width + 1, 20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 1.5) * (height * 0.05) - (t * height * 0.04)
            ribbon_1.append((x, y))
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 1.5) * (height * 0.05) - (t * height * 0.04) + 40
            ribbon_1.append((x, y))
        ribbons.append(('accent', ribbon_1))
        
        # Ribbon 2 (Main)
        ribbon_2 = []
        for x in range(0, width + 1, 20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 1.5) * (height * 0.05) - (t * height * 0.04) + 35
            ribbon_2.append((x, y))
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 1.5) * (height * 0.05) - (t * height * 0.04) + 95
            ribbon_2.append((x, y))
        ribbons.append(('main', ribbon_2))
        
        return pts_photo, ribbons

    # 1. Double Harmonic Intersecting Waves
    elif divider_type == 1:
        pts_photo = [(0, 0), (width, 0)]
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 2.2) * (height * 0.035) + math.cos(t * math.pi) * (height * 0.02)
            pts_photo.append((x, y))
        
        ribbon_1 = []
        for x in range(0, width + 1, 20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 2.2) * (height * 0.035) + math.cos(t * math.pi) * (height * 0.02)
            ribbon_1.append((x, y))
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 2.2) * (height * 0.035) + math.cos(t * math.pi) * (height * 0.02) + 50
            ribbon_1.append((x, y))
        ribbons.append(('main', ribbon_1))

        ribbon_2 = []
        for x in range(0, width + 1, 20):
            t = x / width
            y = split_y + math.cos(t * math.pi * 1.8) * (height * 0.04) + 30
            ribbon_2.append((x, y))
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.cos(t * math.pi * 1.8) * (height * 0.04) + 85
            ribbon_2.append((x, y))
        ribbons.append(('accent', ribbon_2))

        return pts_photo, ribbons

    # 2. Modern Angular Diagonal Slash
    elif divider_type == 2:
        pts_photo = [(0, 0), (width, 0), (width, split_y - 120), (0, split_y + 140)]
        
        r1 = [(0, split_y + 140), (width, split_y - 120), (width, split_y - 85), (0, split_y + 175)]
        ribbons.append(('accent', r1))
        
        r2 = [(0, split_y + 175), (width, split_y - 85), (width, split_y - 30), (0, split_y + 230)]
        ribbons.append(('main', r2))

        r3 = [(0, split_y + 230), (width, split_y - 30), (width, split_y + 10), (0, split_y + 270)]
        ribbons.append(('dark', r3))

        return pts_photo, ribbons

    # 3. Geometric Faceted Triangles / Chevrons
    elif divider_type == 3:
        mid_x = int(width * 0.65)
        pts_photo = [(0, 0), (width, 0), (width, split_y + 60), (mid_x, split_y - 80), (0, split_y + 90)]
        
        r1 = [(0, split_y + 90), (mid_x, split_y - 80), (width, split_y + 60),
              (width, split_y + 110), (mid_x, split_y - 30), (0, split_y + 140)]
        ribbons.append(('accent', r1))

        r2 = [(0, split_y + 140), (mid_x, split_y - 30), (width, split_y + 110),
              (width, split_y + 180), (mid_x, split_y + 40), (0, split_y + 210)]
        ribbons.append(('main', r2))

        return pts_photo, ribbons

    # 4. Aerodynamic Concave Curved Arch
    elif divider_type == 4:
        pts_photo = [(0, 0), (width, 0)]
        for x in range(width, -1, -20):
            t = (x - width / 2) / (width / 2)
            y = split_y - (1 - t * t) * (height * 0.07) + (height * 0.02)
            pts_photo.append((x, y))
        
        r1 = []
        for x in range(0, width + 1, 20):
            t = (x - width / 2) / (width / 2)
            y = split_y - (1 - t * t) * (height * 0.07) + (height * 0.02)
            r1.append((x, y))
        for x in range(width, -1, -20):
            t = (x - width / 2) / (width / 2)
            y = split_y - (1 - t * t) * (height * 0.07) + (height * 0.02) + 45
            r1.append((x, y))
        ribbons.append(('accent', r1))

        r2 = []
        for x in range(0, width + 1, 20):
            t = (x - width / 2) / (width / 2)
            y = split_y - (1 - t * t) * (height * 0.07) + (height * 0.02) + 40
            r2.append((x, y))
        for x in range(width, -1, -20):
            t = (x - width / 2) / (width / 2)
            y = split_y - (1 - t * t) * (height * 0.07) + (height * 0.02) + 110
            r2.append((x, y))
        ribbons.append(('main', r2))

        return pts_photo, ribbons

    # 5. Dual Slope Architectural Facet
    elif divider_type == 5:
        p1 = (0, split_y + 110)
        p2 = (int(width * 0.35), split_y - 60)
        p3 = (int(width * 0.75), split_y + 40)
        p4 = (width, split_y - 90)
        pts_photo = [(0, 0), (width, 0), p4, p3, p2, p1]

        r1 = [p1, p2, p3, p4, (p4[0], p4[1] + 45), (p3[0], p3[1] + 45), (p2[0], p2[1] + 45), (p1[0], p1[1] + 45)]
        ribbons.append(('accent', r1))

        r2 = [(p1[0], p1[1] + 40), (p2[0], p2[1] + 40), (p3[0], p3[1] + 40), (p4[0], p4[1] + 40),
              (p4[0], p4[1] + 115), (p3[0], p3[1] + 115), (p2[0], p2[1] + 115), (p1[0], p1[1] + 115)]
        ribbons.append(('main', r2))

        return pts_photo, ribbons

    # 6. Triple Ripple Wave Cascade
    elif divider_type == 6:
        pts_photo = [(0, 0), (width, 0)]
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 3.0) * (height * 0.025) - (t * 30)
            pts_photo.append((x, y))
        
        r1 = []
        for x in range(0, width + 1, 20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 3.0) * (height * 0.025) - (t * 30)
            r1.append((x, y))
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 3.0) * (height * 0.025) - (t * 30) + 40
            r1.append((x, y))
        ribbons.append(('accent', r1))

        r2 = []
        for x in range(0, width + 1, 20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 3.0) * (height * 0.025) - (t * 30) + 35
            r2.append((x, y))
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + math.sin(t * math.pi * 3.0) * (height * 0.025) - (t * 30) + 95
            r2.append((x, y))
        ribbons.append(('main', r2))

        return pts_photo, ribbons

    # 7. Asymmetric Hexagonal Tech Polygon
    elif divider_type == 7:
        pts_photo = [(0, 0), (width, 0), (width, split_y + 120), (int(width * 0.5), split_y + 120),
                     (int(width * 0.4), split_y - 50), (0, split_y - 50)]
        
        r1 = [(0, split_y - 50), (int(width * 0.4), split_y - 50), (int(width * 0.5), split_y + 120), (width, split_y + 120),
              (width, split_y + 160), (int(width * 0.5) + 20, split_y + 160), (int(width * 0.4) + 20, split_y - 10), (0, split_y - 10)]
        ribbons.append(('accent', r1))

        r2 = [(0, split_y - 10), (int(width * 0.4) + 20, split_y - 10), (int(width * 0.5) + 20, split_y + 160), (width, split_y + 160),
              (width, split_y + 220), (int(width * 0.5) + 40, split_y + 220), (int(width * 0.4) + 40, split_y + 50), (0, split_y + 50)]
        ribbons.append(('main', r2))

        return pts_photo, ribbons

    # 8. High Arch Convex Bow
    elif divider_type == 8:
        pts_photo = [(0, 0), (width, 0)]
        for x in range(width, -1, -20):
            t = (x - width / 2) / (width / 2)
            y = split_y + (1 - t * t) * (height * 0.05) - (height * 0.02)
            pts_photo.append((x, y))
        
        r1 = []
        for x in range(0, width + 1, 20):
            t = (x - width / 2) / (width / 2)
            y = split_y + (1 - t * t) * (height * 0.05) - (height * 0.02)
            r1.append((x, y))
        for x in range(width, -1, -20):
            t = (x - width / 2) / (width / 2)
            y = split_y + (1 - t * t) * (height * 0.05) - (height * 0.02) + 45
            r1.append((x, y))
        ribbons.append(('accent', r1))

        r2 = []
        for x in range(0, width + 1, 20):
            t = (x - width / 2) / (width / 2)
            y = split_y + (1 - t * t) * (height * 0.05) - (height * 0.02) + 40
            r2.append((x, y))
        for x in range(width, -1, -20):
            t = (x - width / 2) / (width / 2)
            y = split_y + (1 - t * t) * (height * 0.05) - (height * 0.02) + 105
            r2.append((x, y))
        ribbons.append(('main', r2))

        return pts_photo, ribbons

    # 9. Dynamic Rising Diagonal Sweep
    else:
        pts_photo = [(0, 0), (width, 0)]
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + (0.5 - t) * (height * 0.12) + math.sin(t * math.pi) * (height * 0.03)
            pts_photo.append((x, y))
        
        r1 = []
        for x in range(0, width + 1, 20):
            t = x / width
            y = split_y + (0.5 - t) * (height * 0.12) + math.sin(t * math.pi) * (height * 0.03)
            r1.append((x, y))
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + (0.5 - t) * (height * 0.12) + math.sin(t * math.pi) * (height * 0.03) + 40
            r1.append((x, y))
        ribbons.append(('accent', r1))

        r2 = []
        for x in range(0, width + 1, 20):
            t = x / width
            y = split_y + (0.5 - t) * (height * 0.12) + math.sin(t * math.pi) * (height * 0.03) + 35
            r2.append((x, y))
        for x in range(width, -1, -20):
            t = x / width
            y = split_y + (0.5 - t) * (height * 0.12) + math.sin(t * math.pi) * (height * 0.03) + 95
            r2.append((x, y))
        ribbons.append(('main', r2))

        return pts_photo, ribbons


def generate_single_cover_clean(index, bg_path, palette, divider_type):
    """
    Renderiza 1 template de capa A4 limpo (sem texto e sem retangulos)
    em altissima resolucao e salva no disco.
    """
    # 1. Canvas Branco Puro (100% solido e limpo)
    canvas = Image.new('RGB', (RENDER_W, RENDER_H), (255, 255, 255))
    
    # 2. Carregar e ajustar Foto de Fundo
    try:
        bg_img = Image.open(bg_path).convert('RGB')
    except Exception as e:
        print(f"Erro ao abrir {bg_path}: {e}")
        bg_img = Image.new('RGB', (RENDER_W, RENDER_H), (200, 220, 240))
    
    # Redimensionar para cobrir a area superior mantendo proporcao
    target_photo_h = int(RENDER_H * 0.85)
    scale = max(RENDER_W / bg_img.width, target_photo_h / bg_img.height)
    new_w = int(bg_img.width * scale)
    new_h = int(bg_img.height * scale)
    bg_resized = bg_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Crop centralizado/ajustado
    crop_x = (new_w - RENDER_W) // 2
    crop_y = (index * 47) % max(1, new_h - target_photo_h)
    bg_cropped = bg_resized.crop((crop_x, crop_y, crop_x + RENDER_W, crop_y + target_photo_h))
    
    # Leve aprimoramento de cor e contraste
    enhancer = ImageEnhance.Color(bg_cropped)
    bg_cropped = enhancer.enhance(1.10)
    enhancer_con = ImageEnhance.Contrast(bg_cropped)
    bg_cropped = enhancer_con.enhance(1.06)

    # 3. Gerar Separador e Mascara da Foto
    pts_photo, ribbons = create_gradient_curve_mask(RENDER_W, RENDER_H, divider_type, split_y_ratio=0.72)
    
    # Mascara da foto
    mask_photo = Image.new('L', (RENDER_W, RENDER_H), 0)
    draw_mask = ImageDraw.Draw(mask_photo)
    draw_mask.polygon(pts_photo, fill=255)
    
    # Aplicar foto no canvas
    canvas.paste(bg_cropped, (0, 0), mask_photo.crop((0, 0, RENDER_W, target_photo_h)))
    
    # 4. Desenhar Ribbons / Fitas do Separador
    draw = ImageDraw.Draw(canvas, 'RGBA')
    for r_type, pts in ribbons:
        if r_type == 'main':
            color = palette['ribbon1'] + (255,)
        elif r_type == 'accent':
            color = palette['ribbon2'] + (255,)
        else:
            color = palette['ribbon3'] + (255,)
        draw.polygon(pts, fill=color)

    # 5. Redimensionar para tamanho final A4 (1240 x 1754) com Anti-Aliasing LANCZOS
    final_img = canvas.resize((FINAL_W, FINAL_H), Image.Resampling.LANCZOS)
    
    # Salvar em formato JPG de alta qualidade
    out_file = os.path.join(OUT_DIR, f"modelo_proposta_{index}.jpg")
    final_img.save(out_file, "JPEG", quality=94, optimize=True)
    return out_file

# Gerar os 100 modelos limpos com variacoes unicas combinadas
print("Iniciando geracao de 100 modelos de capas A4 100% limpas (sem textos nem caixas)...")

for i in range(1, 101):
    # Selecionar variacoes
    bg_path = bg_files[(i - 1) % len(bg_files)]
    palette = PALETTES[(i - 1) % len(PALETTES)]
    divider = (i - 1) % 10
    
    out_path = generate_single_cover_clean(
        index=i,
        bg_path=bg_path,
        palette=palette,
        divider_type=divider
    )
    if i % 10 == 0 or i == 1 or i == 100:
        print(f"[{i}/100] Gerado: {os.path.basename(out_path)} (Paleta: {palette['id']}, Separador: {divider})")

print("Sucesso! 100 capas A4 limpas geradas e salvas em assets/modelo_propostas/.")
