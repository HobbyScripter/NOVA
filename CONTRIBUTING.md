# CONTRIBUTING.md - Leitfaden für Mitwirkende

Vielen Dank für Ihr Interesse an der Weiterentwicklung von **PROJECT NOVA OS**.
Um die Qualität, Reproduzierbarkeit und Sicherheit unseres Betriebssystems zu gewährleisten, gelten folgende verbindliche Richtlinien.

---

## 1. Kodierungs- & Technologiestandards

- **C++ (Desktop, Compositor, Systemwerkzeuge)**:
  - Mindeststandard: **C++20** (bevorzugt C++23, wo stabil unterstützt).
  - Code-Style: Modernes C++ mit striktem RAII, Smart Pointern und Ausnahme-Sicherheit.
  - GUI-Entwicklung: **Qt 6** (C++ und QML) mit strikter Trennung von Benutzeroberfläche und Geschäftslogik.
- **Rust (Systemdienste, D-Bus-Daemons, Werkzeuge)**:
  - Edition: **Rust 2021** (oder neuer).
  - Keine unerlaubten `unsafe`-Blöcke ohne formale Sicherheitsbegründung im Code-Review.
  - Strikte Formatierung via `cargo fmt` und Überprüfung via `cargo clippy -- -D warnings`.
- **Python (Build-Tools, Test-Harness, Automatisierung)**:
  - Mindestversion: **Python 3.10+**.
  - Vollständige Typisierung mit `typing` (`mypy --strict`).
  - PEP 8 Konformität (`ruff` / `black`).
- **Shell-Skripte (POSIX / Bash)**:
  - Strikte Header: `set -euo pipefail`.
  - Überprüfung via `shellcheck`.

---

## 2. Git-Workflow & Commit-Richtlinien

Wir verwenden das **Conventional Commits** Format:

```
<type>(<scope>): <kurze Beschreibung im Präsens>

[Optionale ausführliche Begründung der Änderung]

[Optionale Referenzen, z.B. Fixes #123]
```

### Gültige Typen:
- `feat`: Neues Feature / neue Funktionalität (z. B. `feat(compositor): add fractional scaling support`)
- `fix`: Fehlerbehebung (z. B. `fix(installer): handle nvme drive formatting properly`)
- `arch`: Architekturentscheidungen und Konzepte
- `toolchain`: Änderungen an GCC, Clang oder Binutils
- `kernel`: Kernel-Konfiguration, Patches oder Treiber-Updates
- `pkg`: Neue oder aktualisierte RPM-Spezifikationen
- `sec`: Sicherheitsverbesserungen und Profil-Updates
- `test`: Hinzufügen oder Anpassen von Tests
- `docs`: Änderungen an der Dokumentation

---

## 3. Paketierungs-Richtlinien (RPM Specs)

1. Jedes Paket muss eine saubere `.spec`-Datei im Verzeichnis `packages/specs/` besitzen.
2. Es müssen alle Upstream-Lizenzdateien im Paket mit `%license` deklariert sein.
3. Dynamische Bibliotheken müssen mit korrekten `Provides`/`Requires` (automatisch über RPM) deklariert werden.
4. Manuelle Skripte (`%pre`, `%post`, `%preun`, `%postun`) dürfen niemals unkontrolliert fehlschlagen (stets saubere Rückgabewerte gewährleisten).
5. Binärdateien müssen mit den globalen NOVA-Compilerflags kompiliert werden.

---

## 4. Testpflicht vor jedem Commit

Keine Codeänderung darf committed werden, ohne dass die entsprechenden Modul- und Regressionstests erfolgreich durchlaufen wurden:

```powershell
python testing/run_tests.py --suite core
```
