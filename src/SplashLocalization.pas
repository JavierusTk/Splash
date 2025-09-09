unit SplashLocalization;

interface

uses
  Winapi.Windows;

// Get localized default strings based on Windows locale
function GetLocalizedLoadingCaption: string;
function GetLocalizedLearningIndicator: string;
function GetLocalizedStartingStatus: string;

implementation

function GetPrimaryLanguage: Word;
var
  LocaleID: LCID;
begin
  LocaleID := GetUserDefaultLCID;
  Result := PRIMARYLANGID(LocaleID);
end;

function GetLocalizedLoadingCaption: string;
var
  Lang: Word;
begin
  Lang := GetPrimaryLanguage;
  
  case Lang of
    LANG_SPANISH:    Result := 'Cargando';           // Spanish
    LANG_ENGLISH:    Result := 'Loading';            // English (default)
    LANG_FRENCH:     Result := 'Chargement';         // French
    LANG_GERMAN:     Result := 'Wird geladen';       // German
    LANG_ITALIAN:    Result := 'Caricamento';        // Italian
    LANG_PORTUGUESE: Result := 'Carregando';         // Portuguese
    LANG_DUTCH:      Result := 'Laden';              // Dutch
    LANG_CATALAN:    Result := 'Carregant';          // Catalan
    LANG_POLISH:     Result := 'Ładowanie';          // Polish
    LANG_SWEDISH:    Result := 'Laddar';             // Swedish
    LANG_NORWEGIAN:  Result := 'Laster';             // Norwegian
    LANG_DANISH:     Result := 'Indlæser';           // Danish
  else
    Result := 'Loading';  // Default to English
  end;
end;

function GetLocalizedLearningIndicator: string;
var
  Lang: Word;
begin
  Lang := GetPrimaryLanguage;
  
  case Lang of
    LANG_SPANISH:    Result := ' (aprendiendo)';     // Spanish
    LANG_ENGLISH:    Result := ' (learning)';        // English (default)
    LANG_FRENCH:     Result := ' (apprentissage)';   // French
    LANG_GERMAN:     Result := ' (lernend)';         // German
    LANG_ITALIAN:    Result := ' (apprendimento)';   // Italian
    LANG_PORTUGUESE: Result := ' (aprendendo)';      // Portuguese
    LANG_DUTCH:      Result := ' (aan het leren)';   // Dutch
    LANG_CATALAN:    Result := ' (aprenent)';        // Catalan
    LANG_POLISH:     Result := ' (uczenie się)';     // Polish
    LANG_SWEDISH:    Result := ' (lär sig)';         // Swedish
    LANG_NORWEGIAN:  Result := ' (lærer)';           // Norwegian
    LANG_DANISH:     Result := ' (lærer)';           // Danish
  else
    Result := ' (learning)';  // Default to English
  end;
end;

function GetLocalizedStartingStatus: string;
var
  Lang: Word;
begin
  Lang := GetPrimaryLanguage;
  
  case Lang of
    LANG_SPANISH:    Result := 'Inicializando sistema';        // Spanish
    LANG_ENGLISH:    Result := 'System initialization';        // English (default)
    LANG_FRENCH:     Result := 'Initialisation du système';    // French
    LANG_GERMAN:     Result := 'Systeminitialisierung';        // German
    LANG_ITALIAN:    Result := 'Inizializzazione del sistema'; // Italian
    LANG_PORTUGUESE: Result := 'Inicializando sistema';        // Portuguese
    LANG_DUTCH:      Result := 'Systeem initialiseren';        // Dutch
    LANG_CATALAN:    Result := 'Inicialitzant sistema';        // Catalan
    LANG_POLISH:     Result := 'Inicjalizacja systemu';        // Polish
    LANG_SWEDISH:    Result := 'Systeminitiering';             // Swedish
    LANG_NORWEGIAN:  Result := 'Systeminitialisering';         // Norwegian
    LANG_DANISH:     Result := 'Systeminitialisering';         // Danish
  else
    Result := 'System initialization';  // Default to English
  end;
end;

end.