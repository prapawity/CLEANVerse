# Platform and competitor research

Research date: 2026-11-21. This is a design baseline, not an assertion that CLEANVerse implements the capabilities described here. Sources are primary documentation except where identified.

## Competitor: CleanMyMac

MacPaw combines cleanup, protection, performance, app management and duplicate discovery in Smart Care; users can review results. Its separate modules include Space Lens and cloud cleanup. The direct, Setapp and App Store editions differ because of platform and distribution restrictions. The product's combination and review flow are useful inspiration, but its branding and assets must not be copied. [Smart Care](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care), [edition matrix](https://cms-static.macpaw.com/support/cleanmymac/knowledgebase/missing-features).

At research time, the vendor listed a seven-day trial, monthly and annual subscriptions, and one-time purchases; pricing and offers are variable. One-time licenses may exclude later features. This is a market reference, not a pricing recommendation. [Pricing](https://macpaw.com/store/cleanmymac), [activation](https://cms-static.macpaw.com/support/cleanmymac/knowledgebase/installation-activation), [upgrade terms](https://macpaw.com/support/cleanmymac/knowledgebase/upgrade).

Macworld independently praised breadth and usability while noting price and remaining technical complexity. Existing OS tools also compete: Windows Storage Sense removes some temporary items and can manage cloud placeholders. Differentiation must therefore come from clarity, safe handling and cross-device convenience rather than claims that basic cleanup is unique. [Macworld review](https://www.macworld.com/article/352922/cleanmymac-x-review-macos.html), [Storage Sense](https://support.microsoft.com/en-gb/windows/experience/storage-filemanagement/manage-drive-space-with-storage-sense).

## Platform capability matrix

| Platform | Read-only direction | Removal and distribution constraints | Confidence / outstanding validation |
| --- | --- | --- | --- |
| Windows | User-selected folders, sizes and duplicate candidates. | Windows Shell `IFileOperation` supports per-item operations and recycle flags. Recovery depends on item, volume and actual outcome. | Validate native flags, failure/cancel reporting, local, external, network and cloud-placeholder cases. [IFileOperation](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-ifileoperation), [recycle flag](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags). |
| macOS | User-selected files through sandbox entitlements; direct and App Store variants differ. | Full Disk Access is user granted and does not eliminate SIP, sandbox and other access controls. Do not require it for the first slice. | Verify signed builds and selected-folder access for each distribution channel. [Apple sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), [CleanMyMac edition matrix](https://cms-static.macpaw.com/support/cleanmymac/knowledgebase/missing-features). |
| Linux | User-selected folders on named, tested desktop distributions. | Trash behavior varies with filesystem and environment; the freedesktop specification defines multiple trash locations and metadata. | Choose and test a supported native integration rather than implement ad hoc moves. [Trash specification](https://specifications.freedesktop.org/trash/latest/). |
| Android | Authorized media through MediaStore and selected documents via Storage Access Framework. | Scoped storage applies. Google Play restricts broad All files access and requires declaration and approval for eligible uses. `createDeleteRequest` is permanent deletion; `createTrashRequest` is a different operation. | Validate picker scope, consent, supported SDKs and device-specific behavior. [Storage](https://developer.android.com/training/data-storage/), [Play policy](https://support.google.com/googleplay/android-developer/answer/10467955?hl=en), [MediaStore](https://developer.android.com/training/data-storage/shared/media). |
| iOS | Authorized photos and selected documents, within granted scope. | App sandbox prevents generic access to other apps' private data. PhotoKit changes require an OS-mediated change request. Apple explicitly prohibits misleading iOS malware scanner claims. | Validate limited-library permissions, iCloud assets and change results on real devices. [Apple filesystem](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemDetails/FileSystemDetails.html), [PhotoKit changes](https://developer.apple.com/documentation/photokit/requesting-changes-to-the-photo-library), [App Review](https://developer.apple.com/app-store/review/guidelines/). |

## Architecture implications

Flutter supports the target platform families but support varies by version and CPU architecture. Use platform adapters and capability reporting rather than a single assumed filesystem model. Pigeon supports typed platform channels; use native APIs for OS-specific grants and identity. Flutter recommends distinct UI and data layers with repositories and services. [Flutter platforms](https://docs.flutter.dev/reference/supported-platforms), [Flutter architecture](https://docs.flutter.dev/app-architecture/recommendations), [Pigeon](https://docs.flutter.dev/interop/pigeon).

The October 2026 Apple announcement says future macOS Full Disk Access controls will require explicit user action; it does not specify their exact implementation or release date. Treat it as a reason to design for limited access, not as evidence of a particular restriction already in force. [Apple announcement](https://developer.apple.com/news/?id=p6zjojqw).

## Unknowns requiring experiments

1. Current Flutter plugin support, maintenance, sandbox entitlements and whether a direct native adapter is needed on each host.
2. Actual recycle behavior and recovery on each tested filesystem and external volume; Android/iOS delete consent and cloud synchronization effects.
3. Reliable hard-link, cloud-placeholder, junction and changed-file identity detection on each platform.
4. Representative scan performance, memory use and battery impact; define targets only after measurement.
5. Named minimum OS versions, supported Linux distributions, store distribution model, pricing, and user demand.

## Prototype risk assessment

The Python prototype has not undergone the future removal safety gate. It logs full paths after removal, does not enforce keeping one duplicate, and has not been integration-tested across platforms. It should not be treated as a production cleaner or evidence of recoverability. New Flutter work begins read-only.

