#!/bin/bash

# Script to generate Secrets.swift for different environments

# Set defaults for manual testing
if [ -z "$CONFIGURATION" ]; then
    CONFIGURATION="Debug"
    echo "⚠️ No CONFIGURATION set, defaulting to Debug"
fi

if [ -z "$SRCROOT" ]; then
    # When run manually, assume we're in the Scripts directory
    SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
    echo "⚠️ No SRCROOT set, using: $SRCROOT"
fi

echo "🔧 Generating Secrets.swift for $CONFIGURATION configuration..."

# Generate in the Sprout folder which is already synchronized with Xcode
mkdir -p "$SRCROOT/Sprout/Generated"
OUTPUT_FILE="$SRCROOT/Sprout/Generated/Secrets.swift"

# Function to generate secrets file
generate_secrets() {
    local api_key="$1"
    local api_base_url="$2"
    local mixpanel_token="$3"
    local secret_api_key="$4"
    local zendesk_app_id="$5"
    local zendesk_client_id="$6"
    local braze_api_key="$7"
    local braze_endpoint="$8"
    
    cat > "$OUTPUT_FILE" << ENDOFFILE
// Auto-generated file - DO NOT EDIT
// Generated at: $(date)
// Configuration: $CONFIGURATION

struct Secrets {
    static let apiKey = "$api_key"
    static let apiBaseURL = "$api_base_url"
    static let mixpanelProjectToken = "$mixpanel_token"
    static let secretAPIKey = "$secret_api_key"
    static let zendeskAppId = "$zendesk_app_id"
    static let zendeskClientId = "$zendesk_client_id"
    static let brazeApiKey = "$braze_api_key"
    static let brazeEndpoint = "$braze_endpoint"
}
ENDOFFILE
}

# Check configuration type
case "$CONFIGURATION" in
    "Debug")
        # For Debug, try to use .env.local first
        ENV_FILE="$SRCROOT/../.env.local"
        if [ -f "$ENV_FILE" ]; then
            echo "✅ Found .env.local for Debug build"
            source "$ENV_FILE"
            generate_secrets \
                "$API_KEY" \
                "$API_BASE_URL" \
                "$MIXPANEL_PROJECT_TOKEN" \
                "$SECRET_API_KEY" \
                "$ZENDESK_APP_ID" \
                "$ZENDESK_CLIENT_ID" \
                "$BRAZE_API_KEY" \
                "${BRAZE_ENDPOINT:-sdk.us-09.braze.com}"
        else
            echo "⚠️ No .env.local found, using debug defaults"
            generate_secrets \
                "debug_api_key" \
                "https://dev-api.yourapp.com" \
                "debug_mixpanel_token" \
                "debug_secret_key" \
                "debug_zendesk_app_id" \
                "debug_zendesk_client_id" \
                "debug_braze_api_key" \
                "sdk.us-09.braze.com"
        fi
        ;;
        
    "Staging")
        echo "📦 Generating secrets for Staging"
        # For Staging, use environment variables or staging defaults
        generate_secrets \
            "${STAGING_API_KEY:-staging_api_key}" \
            "${STAGING_API_BASE_URL:-https://staging-api.yourapp.com}" \
            "${STAGING_MIXPANEL_TOKEN:-staging_mixpanel_token}" \
            "${STAGING_SECRET_API_KEY:-staging_secret_key}" \
            "${STAGING_ZENDESK_APP_ID:-staging_zendesk_app_id}" \
            "${STAGING_ZENDESK_CLIENT_ID:-staging_zendesk_client_id}" \
            "${STAGING_BRAZE_API_KEY:-staging_braze_api_key}" \
            "${STAGING_BRAZE_ENDPOINT:-sdk.us-09.braze.com}"
        ;;
        
    "Release")
        echo "🚀 Generating secrets for Release"
        
        # Try to source .env.release if it exists
        RELEASE_ENV_FILE="$SRCROOT/../.env.local.release"
        if [ -f "$RELEASE_ENV_FILE" ]; then
            echo "📄 Found .env.local.release file"
            source "$RELEASE_ENV_FILE"
        fi
        
        # Check if required variables are set
        if [ -z "$PROD_API_KEY" ] || [ -z "$PROD_API_BASE_URL" ] || [ -z "$PROD_MIXPANEL_TOKEN" ]; then
            echo "❌ ERROR: Required production environment variables not set!"
            echo "Please set: PROD_API_KEY, PROD_API_BASE_URL, PROD_MIXPANEL_TOKEN, etc."
            
            # For now, generate empty file to prevent build failure
            # Remove this in production when you have proper CI/CD
            generate_secrets \
                "${PROD_API_KEY:-}" \
                "${PROD_API_BASE_URL:-https://api.yourapp.com}" \
                "${PROD_MIXPANEL_TOKEN:-}" \
                "${PROD_SECRET_API_KEY:-}" \
                "${PROD_ZENDESK_APP_ID:-}" \
                "${PROD_ZENDESK_CLIENT_ID:-}" \
                "${PROD_BRAZE_API_KEY:-}" \
                "${PROD_BRAZE_ENDPOINT:-sdk.us-09.braze.com}"
            
            # Uncomment this line to fail the build if secrets are missing
            # exit 1
        else
            generate_secrets \
                "$PROD_API_KEY" \
                "$PROD_API_BASE_URL" \
                "$PROD_MIXPANEL_TOKEN" \
                "$PROD_SECRET_API_KEY" \
                "$PROD_ZENDESK_APP_ID" \
                "$PROD_ZENDESK_CLIENT_ID" \
                "$PROD_BRAZE_API_KEY" \
                "${PROD_BRAZE_ENDPOINT:-sdk.us-09.braze.com}"
        fi
        ;;
        
    *)
        echo "❌ Unknown configuration: $CONFIGURATION"
        exit 1
        ;;
esac

echo "✅ Secrets.swift generated successfully at: $OUTPUT_FILE"

# Verify the file was created
if [ -f "$OUTPUT_FILE" ]; then
    echo "📄 File contents:"
    head -n 5 "$OUTPUT_FILE"
else
    echo "❌ ERROR: Failed to create Secrets.swift"
    exit 1
fi