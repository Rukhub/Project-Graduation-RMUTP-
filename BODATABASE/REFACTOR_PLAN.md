# Code Refactoring Plan

## Goal
Refactor long code files to improve maintainability. Focus on the largest file first: `equipment_detail_screen.dart` (5,270 lines).

## Analysis of equipment_detail_screen.dart

The file contains 49 methods that can be grouped into:

| Category | Methods | Approx Lines | Action |
|----------|---------|--------------|--------|
| **Dialogs** | `_showRepairAgainDialog`, `_showImageSourceDialog`, `_showStatusDialog`, `_showAuditDialog`, `_showStartRepairDialog`, `_showFinishRepairDialog` | ~1,500 | Extract to `dialogs/` |
| **Image Handling** | `_pickImageFromGallery`, `_takePhoto`, `_deleteImage`, `_uploadAndUpdateImage` | ~200 | Keep in main file |
| **Status Logic** | `_handleStatusChange`, `_handleFailedRepair`, `_saveAuditLog` | ~300 | Keep in main file |
| **UI Builders** | `_buildImageSection`, `_buildQRCodeSection`, `_buildRepairAgainSection`, `_buildDamagedAuditSection`, etc. | ~800 | Extract to `widgets/` |
| **Data Loading** | `_loadLatestData`, `_loadCheckLogs`, `_subscribeToAssetChanges` | ~500 | Keep in main file |

---

## Proposed Changes

### Phase 1: Create folder structure

```
lib/
├── dialogs/               [NEW]
│   └── equipment_dialogs.dart
├── widgets/               [NEW]
│   └── equipment_detail_widgets.dart
└── equipment_detail_screen.dart  [MODIFY - reduce to ~2,000 lines]
```

---

### Phase 2: Extract Dialogs

#### [NEW] `lib/dialogs/equipment_dialogs.dart`

Extract these dialog functions as standalone functions or a utility class:
- `showRepairAgainDialog()`
- `showImageSourceDialog()`
- `showStatusDialog()`
- `showAuditDialog()`
- `showStartRepairDialog()`
- `showFinishRepairDialog()`

---

### Phase 3: Extract Widgets

#### [NEW] `lib/widgets/equipment_detail_widgets.dart`

Extract these builder methods as separate StatelessWidget classes:
- `EquipmentImageSection` 
- `EquipmentQRCodeSection`
- `RepairAgainSection`
- `DamagedAuditSection`
- `EquipmentInfoRow`

---

## Important Notes

> [!WARNING]
> **This is a significant refactoring task.** 
> - It may introduce bugs if not tested carefully
> - The app should be tested after each phase
> - Consider doing this incrementally over several sessions

---

## Verification Plan

### Manual Testing (User)
1. After each phase, run `flutter run` and test:
   - Open equipment detail screen
   - Test all dialogs (repair, audit, status change)
   - Test image upload/delete
   - Test QR code generation

### Automated Check
```bash
flutter analyze
flutter build apk --debug
```

---

## Questions for User

1. **Do you want me to start with just Phase 1 (folder structure) first?** Or should I do all phases at once?

2. **How much time do you have?** Full refactor may take 30+ minutes. We can do smaller incremental changes instead.

3. **Any specific screens you use most often?** I can prioritize those for testing.
