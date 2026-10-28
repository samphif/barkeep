import Foundation

/// macOS 27's menu bar allow-list, from `MenuBarClientCore`, the private framework behind
/// assessment (exam lockdown) mode. It's resolved at runtime, so a macOS release that
/// changes or drops it reports unavailable instead of crashing. macOS lifts the
/// restriction when Barkeep quits, so the bar can't stay stuck hidden.
@MainActor
enum NativeVisibility {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"

    private static let classes: (configuration: AssessmentConfiguration.Type, assertion: AssessmentAssertion.Type)? = {
        guard dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL) != nil,
              let configuration = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
              let assertion = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type,
              configuration.instancesRespond(to: NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")),
              assertion.instancesRespond(to: NSSelectorFromString("activateWithConfiguration:completionHandler:")),
              assertion.instancesRespond(to: NSSelectorFromString("invalidate"))
        else { return nil }
        return (
            unsafeBitCast(configuration, to: AssessmentConfiguration.Type.self),
            unsafeBitCast(assertion, to: AssessmentAssertion.Type.self)
        )
    }()

    static var isAvailable: Bool { classes != nil }

    static var allSystemItems: [NSNumber] {
        SystemItemID.allowListRange.map { NSNumber(value: $0) }
    }

    /// Hides every other app's status items except those of `bundleIDs`, and every system
    /// item whose id is missing from `systemItems`. Pass `allSystemItems` to leave macOS's
    /// own icons alone; omit Battery / Wi-Fi ids to hide ones the user dragged left of the divider.
    static func restrict(allowing bundleIDs: [String], systemItems: [NSNumber] = allSystemItems) async throws -> VisibilityRestriction {
        guard let classes else { throw NativeVisibilityError.unavailable }
        // The framework indexes into both lists, so they must be arrays, not sets.
        let configuration = classes.configuration.init(allowedSystemItems: systemItems as NSArray, allowedBundleIdentifiers: bundleIDs as NSArray)
        let assertion = classes.assertion.init()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            assertion.activate(with: configuration) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        return VisibilityRestriction(assertion)
    }
}

enum NativeVisibilityError: Error {
    case unavailable
}

/// An active allow-list. Hidden items come back on `lift()` or when Barkeep exits.
@MainActor
final class VisibilityRestriction {
    private var assertion: AssessmentAssertion?

    fileprivate init(_ assertion: AssessmentAssertion) {
        self.assertion = assertion
    }

    func lift() {
        assertion?.invalidate()
        assertion = nil
    }
}

@objc fileprivate protocol AssessmentConfiguration {
    @objc(initWithAllowedSystemItems:allowedBundleIdentifiers:)
    init(allowedSystemItems: NSArray, allowedBundleIdentifiers: NSArray)
}

@objc fileprivate protocol AssessmentAssertion {
    init()
    @objc(activateWithConfiguration:completionHandler:)
    func activate(with configuration: AnyObject, completionHandler: @escaping @Sendable (NSError?) -> Void)
    func invalidate()
}
