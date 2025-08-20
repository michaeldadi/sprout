# Apple Sign In Setup for Android

This document explains how to set up Apple Sign In for the Android app.

## Overview

Apple Sign In on Android uses a web-based OAuth flow since Apple doesn't provide a native Android SDK. The implementation uses Custom Tabs to open Apple's authentication page and handles the OAuth callback via a deep link.

## Prerequisites

1. **Apple Developer Account**
2. **Service ID configured in Apple Developer Console**
3. **AWS Cognito User Pool with Apple as an identity provider**

## Setup Steps

### 1. Apple Developer Console Setup

1. Sign in to [Apple Developer Console](https://developer.apple.com/)
2. Create a Service ID:
   - Go to Certificates, Identifiers & Profiles
   - Click Identifiers → Add (+) → Services IDs
   - Description: "Sprout Android Sign In"
   - Identifier: `com.services.michaeldadi.sprout`
3. Configure Sign In with Apple:
   - Enable "Sign In with Apple"
   - Click Configure
   - Add your domain and return URLs:
     - Domain: `your-domain.com`
     - Return URL: `https://your-domain.com/auth/apple/callback`
4. Note: For local testing, you'll need to set up a server to handle the callback and redirect to your app

### 2. AWS Cognito Setup

1. In AWS Console, go to Cognito User Pools
2. Select your user pool
3. Go to "Sign-in experience" → "Federated identity provider sign-in"
4. Add Apple as an identity provider:
   - Provider name: `SignInWithApple`
   - Client ID: Your Service ID (e.g., `com.services.michaeldadi.sprout`)
   - Team ID: Your Apple Team ID
   - Key ID: Your Apple private key ID
   - Private key: Upload your Apple private key (.p8 file)
5. Configure attribute mapping:
   - `email` → `email`
   - `name` → `name`

### 3. App Configuration

Update `AppConfig.kt` with your actual values:

```kotlin
object AppConfig {
    // Apple Sign In Configuration
    const val appleSignInServiceId = "com.services.michaeldadi.sprout" // Your Service ID
    
    // AWS Configuration
    const val cognitoUserPoolId = "us-east-1_XXXXXXXXX" // Your User Pool ID
    const val cognitoClientId = "XXXXXXXXXXXXXXXXXXXXXXXXXX" // Your App Client ID
}
```

### 4. Backend Requirements

For production, you need a backend server to:

1. Handle the Apple OAuth callback
2. Exchange the authorization code for tokens
3. Validate the tokens
4. Create/update the user in Cognito
5. Redirect back to your app with the tokens

Example backend flow:
```
1. App opens: https://appleid.apple.com/auth/authorize?...
2. User authenticates
3. Apple redirects to: https://your-backend.com/auth/apple/callback
4. Backend exchanges code for tokens
5. Backend creates/updates Cognito user
6. Backend redirects to: com.michaeldadi.sprout://auth/apple/callback?tokens=...
7. App handles the deep link and signs in the user
```

### 5. Testing Apple Sign In

1. For development, you can use a tool like ngrok to expose a local server
2. Update your Service ID return URL to your ngrok URL
3. Implement a simple server to handle the callback and redirect to your app

### 6. Custom Authentication Flow (Optional)

If you want to use Cognito's custom authentication flow:

1. Create Lambda triggers for:
   - `DefineAuthChallenge`
   - `CreateAuthChallenge`
   - `VerifyAuthChallengeResponse`
2. Configure your Lambda functions to handle Apple Sign In
3. Update the AuthService to use the custom auth flow

## Current Implementation

The current implementation includes:

1. **AppleSignInService**: Handles the OAuth flow using Custom Tabs
2. **AuthService**: Processes Apple Sign In tokens and creates/signs in users
3. **MainActivity**: Handles the OAuth callback deep link
4. **UI Integration**: Login and SignUp screens have Apple Sign In buttons

## Security Considerations

1. Always validate ID tokens on your backend
2. Use PKCE (implemented in AppleSignInService)
3. Verify the `state` parameter to prevent CSRF attacks
4. Store sensitive data securely
5. Use HTTPS for all communications

## Troubleshooting

1. **"Invalid client" error**: Check your Service ID configuration
2. **Redirect not working**: Ensure your deep link is properly configured in AndroidManifest.xml
3. **User not created in Cognito**: Check your Lambda triggers or backend implementation
4. **Token validation fails**: Ensure your Apple keys are correctly configured in Cognito

## References

- [Sign In with Apple REST API](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api)
- [AWS Cognito Apple Integration](https://docs.aws.amazon.com/cognito/latest/developerguide/apple.html)
- [Android Custom Tabs](https://developer.chrome.com/docs/android/custom-tabs)