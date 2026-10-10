# FastFlags Manager (iOS)

A native SwiftUI JSON editor for Roblox-style FastFlags configuration files.

## What it does
- Search, add, edit, and delete JSON flags
- Toggle Boolean flags
- Validate and preview JSON
- Import a `.json` file
- Export/share `ClientAppSettings.json`
- Includes example presets

## Important limitations
This app edits and exports JSON. It does not bypass iOS sandboxing, write into Roblox's private app container, or guarantee that Roblox for iOS will honor a given flag. Only use flags supported by the target client.

## Build entirely from iPad using GitHub Actions
1. In Safari, sign in to GitHub and create a new **public** repository named `FastFlagsManager`.
2. Upload the contents of this ZIP to the repository (extract the ZIP first if your upload method requires it).
3. Open the repository's **Actions** tab and enable GitHub Actions if prompted.
4. Run the workflow named **Build unsigned iOS IPA** from **Run workflow**.
5. When it finishes, open the workflow run and download the `FastFlagsManager-unsigned-ipa` artifact.
6. In SideStore, use its install/import IPA flow to select the downloaded `.ipa`. SideStore may sign it with your configured Apple ID; the app still needs normal signing/refresh.
7. If SideStore rejects the artifact, share the exact error message so the build/signing steps can be adjusted.

GitHub Actions on a public repository can provide free hosted builds subject to GitHub's current limits. No paid build service is required for this workflow.

## Notes
The workflow builds an unsigned device `.app` and packages it into an `.ipa` container. SideStore is used for installation/signing; the workflow itself does not sign with an Apple developer certificate.
