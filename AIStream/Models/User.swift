//
//  User.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation

/// User model stored in UserDefaults (no sensitive data)
struct User: Codable {
    let email: String
}
