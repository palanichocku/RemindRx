import SwiftUI

struct ExpiryBadgeView: View {
    enum ExpiryStatus {
        case expired
        case expiringSoon
        case valid
        
        var color: Color {
            switch self {
            case .expired:
                return .red
            case .expiringSoon:
                return .yellow
            case .valid:
                return .green
            }
        }
        
        var text: String {
            switch self {
            case .expired:
                return "EXPIRED"
            case .expiringSoon:
                return "EXPIRING SOON"
            case .valid:
                return "VALID"
            }
        }
        
        var icon: String {
            switch self {
            case .expired:
                return "exclamationmark.circle.fill"
            case .expiringSoon:
                return "exclamationmark.triangle.fill"
            case .valid:
                return "checkmark.circle.fill"
            }
        }
    }
    
    let status: ExpiryStatus
    let compact: Bool
    
    init(status: ExpiryStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }
    
    var body: some View {
        if compact {
            compactBadge
        } else {
            fullBadge
        }
    }
    
    private var fullBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
            
            Text(status.text)
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeBackground)
        .foregroundColor(badgeForeground)
        .clipShape(Capsule())
    }
    
    private var compactBadge: some View {
        Image(systemName: status.icon)
            .font(.system(size: 16))
            .foregroundColor(status.color)
    }
    
    private var badgeBackground: Color {
        switch status {
        case .expired:
            return .red
        case .expiringSoon:
            return .yellow
        case .valid:
            return .green.opacity(0.2)
        }
    }
    
    private var badgeForeground: Color {
        switch status {
        case .expired:
            return .white
        case .expiringSoon:
            return .black
        case .valid:
            return .green
        }
    }
}

// Helper extension to determine Medicine expiry status
extension Medicine {
    var expiryStatus: ExpiryBadgeView.ExpiryStatus {
        if expirationDate < Date() {
            return .expired
        } else {
            let timeInterval = expirationDate.timeIntervalSince(Date())
            let daysTillExpiry = timeInterval / (60 * 60 * 24)
            
            if daysTillExpiry <= Double(alertInterval.days) {
                return .expiringSoon
            } else {
                return .valid
            }
        }
    }
}

struct ExpiryBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ExpiryBadgeView(status: .valid)
            ExpiryBadgeView(status: .expiringSoon)
            ExpiryBadgeView(status: .expired)
            
            HStack(spacing: 20) {
                ExpiryBadgeView(status: .valid, compact: true)
                ExpiryBadgeView(status: .expiringSoon, compact: true)
                ExpiryBadgeView(status: .expired, compact: true)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
