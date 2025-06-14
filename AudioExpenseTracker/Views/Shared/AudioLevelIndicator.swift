//
//  AudioLevelIndicator.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI

// MARK: - 音频电平指示器
struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4)
                    .scaleEffect(y: barScale(for: index))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
    
    private func barScale(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(level) * 10
        let threshold = CGFloat(index)
        return normalizedLevel > threshold ? min(normalizedLevel - threshold, 1.0) : 0.1
    }
    
    private func barColor(for index: Int) -> Color {
        let normalizedLevel = CGFloat(level) * 10
        let threshold = CGFloat(index)
        
        if normalizedLevel > threshold {
            if index < 12 {
                return .green
            } else if index < 16 {
                return .yellow
            } else {
                return .red
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
}

#Preview {
    AudioLevelIndicator(level: 0.5)
        .frame(height: 60)
        .padding()
} 