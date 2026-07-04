//
//  LoginResponse.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation

/// Response model from login API
struct LoginResponse: Decodable {
    let accessToken: String
    let email: String
    let redirect: String?
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case email
        case redirect
        case refreshToken = "refresh_token"
    }
}


struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
}


struct RefreshTokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}
