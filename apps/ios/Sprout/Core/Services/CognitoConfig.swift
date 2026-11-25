import Foundation

struct CognitoConfig {
    static let shared = CognitoConfig()
    
    // These values will be populated from CDK outputs
    let region = AppConfig.shared.awsRegion
    let userPoolId = AppConfig.shared.cognitoUserPoolId
    let clientId = AppConfig.shared.cognitoClientId
    
    private init() {}
}
