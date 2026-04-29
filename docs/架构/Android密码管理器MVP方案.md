# Android Password Manager MVP

## Scope

This document captures the agreed MVP scope for an Android-first password manager. The goal is to ship a credible local-first password vault before expanding into sync, passkeys, or multi-user collaboration.

Core principles:

- Build a secure local vault first
- Prefer a complete usable loop over feature breadth
- Treat autofill, sync, and passkeys as later phases
- Keep the first release focused on trust, speed, and clarity

## MVP Feature Priority

| Priority | Feature | MVP Required | Why It Matters | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| P0 | Master password setup and unlock | Yes | Defines the vault boundary and unlock flow | User can create a master password and must unlock after app restart |
| P0 | Local encrypted storage | Yes | Security foundation for the entire product | All vault records are stored encrypted, with no plaintext secrets written to disk |
| P0 | Credential CRUD | Yes | Core day-to-day utility | User can add, edit, view, and delete password entries |
| P0 | Search and basic organization | Yes | Required once the vault has multiple entries | User can search by title, username, or website |
| P0 | Password generator | Yes | Immediate value for new account creation and rotation | User can generate configurable strong passwords and insert them into an entry |
| P0 | Copy username and password | Yes | Lowest-cost practical usage before autofill | User can copy fields with clear UI feedback and clipboard handling |
| P1 | Biometric unlock | Recommended | Improves repeat-use convenience without removing master-password security | User can unlock with fingerprint or face after initial setup |
| P1 | Auto-lock | Recommended | Reduces exposure when the app is backgrounded or the phone is shared | App locks after a configurable timeout |
| P1 | Screenshot protection | Recommended | Basic shoulder-surfing and screen-capture defense | Sensitive screens block screenshots and recordings where supported |
| P1 | Import from other tools | Recommended | Critical for migration and trial adoption | User can import at least Chrome CSV and Bitwarden CSV |
| P1 | Encrypted backup export | Recommended | Prevents data loss while staying aligned with a secure product | User can export vault data in an app-defined encrypted format |
| P2 | Android Autofill integration | Later | Important product milestone, but materially harder to implement correctly | User can fill credentials in common login surfaces via Android Autofill |
| P2 | TOTP codes | Later | Strong retention feature, not needed for first usable release | User can store a TOTP secret and view current one-time codes |
| P2 | Favorites and recent items | Later | Improves speed, but not core to first release | User can pin favorites or access recently used entries |
| P3 | Cloud sync | Later | Large jump in complexity and security surface | User can securely sync encrypted vault data across devices |
| P3 | Passkeys | Later | Strategically important, but not an MVP dependency | User can create and use passkeys |
| P3 | Sharing and family features | Later | Requires more complex trust and permission models | User can securely share selected items with another person |

## Recommended Build Order

1. Master password setup and local encrypted storage
2. Credential CRUD and search
3. Password generator and copy actions
4. Biometric unlock, auto-lock, and screenshot protection
5. Import and encrypted backup export
6. Android Autofill
7. TOTP
8. Cloud sync and passkeys

## Minimal Launch Scope

The smallest credible launch should include:

- Master password
- Local encrypted vault
- Credential create, edit, view, delete
- Search
- Password generator
- Copy username and password
- Biometric unlock
- Auto-lock
- Import support

Not in MVP:

- Team sharing
- Family plans
- Dark web monitoring
- Email alias integration
- Built-in browser
- Cloud sync at launch
- Passkeys at launch

## MVP Page List

Keep the first version to 8 core pages and 3 optional support pages.

### Core Pages

#### 1. Splash / Lock Screen

Purpose:

- Detect whether the vault has already been initialized
- Unlock with master password
- Unlock with biometrics
- Provide first-use entry

Key elements:

- App name and logo
- Master password input
- Unlock button
- Biometric unlock button
- First-time setup entry
- Error state for failed unlock

#### 2. First-Time Setup Screen

Purpose:

- Create the master password
- Confirm the master password
- Offer biometric unlock
- Set auto-lock preference

Key elements:

- Master password field
- Confirm password field
- Biometric toggle
- Auto-lock timeout selector
- Create vault action

#### 3. Home / Credential List Screen

Purpose:

- Show all saved entries
- Search and filter entries
- Open an existing entry
- Create a new entry

Key elements:

- Search bar
- Credential list
- Favorites or recent section
- Basic category or tag filter
- Floating action button to add an entry

#### 4. Add / Edit Credential Screen

Purpose:

- Create a new credential
- Edit an existing credential

Fields:

- Title
- Username
- Password
- Website or domain
- Notes
- Tags
- Favorite toggle

Actions:

- Generate password
- Show or hide password
- Save
- Delete

#### 5. Credential Detail Screen

Purpose:

- View a single credential record
- Perform fast actions from one place

Key elements:

- Username
- Password
- Website
- Notes
- Last updated time

Actions:

- Copy username
- Copy password
- Open website
- Edit
- Delete

#### 6. Password Generator Screen

Purpose:

- Generate strong passwords and return them to the edit flow

Key elements:

- Generated password output
- Length slider
- Uppercase toggle
- Lowercase toggle
- Number toggle
- Symbol toggle
- Exclude confusing characters toggle
- Regenerate action
- Use this password action

#### 7. Import Screen

Purpose:

- Import vault data from other products or local backups

Supported formats for MVP:

- Chrome CSV
- Bitwarden CSV
- App backup file

Key elements:

- File picker
- Format detection state
- Import preview
- Conflict warning
- Start import action

#### 8. Settings Screen

Purpose:

- Manage security options and data operations

Suggested sections:

- Biometric unlock toggle
- Auto-lock timeout
- Screenshot protection toggle
- Import data
- Export encrypted backup
- Clipboard clear timeout
- Lock now
- About

### Optional Support Pages

#### 9. Search Results Screen

This can be skipped if search stays inline on the home screen.

#### 10. Export Backup Screen

Use this if export becomes large enough to deserve a focused flow.

Suggested elements:

- Backup password field
- Export location picker
- Security warning
- Confirm export action

#### 11. Empty State / Onboarding Screen

Use this when the vault has no entries yet.

Suggested actions:

- Add first password
- Import existing passwords
- Read a short security explanation

## Navigation Structure

```text
[Splash / Lock Screen]
  |- Uninitialized -> [First-Time Setup Screen]
  |                    |- Setup complete -> [Home / Credential List Screen]
  |- Initialized -> unlock success -> [Home / Credential List Screen]

[Home / Credential List Screen]
  |- Tap entry -> [Credential Detail Screen]
  |                |- Edit -> [Add / Edit Credential Screen]
  |- Tap add -> [Add / Edit Credential Screen]
  |              |- Generate password -> [Password Generator Screen]
  |- Tap search -> [Search Results Screen] or inline search on home
  |- Tap import -> [Import Screen]
  |- Tap settings -> [Settings Screen]
                     |- Import data -> [Import Screen]
                     |- Export backup -> [Export Backup Screen]

[Add / Edit Credential Screen]
  |- Save success -> [Credential Detail Screen] or [Home / Credential List Screen]
  |- Generate password -> [Password Generator Screen]
                          |- Use this password -> back to [Add / Edit Credential Screen]

[Credential Detail Screen]
  |- Edit -> [Add / Edit Credential Screen]
  |- Delete -> back to [Home / Credential List Screen]
```

## Bottom Navigation Recommendation

Keep bottom navigation minimal.

Preferred tabs:

- Passwords
- Import
- Settings

If the product needs to stay even leaner, remove bottom navigation entirely and keep:

- Settings in the top-right of the home screen
- Import exposed through home empty state and settings

## Compressed Page Set

If implementation speed is the top priority, the MVP can be reduced to 6 pages:

- Splash / Lock Screen
- First-Time Setup Screen
- Home / Credential List Screen
- Credential Detail Screen
- Add / Edit Credential Screen
- Settings Screen

In that reduced version, the password generator, import flow, and export flow can be handled as dialogs or subflows instead of dedicated screens.
