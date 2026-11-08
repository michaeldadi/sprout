# Sprout

Sprout is a personal finance app under development for iOS and Android. This repository contains the native apps, TypeScript API handlers, and AWS infrastructure. The product aims to help people understand their finances, subscriptions, and goals; some flows and integrations are still incomplete.

## Repository layout

| Path | Contents |
| --- | --- |
| `apps/ios/` | SwiftUI app, Xcode project, and iOS tests |
| `apps/android/` | Jetpack Compose app, Gradle project, and Android tests |
| `services/api/` | TypeScript handlers for authentication, transactions, sync, chat, and uploads |
| `infra/` | AWS CDK stack, deployment scripts, and database migrations |
| `.github/workflows/` | Mobile CI and deployment workflows |

The mobile apps have their own build systems. The root Yarn workspace is for the TypeScript services and infrastructure; there is no single command that starts the entire product locally.

## Prerequisites

- **iOS:** macOS, Xcode, and an iOS Simulator.
- **Android:** Android Studio or the Android SDK with API 36, plus JDK 17. The Gradle wrapper is included.
- **Services and infrastructure:** Node.js with Corepack, which selects the repository's Yarn 4.9.2 version. AWS credentials are needed only for AWS operations.

## Run the mobile apps

### Android

Open `apps/android/` in Android Studio and run the `app` configuration on an emulator or device. To build the debug APK and run the JVM unit tests from a terminal:

```bash
cd apps/android
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

Gradle reads optional third-party SDK values from `apps/.env.local`. The Android variable names are listed in `apps/android/.env.local.example`. A build can succeed without working credentials for every external service.

### iOS

Open `apps/ios/Sprout.xcodeproj` in Xcode, select the shared **Sprout CI** scheme and a simulator, then build or run the app. Xcode resolves the project's Swift package dependencies.

The build script creates ignored `Secrets.swift` files. For Debug builds it reads `apps/.env.local` when present and otherwise generates placeholder values. Placeholders satisfy that configuration input but do not provide working service connections. Keep local configuration and generated secrets out of Git.

As of November 2026, a full local build with Xcode 27.2 stops in pinned third-party Swift packages before Sprout source compiles. The [Mobile CI workflow](.github/workflows/mobile-ci.yml) uses a separate macOS runner; its result should be checked independently.

## Work on services and infrastructure

Install the root workspace dependencies with the pinned Yarn version:

```bash
corepack yarn install --immutable
```

The API handlers live in `services/api/`; the AWS resources that use them are defined in `infra/`. To type-check and build the infrastructure package:

```bash
corepack yarn workspace infra build
```

Review the environment-specific scripts in `infra/` before any deployment or migration. The repository does not define a local API server or a root `start` script.

## Checks

The [Mobile CI workflow](.github/workflows/mobile-ci.yml) selects iOS and Android jobs from the changed paths. Android CI builds the debug app and runs the JVM unit suite. iOS CI builds the app and runs a focused simulator smoke test. These checks do not establish that every integration or user journey is complete.
