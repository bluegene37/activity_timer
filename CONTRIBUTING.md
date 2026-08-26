# Contributing to Activity Timer

Thank you for your interest in contributing to **Activity Timer**! We are committed to building an offline-first, private, and delightful timer experience.

---

## 🧭 Code of Conduct

We are dedicated to providing a welcoming, inclusive, and harassment-free environment for all contributors. Please be respectful, constructive, and open to feedback during all discussions and code reviews.

---

## 🛠️ Development Setup

### Prerequisites
- **Flutter SDK**: `^3.7.0` (Stable channel)
- **Dart SDK**: `^3.7.0`
- **JDK**: 17+ (for Android builds)
- **Xcode**: 15+ (for iOS builds, macOS required)

### Workflow Steps

1. **Fork and clone the repository**:
   ```bash
   git clone https://github.com/your-username/activity_timer.git
   cd activity_timer
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate code artifacts (Hive type adapters)**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Verify local environment**:
   ```bash
   flutter analyze --fatal-infos
   flutter test
   ```

---

## 🌿 Branching Strategy

- **`main`**: Always releasable, stable branch.
- **Feature branches**: Create descriptive branches from `main`:
  - `feature/add-vibrations-profile`
  - `fix/interval-boundary-rounding`
  - `docs/update-architecture-guide`
  - `refactor/extract-timer-ring`

---

## 💬 Commit Message Standards

We strictly adhere to the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification:

```text
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

### Supported Types
- **`feat`**: A new user-facing feature.
- **`fix`**: A bug fix.
- **`docs`**: Documentation only changes.
- **`style`**: Code formatting, missing semicolons, etc. (no production code change).
- **`refactor`**: Code restructuring without changing external behavior or fixing bugs.
- **`perf`**: Performance optimizations.
- **`test`**: Adding missing tests or correcting existing tests.
- **`chore`**: Maintenance tasks, dependency bumps, CI configuration.

**Example**:
```text
feat(coffee): add bloom time visualizer to brew execution screen
fix(interval): prevent negative countdown duration when system time jumps
test(routine): add widget test for routine drag and drop reordering
```

---

## 📐 Code Style & Quality Standards

1. **Strict Analyzer Rules**:
   The repository uses strict type checking configured in `analysis_options.yaml`:
   - `strict-casts: true`
   - `strict-inference: true`
   - `strict-raw-types: true`
   Any type ambiguity or raw generics will fail analysis.

2. **House Style Guidelines**:
   - Use **single quotes** for string literals.
   - Use `prefer_final_locals` everywhere.
   - Explicit return types are required on all functions and methods (`always_declare_return_types`).
   - Use constructor super parameters: `MyWidget({super.key})`.
   - Never edit generated `*.g.dart` files directly; re-run `build_runner`.

3. **Format Validation**:
   Ensure all Dart files adhere to standard formatting before opening a PR:
   ```bash
   dart format --set-exit-if-changed lib test
   ```

---

## 🧪 Testing Guidelines

Every change must be accompanied by appropriate automated tests:

- **Unit Tests**: Cover models, state calculations, string formatting, and controllers.
- **Widget Tests**: Ensure UI widgets render accurately across light and dark themes and handle user taps/drags properly.
- **Platform Mocking**: Platform channels such as `audioplayers` and `wakelock_plus` must be mocked in test setup (see `test/timer_screen_test.dart` and `test/settings_screen_test.dart` for reference mocks).

Run the full suite with:
```bash
flutter test --coverage
```

---

## 🚀 Pull Request Checklist

Before submitting your pull request, verify:

- [ ] My branch is up to date with `main`.
- [ ] `flutter analyze --fatal-infos` reports 0 issues.
- [ ] `dart format --set-exit-if-changed lib test` passes without changes.
- [ ] All tests in `flutter test` pass 100%.
- [ ] New functionality or bug fixes include corresponding unit/widget tests.
- [ ] Documentation (`README.md`, `ARCHITECTURE.md`, `CHANGELOG.md`) is updated if applicable.
- [ ] Commit history is clean and adheres to Conventional Commits.
