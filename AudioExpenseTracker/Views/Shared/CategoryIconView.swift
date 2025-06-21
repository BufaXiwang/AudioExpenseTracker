//
//  CategoryIconView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI

struct CategoryIconView: View {
    let category: ExpenseCategory
    
    var body: some View {
        ZStack {
            Circle()
                .fill(category.color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: category.iconName)
                .foregroundColor(category.color)
                .font(.system(size: 18, weight: .medium))
        }
    }
}

#Preview {
    HStack {
        CategoryIconView(category: .food)
        CategoryIconView(category: .transport)
        CategoryIconView(category: .shopping)
        CategoryIconView(category: .entertainment)
    }
    .padding()
} 