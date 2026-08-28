import 'package:shared_preferences/shared_preferences.dart';
import '../../../products/domain/models/product_model.dart';

/// Serviço de persistência e gerenciamento das preferências globais e ramo do CRM
class SettingsService {
  static const _preferredSectorKey = 'mavis_crm_preferred_sector';
  static const _isFixedSectorKey = 'mavis_crm_is_fixed_sector';
  static const _hasOnboardingKey = 'mavis_crm_has_completed_onboarding';

  /// Retorna se o usuário já realizou a configuração inicial de ramo
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasOnboardingKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Define que o usuário concluiu a configuração de ramo inicial
  static Future<void> setCompletedOnboarding(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasOnboardingKey, completed);
    } catch (_) {}
  }

  /// Retorna o setor preferencial do usuário (ex: ProductSector.solarPlant)
  static Future<ProductSector?> getPreferredSector() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sectorName = prefs.getString(_preferredSectorKey);
      if (sectorName != null && sectorName.isNotEmpty) {
        for (final s in ProductSector.values) {
          if (s.name == sectorName) return s;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Retorna se o CRM opera em modo fixo exclusivo para o ramo selecionado
  static Future<bool> isFixedSectorMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isFixedSectorKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Salva o setor preferencial e se opera em modo fixo
  static Future<void> savePreferredSector(ProductSector? sector, {bool isFixed = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (sector != null) {
        await prefs.setString(_preferredSectorKey, sector.name);
        await prefs.setString('mavis_saved_product_filter_sector', sector.name);
      } else {
        await prefs.remove(_preferredSectorKey);
      }
      await prefs.setBool(_isFixedSectorKey, isFixed);
      await prefs.setBool(_hasOnboardingKey, true);
    } catch (_) {}
  }

  /// Reseta as preferências de onboarding para testar primeiro acesso
  static Future<void> resetPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_preferredSectorKey);
      await prefs.remove(_isFixedSectorKey);
      await prefs.remove(_hasOnboardingKey);
    } catch (_) {}
  }
}
