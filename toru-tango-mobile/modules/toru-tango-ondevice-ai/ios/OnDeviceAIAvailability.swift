import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum OnDeviceAIStatus: Equatable, Sendable {
  case available
  case unsupportedOS
  case deviceNotEligible
  case appleIntelligenceDisabled
  case modelNotReady
  case unavailable(String)
}

public enum OnDeviceAIAvailability {
  public static func currentStatus() -> OnDeviceAIStatus {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      let model = SystemLanguageModel.default

      switch model.availability {
      case .available:
        return .available
      case .unavailable(.deviceNotEligible):
        return .deviceNotEligible
      case .unavailable(.appleIntelligenceNotEnabled):
        return .appleIntelligenceDisabled
      case .unavailable(.modelNotReady):
        return .modelNotReady
      case .unavailable(let reason):
        return .unavailable(String(describing: reason))
      }
    }
    #endif

    return .unsupportedOS
  }
}
