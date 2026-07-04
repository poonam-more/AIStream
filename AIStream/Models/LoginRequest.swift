//
//  LoginRequest.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation

/// Request model for login API
struct LoginRequest: Encodable {
    let email: String
    let password: String
}
