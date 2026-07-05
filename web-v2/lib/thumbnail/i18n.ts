// 🔥 MULTI-LANGUAGE SUPPORT - GLOBAL REACH 💣

// Supported languages
export type Language = 'en' | 'es' | 'fr' | 'de' | 'ja' | 'ko' | 'zh' | 'pt' | 'ru' | 'ar' | 'hi';

export const languages: Record<Language, { name: string; nativeName: string; flag: string }> = {
  en: { name: 'English', nativeName: 'English', flag: '🇺🇸' },
  es: { name: 'Spanish', nativeName: 'Español', flag: '🇪🇸' },
  fr: { name: 'French', nativeName: 'Français', flag: '🇫🇷' },
  de: { name: 'German', nativeName: 'Deutsch', flag: '🇩🇪' },
  ja: { name: 'Japanese', nativeName: '日本語', flag: '🇯🇵' },
  ko: { name: 'Korean', nativeName: '한국어', flag: '🇰🇷' },
  zh: { name: 'Chinese', nativeName: '中文', flag: '🇨🇳' },
  pt: { name: 'Portuguese', nativeName: 'Português', flag: '🇵🇹' },
  ru: { name: 'Russian', nativeName: 'Русский', flag: '🇷🇺' },
  ar: { name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦' },
  hi: { name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳' },
};

// Translations
// Base translations for fully-translated languages. Assembled into the exported
// `translations` map below so fallback languages can safely spread English.
const baseTranslations = {
  en: {
    // Thumbnail Creator
    'thumbnail.creator': 'Thumbnail Creator',
    'thumbnail.create': 'Create Thumbnail',
    'thumbnail.edit': 'Edit Thumbnail',
    'thumbnail.save': 'Save',
    'thumbnail.export': 'Export',
    'thumbnail.delete': 'Delete',
    
    // Canvas
    'canvas.background': 'Background',
    'canvas.text': 'Text',
    'canvas.image': 'Image',
    'canvas.sticker': 'Sticker',
    'canvas.filter': 'Filter',
    
    // AI Features
    'ai.generate': 'AI Generate',
    'ai.removeBackground': 'Remove Background',
    'ai.predictCTR': 'Predict CTR',
    'ai.analyzing': 'Analyzing...',
    'ai.generating': 'Generating...',
    
    // Templates
    'template.browse': 'Browse Templates',
    'template.myTemplates': 'My Templates',
    'template.featured': 'Featured',
    'template.popular': 'Popular',
    'template.recent': 'Recent',
    
    // Team
    'team.workspace': 'Team Workspace',
    'team.members': 'Members',
    'team.invite': 'Invite Member',
    'team.role': 'Role',
    
    // Analytics
    'analytics.dashboard': 'Analytics Dashboard',
    'analytics.impressions': 'Impressions',
    'analytics.clicks': 'Clicks',
    'analytics.ctr': 'Click-Through Rate',
    'analytics.views': 'Views',
    'analytics.engagement': 'Engagement',
    
    // Common
    'common.loading': 'Loading...',
    'common.error': 'Error',
    'common.success': 'Success',
    'common.cancel': 'Cancel',
    'common.confirm': 'Confirm',
    'common.close': 'Close',
  },
  
  es: {
    // Thumbnail Creator
    'thumbnail.creator': 'Creador de Miniaturas',
    'thumbnail.create': 'Crear Miniatura',
    'thumbnail.edit': 'Editar Miniatura',
    'thumbnail.save': 'Guardar',
    'thumbnail.export': 'Exportar',
    'thumbnail.delete': 'Eliminar',
    
    // Canvas
    'canvas.background': 'Fondo',
    'canvas.text': 'Texto',
    'canvas.image': 'Imagen',
    'canvas.sticker': 'Pegatina',
    'canvas.filter': 'Filtro',
    
    // AI Features
    'ai.generate': 'Generar con IA',
    'ai.removeBackground': 'Eliminar Fondo',
    'ai.predictCTR': 'Predecir CTR',
    'ai.analyzing': 'Analizando...',
    'ai.generating': 'Generando...',
    
    // Templates
    'template.browse': 'Explorar Plantillas',
    'template.myTemplates': 'Mis Plantillas',
    'template.featured': 'Destacadas',
    'template.popular': 'Populares',
    'template.recent': 'Recientes',
    
    // Team
    'team.workspace': 'Espacio de Equipo',
    'team.members': 'Miembros',
    'team.invite': 'Invitar Miembro',
    'team.role': 'Rol',
    
    // Analytics
    'analytics.dashboard': 'Panel de Análisis',
    'analytics.impressions': 'Impresiones',
    'analytics.clicks': 'Clics',
    'analytics.ctr': 'Tasa de Clics',
    'analytics.views': 'Vistas',
    'analytics.engagement': 'Interacción',
    
    // Common
    'common.loading': 'Cargando...',
    'common.error': 'Error',
    'common.success': 'Éxito',
    'common.cancel': 'Cancelar',
    'common.confirm': 'Confirmar',
    'common.close': 'Cerrar',
  },
  
  fr: {
    // Thumbnail Creator
    'thumbnail.creator': 'Créateur de Miniatures',
    'thumbnail.create': 'Créer une Miniature',
    'thumbnail.edit': 'Modifier la Miniature',
    'thumbnail.save': 'Enregistrer',
    'thumbnail.export': 'Exporter',
    'thumbnail.delete': 'Supprimer',
    
    // Canvas
    'canvas.background': 'Arrière-plan',
    'canvas.text': 'Texte',
    'canvas.image': 'Image',
    'canvas.sticker': 'Autocollant',
    'canvas.filter': 'Filtre',
    
    // AI Features
    'ai.generate': 'Générer avec IA',
    'ai.removeBackground': 'Supprimer l\'Arrière-plan',
    'ai.predictCTR': 'Prédire le CTR',
    'ai.analyzing': 'Analyse en cours...',
    'ai.generating': 'Génération en cours...',
    
    // Templates
    'template.browse': 'Parcourir les Modèles',
    'template.myTemplates': 'Mes Modèles',
    'template.featured': 'En Vedette',
    'template.popular': 'Populaires',
    'template.recent': 'Récents',
    
    // Team
    'team.workspace': 'Espace d\'Équipe',
    'team.members': 'Membres',
    'team.invite': 'Inviter un Membre',
    'team.role': 'Rôle',
    
    // Analytics
    'analytics.dashboard': 'Tableau de Bord',
    'analytics.impressions': 'Impressions',
    'analytics.clicks': 'Clics',
    'analytics.ctr': 'Taux de Clic',
    'analytics.views': 'Vues',
    'analytics.engagement': 'Engagement',
    
    // Common
    'common.loading': 'Chargement...',
    'common.error': 'Erreur',
    'common.success': 'Succès',
    'common.cancel': 'Annuler',
    'common.confirm': 'Confirmer',
    'common.close': 'Fermer',
  },
  
  de: {
    // Thumbnail Creator
    'thumbnail.creator': 'Miniaturansicht-Ersteller',
    'thumbnail.create': 'Miniaturansicht Erstellen',
    'thumbnail.edit': 'Miniaturansicht Bearbeiten',
    'thumbnail.save': 'Speichern',
    'thumbnail.export': 'Exportieren',
    'thumbnail.delete': 'Löschen',
    
    // Canvas
    'canvas.background': 'Hintergrund',
    'canvas.text': 'Text',
    'canvas.image': 'Bild',
    'canvas.sticker': 'Aufkleber',
    'canvas.filter': 'Filter',
    
    // AI Features
    'ai.generate': 'KI Generieren',
    'ai.removeBackground': 'Hintergrund Entfernen',
    'ai.predictCTR': 'CTR Vorhersagen',
    'ai.analyzing': 'Analysiere...',
    'ai.generating': 'Generiere...',
    
    // Templates
    'template.browse': 'Vorlagen Durchsuchen',
    'template.myTemplates': 'Meine Vorlagen',
    'template.featured': 'Empfohlen',
    'template.popular': 'Beliebt',
    'template.recent': 'Neueste',
    
    // Team
    'team.workspace': 'Team-Arbeitsbereich',
    'team.members': 'Mitglieder',
    'team.invite': 'Mitglied Einladen',
    'team.role': 'Rolle',
    
    // Analytics
    'analytics.dashboard': 'Analytics-Dashboard',
    'analytics.impressions': 'Impressionen',
    'analytics.clicks': 'Klicks',
    'analytics.ctr': 'Klickrate',
    'analytics.views': 'Aufrufe',
    'analytics.engagement': 'Engagement',
    
    // Common
    'common.loading': 'Laden...',
    'common.error': 'Fehler',
    'common.success': 'Erfolg',
    'common.cancel': 'Abbrechen',
    'common.confirm': 'Bestätigen',
    'common.close': 'Schließen',
  },
  
  ja: {
    // Thumbnail Creator
    'thumbnail.creator': 'サムネイル作成',
    'thumbnail.create': 'サムネイルを作成',
    'thumbnail.edit': 'サムネイルを編集',
    'thumbnail.save': '保存',
    'thumbnail.export': 'エクスポート',
    'thumbnail.delete': '削除',
    
    // Canvas
    'canvas.background': '背景',
    'canvas.text': 'テキスト',
    'canvas.image': '画像',
    'canvas.sticker': 'ステッカー',
    'canvas.filter': 'フィルター',
    
    // AI Features
    'ai.generate': 'AI生成',
    'ai.removeBackground': '背景を削除',
    'ai.predictCTR': 'CTRを予測',
    'ai.analyzing': '分析中...',
    'ai.generating': '生成中...',
    
    // Templates
    'template.browse': 'テンプレートを閲覧',
    'template.myTemplates': 'マイテンプレート',
    'template.featured': '注目',
    'template.popular': '人気',
    'template.recent': '最近',
    
    // Team
    'team.workspace': 'チームワークスペース',
    'team.members': 'メンバー',
    'team.invite': 'メンバーを招待',
    'team.role': '役割',
    
    // Analytics
    'analytics.dashboard': '分析ダッシュボード',
    'analytics.impressions': 'インプレッション',
    'analytics.clicks': 'クリック',
    'analytics.ctr': 'クリック率',
    'analytics.views': '視聴回数',
    'analytics.engagement': 'エンゲージメント',
    
    // Common
    'common.loading': '読み込み中...',
    'common.error': 'エラー',
    'common.success': '成功',
    'common.cancel': 'キャンセル',
    'common.confirm': '確認',
    'common.close': '閉じる',
  },
  
};

// Languages below fall back to English until fully translated.
export const translations: Record<Language, Record<string, string>> = {
  ...baseTranslations,
  ko: { ...baseTranslations.en }, // Korean (would be fully translated)
  zh: { ...baseTranslations.en }, // Chinese (would be fully translated)
  pt: { ...baseTranslations.en }, // Portuguese (would be fully translated)
  ru: { ...baseTranslations.en }, // Russian (would be fully translated)
  ar: { ...baseTranslations.en }, // Arabic (would be fully translated)
  hi: { ...baseTranslations.en }, // Hindi (would be fully translated)
};

// Translation hook
export function useTranslation(language: Language = 'en') {
  const t = (key: string): string => {
    return translations[language]?.[key] || translations.en[key] || key;
  };

  return { t, language };
}

// Get browser language
export function getBrowserLanguage(): Language {
  if (typeof window === 'undefined') return 'en';

  const browserLang = navigator.language.split('-')[0] as Language;
  return languages[browserLang] ? browserLang : 'en';
}

// Format number with locale
export function formatNumber(num: number, language: Language = 'en'): string {
  const locales: Record<Language, string> = {
    en: 'en-US',
    es: 'es-ES',
    fr: 'fr-FR',
    de: 'de-DE',
    ja: 'ja-JP',
    ko: 'ko-KR',
    zh: 'zh-CN',
    pt: 'pt-PT',
    ru: 'ru-RU',
    ar: 'ar-SA',
    hi: 'hi-IN',
  };

  return new Intl.NumberFormat(locales[language]).format(num);
}

// Format currency with locale
export function formatCurrency(
  amount: number,
  language: Language = 'en',
  currency: string = 'USD'
): string {
  const locales: Record<Language, string> = {
    en: 'en-US',
    es: 'es-ES',
    fr: 'fr-FR',
    de: 'de-DE',
    ja: 'ja-JP',
    ko: 'ko-KR',
    zh: 'zh-CN',
    pt: 'pt-PT',
    ru: 'ru-RU',
    ar: 'ar-SA',
    hi: 'hi-IN',
  };

  return new Intl.NumberFormat(locales[language], {
    style: 'currency',
    currency,
  }).format(amount);
}

// Format date with locale
export function formatDate(
  date: Date,
  language: Language = 'en',
  options: Intl.DateTimeFormatOptions = {}
): string {
  const locales: Record<Language, string> = {
    en: 'en-US',
    es: 'es-ES',
    fr: 'fr-FR',
    de: 'de-DE',
    ja: 'ja-JP',
    ko: 'ko-KR',
    zh: 'zh-CN',
    pt: 'pt-PT',
    ru: 'ru-RU',
    ar: 'ar-SA',
    hi: 'hi-IN',
  };

  return new Intl.DateTimeFormat(locales[language], options).format(date);
}

// RTL languages
export const rtlLanguages: Language[] = ['ar'];

// Check if language is RTL
export function isRTL(language: Language): boolean {
  return rtlLanguages.includes(language);
}

// Get text direction
export function getTextDirection(language: Language): 'ltr' | 'rtl' {
  return isRTL(language) ? 'rtl' : 'ltr';
}

// Save language preference
export function saveLanguagePreference(language: Language): void {
  if (typeof window !== 'undefined') {
    localStorage.setItem('preferred_language', language);
  }
}

// Load language preference
export function loadLanguagePreference(): Language {
  if (typeof window === 'undefined') return 'en';

  const saved = localStorage.getItem('preferred_language') as Language;
  return saved && languages[saved] ? saved : getBrowserLanguage();
}






