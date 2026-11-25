# Sprout

Sprout is a personal finance app under development for iOS and Android. The native apps use Appwrite Auth and Appwrite Functions. Appwrite also hosts the Clear sky marketing website and its private forms. The legacy AWS code remains available for migration and rollback.

## Repository layout

| Path                 | Contents                                                                      |
| -------------------- | ----------------------------------------------------------------------------- |
| `apps/ios/`          | SwiftUI app, Xcode project, and iOS tests                                     |
| `apps/android/`      | Jetpack Compose app, Gradle project, and Android tests                        |
| `apps/web/`          | TanStack Start marketing website, journal, waitlist, and inquiry forms        |
| `infra/appwrite/`    | Staging and production Appwrite configuration                                |
| `services/functions/` | Appwrite Functions for the finance API, background jobs, and privacy          |
| `services/contracts/` | Shared API and native client contracts                                      |
| `services/api/`      | Legacy AWS handlers                                                         |
| `infra/`             | Legacy AWS CDK stack and migrations                                          |
| `.github/workflows/` | Mobile CI and deployment workflows                                            |

The mobile apps have their own build systems. The root Yarn workspace is for the website, TypeScript services, and infrastructure; there is no single command that starts the entire product locally.

## Prerequisites

- **iOS:** macOS, Xcode, and an iOS Simulator.
- **Android:** Android Studio or the Android SDK with API 36, plus JDK 17. The Gradle wrapper is included.
- **Services and infrastructure:** Node.js with Corepack, which selects the repository's Yarn 4.9.2 version. AWS credentials are needed only for AWS operations.

## Run the website

Use Node 22.12+ and the root Yarn 4.9.2 workspace:

```bash
corepack yarn install --immutable
corepack yarn web:dev
corepack yarn web:check
```

See [website setup](apps/web/README.md), [implementation and acceptance](docs/web/implementation-plan.md), and [release status](docs/web/validation.md). Appwrite is the target backend; AWS code is migration inventory. Hosted form writes require the selected environment's exact origin and private table configuration.

## Run the mobile apps

### Android

Open `apps/android/` in Android Studio and run the `app` configuration on an emulator or device. To build the debug APK and run the JVM unit tests from a terminal:

```bash
cd apps/android
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

Gradle reads client configuration from `apps/.env.local`. Set `SPROUT_APPWRITE_ENDPOINT` and `SPROUT_APPWRITE_PROJECT_ID` to the same staging project to test sign-in and sync. Add `SPROUT_GOOGLE_WEB_CLIENT_ID` to test Google sign-in.

### iOS

Open `apps/ios/Sprout.xcodeproj` in Xcode, select the shared **Sprout CI** scheme and a simulator, then build or run the app. Xcode resolves the project's Swift package dependencies.

The build script creates ignored `Secrets.swift` files for client configuration. For Debug builds it reads `apps/.env.local` when present. To sign in locally, set the `SPROUT_APPWRITE_ENDPOINT` and `SPROUT_APPWRITE_PROJECT_ID` Xcode build settings for the staging project. Keep local configuration and generated files out of Git.

## Work on services and infrastructure

Install the root workspace dependencies with the pinned Yarn version:

```bash
corepack yarn install --immutable
```

The financial API runs on Appwrite Functions. Validate its contracts, TypeScript and tests from the root workspace:

```bash
corepack yarn workspace @sprout/services generate --check
corepack yarn workspace @sprout/services build
corepack yarn workspace @sprout/services check:tools
corepack yarn workspace @sprout/services test
```

See the [Appwrite infrastructure runbook](infra/appwrite/README.md) for staging configuration, deployment, and rollback. Appwrite financial infrastructure is enabled for staging. Production activation requires a reviewed migration and release.

## Checks

The [Mobile CI workflow](.github/workflows/mobile-ci.yml) runs Android builds and JVM tests and iOS simulator tests based on changed paths. The [financial CI workflow](.github/workflows/financial-ci.yml) checks backend code, generated contracts, function bundles, and Appwrite Terraform.

The [Web CI workflow](.github/workflows/web-ci.yml) checks the website with TypeScript, lint, form tests, a production build, and browser tests. Legacy AWS deployments and Firebase tester distribution require explicit workflow dispatch.
