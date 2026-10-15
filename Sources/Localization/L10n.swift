import Foundation

public enum L10n {
    public static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"),
        ("ja", "日本語"), ("ko", "한국어"), ("de", "Deutsch"), ("fr", "Français"),
        ("es", "Español"), ("pt-BR", "Português (Brasil)"), ("it", "Italiano"),
        ("ru", "Русский"), ("ar", "العربية"), ("hi", "हिन्दी"),
        ("tr", "Türkçe"), ("id", "Bahasa Indonesia")
    ]
    public static var override: String? {
        get { UserDefaults.standard.string(forKey: "appLanguage") }
        set { UserDefaults.standard.set(newValue, forKey: "appLanguage") }
    }
    public static var language: String {
        guard let override else { return "en" }
        if languages.contains(where: { $0.code == override }) { return override }
        return Bundle.preferredLocalizations(from: languages.map(\.code)).first ?? "en"
    }
    public static var locale: Locale { Locale(identifier: language) }
    public static var isRightToLeft: Bool { language == "ar" }

    public static func text(_ key: String, language: String? = nil) -> String {
        let code = language ?? self.language
        if let path = Bundle.module.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        guard let path = Bundle.module.path(forResource: "en", ofType: "lproj"), let english = Bundle(path: path) else { return key }
        return english.localizedString(forKey: key, value: key, table: nil)
    }
    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
    public static var resourceURL: URL { Bundle.module.resourceURL ?? Bundle.module.bundleURL }
}
