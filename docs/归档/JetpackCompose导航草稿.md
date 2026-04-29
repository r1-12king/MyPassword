# Jetpack Compose Navigation Draft

## Goal

This document provides a practical navigation draft for the Android password manager MVP using Jetpack Compose Navigation.

The focus is:

- Stable route naming
- Clear parameter rules
- Simple screen transitions
- A navigation shape that fits the agreed MVP scope

This is intentionally limited to MVP. It does not include sync, passkeys, or advanced multi-pane tablet patterns.

## Navigation Principles

- Keep route names short and stable
- Prefer typed arguments over ad hoc string passing
- Pass IDs, not full objects
- Keep sensitive data out of route strings
- Use one main `NavHost` for MVP
- Keep dialogs and transient flows outside the main graph where possible

## Route List

Recommended route set:

- `lock`
- `setup`
- `home`
- `credential_detail/{credentialId}`
- `credential_edit`
- `credential_edit/{credentialId}`
- `password_generator`
- `import`
- `settings`
- `export_backup`

Optional route:

- `search`

## Route Definitions

### `lock`

Purpose:

- Entry screen after cold start
- Checks initialization state
- Unlocks existing vault

Arguments:

- None

Outputs:

- Navigate to `setup` if vault is not initialized
- Navigate to `home` if unlock succeeds

### `setup`

Purpose:

- First-run vault creation

Arguments:

- None

Outputs:

- On success, navigate to `home` and clear setup from back stack

### `home`

Purpose:

- Main credential list
- Search
- Entry point for add, import, settings

Arguments:

- None

Outputs:

- Open detail
- Open add flow
- Open import
- Open settings

### `credential_detail/{credentialId}`

Purpose:

- View one credential record

Arguments:

- `credentialId: String`

Outputs:

- Edit current credential
- Delete and return to `home`

### `credential_edit`

Purpose:

- Create new credential

Arguments:

- None

Outputs:

- Save and go to detail or home
- Open password generator

### `credential_edit/{credentialId}`

Purpose:

- Edit existing credential

Arguments:

- `credentialId: String`

Outputs:

- Save and return to detail
- Open password generator

### `password_generator`

Purpose:

- Generate password for create or edit flow

Arguments:

- None in the route itself

Notes:

- Generated password should be returned via `SavedStateHandle`, not embedded in route arguments

### `import`

Purpose:

- Import data from CSV or app backup

Arguments:

- None

Outputs:

- Return to `home` after import

### `settings`

Purpose:

- Security settings and data-management actions

Arguments:

- None

Outputs:

- Open `import`
- Open `export_backup`
- Trigger lock action back to `lock`

### `export_backup`

Purpose:

- Focused encrypted export flow

Arguments:

- None

Outputs:

- Return to `settings`

### `search` (optional)

Purpose:

- Separate result list if inline search on `home` becomes too limiting

Arguments:

- Optional initial query

Notes:

- For MVP, prefer inline search on `home`

## Route Model Suggestion

Use a central route definition object. For MVP, sealed classes or a small route object set are both fine.

Example:

```kotlin
sealed interface AppRoute {
    val route: String

    data object Lock : AppRoute {
        override val route = "lock"
    }

    data object Setup : AppRoute {
        override val route = "setup"
    }

    data object Home : AppRoute {
        override val route = "home"
    }

    data object CredentialCreate : AppRoute {
        override val route = "credential_edit"
    }

    data object PasswordGenerator : AppRoute {
        override val route = "password_generator"
    }

    data object Import : AppRoute {
        override val route = "import"
    }

    data object Settings : AppRoute {
        override val route = "settings"
    }

    data object ExportBackup : AppRoute {
        override val route = "export_backup"
    }

    data object CredentialDetail : AppRoute {
        override val route = "credential_detail/{credentialId}"

        fun create(credentialId: String): String {
            return "credential_detail/$credentialId"
        }
    }

    data object CredentialEdit : AppRoute {
        override val route = "credential_edit/{credentialId}"

        fun create(credentialId: String): String {
            return "credential_edit/$credentialId"
        }
    }
}
```

## Navigation Graph Shape

Recommended MVP graph:

```text
root
|- lock
|- setup
|- home
|  |- credential_detail/{credentialId}
|  |- credential_edit
|  |- credential_edit/{credentialId}
|  |- password_generator
|  |- import
|  |- settings
|     |- export_backup
```

This can live in one `NavHost` initially. There is no strong need to split auth and main graphs yet, because the app does not have remote authentication in MVP.

## Suggested NavHost Skeleton

```kotlin
@Composable
fun PasswordManagerNavHost(
    navController: NavHostController,
    startDestination: String = AppRoute.Lock.route,
) {
    NavHost(
        navController = navController,
        startDestination = startDestination,
    ) {
        composable(AppRoute.Lock.route) {
            LockRoute(
                onNeedsSetup = {
                    navController.navigate(AppRoute.Setup.route) {
                        popUpTo(AppRoute.Lock.route) { inclusive = true }
                    }
                },
                onUnlockSuccess = {
                    navController.navigate(AppRoute.Home.route) {
                        popUpTo(AppRoute.Lock.route) { inclusive = true }
                    }
                },
            )
        }

        composable(AppRoute.Setup.route) {
            SetupRoute(
                onSetupComplete = {
                    navController.navigate(AppRoute.Home.route) {
                        popUpTo(AppRoute.Setup.route) { inclusive = true }
                    }
                },
                onBack = { navController.popBackStack() },
            )
        }

        composable(AppRoute.Home.route) {
            HomeRoute(
                onOpenCredential = { credentialId ->
                    navController.navigate(AppRoute.CredentialDetail.create(credentialId))
                },
                onAddCredential = {
                    navController.navigate(AppRoute.CredentialCreate.route)
                },
                onOpenImport = {
                    navController.navigate(AppRoute.Import.route)
                },
                onOpenSettings = {
                    navController.navigate(AppRoute.Settings.route)
                },
            )
        }

        composable(AppRoute.CredentialCreate.route) {
            CredentialEditRoute(
                credentialId = null,
                onBack = { navController.popBackStack() },
                onOpenGenerator = {
                    navController.navigate(AppRoute.PasswordGenerator.route)
                },
                onSaveComplete = { credentialId ->
                    navController.navigate(AppRoute.CredentialDetail.create(credentialId)) {
                        popUpTo(AppRoute.CredentialCreate.route) { inclusive = true }
                    }
                },
            )
        }

        composable(
            route = AppRoute.CredentialDetail.route,
            arguments = listOf(navArgument("credentialId") { type = NavType.StringType }),
        ) { entry ->
            val credentialId = entry.arguments?.getString("credentialId").orEmpty()
            CredentialDetailRoute(
                credentialId = credentialId,
                onBack = { navController.popBackStack() },
                onEdit = {
                    navController.navigate(AppRoute.CredentialEdit.create(credentialId))
                },
                onDeleted = {
                    navController.popBackStack(AppRoute.Home.route, false)
                },
            )
        }

        composable(
            route = AppRoute.CredentialEdit.route,
            arguments = listOf(navArgument("credentialId") { type = NavType.StringType }),
        ) { entry ->
            val credentialId = entry.arguments?.getString("credentialId").orEmpty()
            CredentialEditRoute(
                credentialId = credentialId,
                onBack = { navController.popBackStack() },
                onOpenGenerator = {
                    navController.navigate(AppRoute.PasswordGenerator.route)
                },
                onSaveComplete = {
                    navController.popBackStack()
                },
            )
        }

        composable(AppRoute.PasswordGenerator.route) {
            PasswordGeneratorRoute(
                onBack = { navController.popBackStack() },
                onUsePassword = { generatedPassword ->
                    navController.previousBackStackEntry
                        ?.savedStateHandle
                        ?.set("generated_password", generatedPassword)
                    navController.popBackStack()
                },
            )
        }

        composable(AppRoute.Import.route) {
            ImportRoute(
                onBack = { navController.popBackStack() },
                onImportComplete = { navController.popBackStack() },
            )
        }

        composable(AppRoute.Settings.route) {
            SettingsRoute(
                onBack = { navController.popBackStack() },
                onOpenImport = { navController.navigate(AppRoute.Import.route) },
                onOpenExportBackup = { navController.navigate(AppRoute.ExportBackup.route) },
                onLockNow = {
                    navController.navigate(AppRoute.Lock.route) {
                        popUpTo(0) { inclusive = true }
                    }
                },
            )
        }

        composable(AppRoute.ExportBackup.route) {
            ExportBackupRoute(
                onBack = { navController.popBackStack() },
                onExportComplete = { navController.popBackStack() },
            )
        }
    }
}
```

## Navigation Event Conventions

Keep navigation decisions out of UI-heavy composables as much as possible.

Recommended pattern:

- Screen-level composable exposes intent callbacks
- ViewModel emits state and one-off UI events
- Navigation is handled by the route wrapper or host layer

Example callback set:

```kotlin
data class HomeActions(
    val onOpenCredential: (String) -> Unit,
    val onAddCredential: () -> Unit,
    val onOpenImport: () -> Unit,
    val onOpenSettings: () -> Unit,
)
```

## Passing Data Between Screens

Use these rules:

- Route args for stable identifiers only
- `SavedStateHandle` for temporary return values
- Shared ViewModel only when multiple screens truly edit one shared draft

For MVP:

- Pass `credentialId` through route args
- Return generated password through `SavedStateHandle`
- Do not pass master password, plaintext secrets, or large serialized objects through navigation

Example generator return:

```kotlin
val generatedPassword =
    navController.currentBackStackEntry
        ?.savedStateHandle
        ?.getStateFlow<String?>("generated_password", null)
```

After consuming it, clear it:

```kotlin
navController.currentBackStackEntry
    ?.savedStateHandle
    ?.set("generated_password", null)
```

## Back Stack Rules

Recommended behavior:

- `lock -> home`: clear `lock`
- `setup -> home`: clear `setup`
- `credential_create -> detail`: clear create route after successful save
- `settings -> lock now`: clear the whole stack
- `delete credential from detail`: pop back to `home`

This keeps the back behavior understandable and prevents returning to invalid states.

## Start Destination Strategy

For MVP, compute the start destination from a lightweight app bootstrap state:

- If no vault exists: start at `setup`
- If vault exists but app is locked: start at `lock`
- If app process is alive and vault is still unlocked: start at `home`

In many apps, it is still simpler to always start at `lock` and let that screen redirect.

Recommended first implementation:

- Start at `lock`
- Let the `lock` screen inspect initialization state and route onward

This is simpler and reduces launch branching in the `Activity`.

## Suggested Package Layout

Example package structure:

```text
ui/
  navigation/
    AppRoute.kt
    PasswordManagerNavHost.kt
  lock/
    LockRoute.kt
    LockScreen.kt
    LockViewModel.kt
  setup/
    SetupRoute.kt
    SetupScreen.kt
    SetupViewModel.kt
  home/
    HomeRoute.kt
    HomeScreen.kt
    HomeViewModel.kt
  credential/
    detail/
    edit/
  generator/
  importing/
  settings/
```

## Recommended MVP Simplifications

To keep the first implementation moving:

- Keep search inline in `home`
- Use one root `NavHost`
- Avoid nested graphs until sync or onboarding complexity grows
- Treat password generator as a normal destination, not a modal bottom sheet at first
- Keep add and edit as two routes backed by one reusable screen

## What To Avoid

- Passing whole credential objects in route strings
- Encoding sensitive fields into route parameters
- Over-splitting the graph before the app has real complexity
- Mixing navigation calls deep inside reusable leaf composables
- Letting screen state depend directly on back stack parsing everywhere

## Next Step

After this navigation draft, the most useful next artifact would be one of these:

- Jetpack Compose screen-by-screen route contracts
- ViewModel state models for each MVP screen
- Room or SQLCipher local database schema draft
