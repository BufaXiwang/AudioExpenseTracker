//
//  ExpenseCategory.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "餐饮"
    case transport = "交通"
    case shopping = "购物"
    case entertainment = "娱乐"
    case healthcare = "医疗"
    case housing = "住房"
    case education = "教育"
    case utilities = "水电费"
    case clothing = "服装"
    case gift = "礼品"
    case travel = "旅行"
    case other = "其他"
    
    var icon: String {
        switch self {
        case .food:
            return "fork.knife"
        case .transport:
            return "car.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "gamecontroller.fill"
        case .healthcare:
            return "cross.fill"
        case .housing:
            return "house.fill"
        case .education:
            return "book.fill"
        case .utilities:
            return "bolt.fill"
        case .clothing:
            return "tshirt.fill"
        case .gift:
            return "gift.fill"
        case .travel:
            return "airplane"
        case .other:
            return "questionmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .food:
            return "orange"
        case .transport:
            return "blue"
        case .shopping:
            return "pink"
        case .entertainment:
            return "purple"
        case .healthcare:
            return "red"
        case .housing:
            return "brown"
        case .education:
            return "green"
        case .utilities:
            return "yellow"
        case .clothing:
            return "indigo"
        case .gift:
            return "mint"
        case .travel:
            return "cyan"
        case .other:
            return "gray"
        }
    }
} 