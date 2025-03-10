//
// This source file is part of the Stanford XCTRuntimeAssertions open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if DEBUG || TEST
import Foundation
import RuntimeAssertions
#if canImport(XCTest) // TODO: does that work?
import XCTest
#endif


/// `XCTRuntimePrecondition` allows you to test assertions of types that use the `precondition` and `preconditionFailure` functions of the `XCTRuntimeAssertions` target.
///
/// - Important: The `expression` is executed on a background thread, even though it is not annotated as `@Sendable`. This is by design. Preconditions return `Never` and, therefore,
/// need to be run on a separate thread that can block forever. Without this workaround, testing preconditions that are isolated to `@MainActor` would be impossible.
/// Make sure to only run isolated parts of your code that don't suffer from concurrency issues in such a scenario.
///
/// - Parameters:
///   - validateRuntimeAssertion: An optional closure that can be used to further validate the messages passed to the
///                               `precondition` and `preconditionFailure` functions of the `XCTRuntimeAssertions` target.
///   - timeout: A timeout defining how long to wait for the precondition to be triggered.
///   - message: A message that is posted on failure.
///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
///   - line: The line number where the failure occurs. The default is the line number where you call this function.
///   - expression: The expression that is evaluated.
/// - Throws: Throws an `XCTFail` error if the expression does not trigger a runtime assertion with the parameters defined above.
public func XCTRuntimePrecondition(
    validateRuntimeAssertion: (@Sendable (String) -> Void)? = nil,
    timeout: TimeInterval = 1,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ expression: @escaping () -> Void
) throws {
    let fulfillmentCount = Counter()
    let injection = setupXCTRuntimeAssertionInjector(
        fulfillmentCount: fulfillmentCount,
        validateRuntimeAssertion: validateRuntimeAssertion
    )
    
    // We have to run the operation on a `DispatchQueue` as we have to call `RunLoop.current.run()` in the `preconditionFailure` call.
    let dispatchQueue = DispatchQueue(label: "XCTRuntimePrecondition-\(injection.id)")

    let expressionWorkItem = DispatchWorkItem {
        expression()
    }
    dispatchQueue.async(execute: expressionWorkItem)
    
    // We don't use:
    // `wait(for: [expectation], timeout: timeout)`
    // here as we need to make the method independent of XCTestCase to also use it in our TestApp UITest target which fails if you import XCTest.
    usleep(useconds_t(1_000_000 * timeout))
    expressionWorkItem.cancel()

    injection.remove()

    try assertFulfillmentCount(
        fulfillmentCount,
        message,
        file: file,
        line: line
    )
}

/// `XCTRuntimePrecondition` allows you to test async assertions of types that use the `precondition` and `preconditionFailure` functions of the `XCTRuntimeAssertions` target.
///
/// - Important: The `expression` is executed on a background thread, even though it is not annotated as `@Sendable`. This is by design. Preconditions return `Never` and, therefore,
/// need to be run on a separate thread that can block forever. Without this workaround, testing preconditions that are isolated to `@MainActor` would be impossible.
/// Make sure to only run isolated parts of your code that don't suffer from concurrency issues in such a scenario.
///
/// - Parameters:
///   - validateRuntimeAssertion: An optional closure that can be used to further validate the messages passed to the
///                               `precondition` and `preconditionFailure` functions of the `XCTRuntimeAssertions` target.
///   - timeout: A timeout defining how long to wait for the precondition to be triggered.
///   - message: A message that is posted on failure.
///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
///   - line: The line number where the failure occurs. The default is the line number where you call this function.
///   - expression: The async expression that is evaluated.
/// - Throws: Throws an `XCTFail` error if the expression does not trigger a runtime assertion with the parameters defined above.
public func XCTRuntimePrecondition(
    validateRuntimeAssertion: (@Sendable (String) -> Void)? = nil,
    timeout: TimeInterval = 1,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ expression: @escaping () async -> Void
) throws {
    struct HackySendable<Value>: @unchecked Sendable {
        let value: Value
    }

    let fulfillmentCount = Counter()
    let injection = setupXCTRuntimeAssertionInjector(
        fulfillmentCount: fulfillmentCount,
        validateRuntimeAssertion: validateRuntimeAssertion
    )

    let expressionClosure = HackySendable(value: expression)
    let task = Task {
        await expressionClosure.value()
    }
    
    // We don't use:
    // `wait(for: [expectation], timeout: timeout)`
    // here as we need to make the method independent of XCTestCase to also use it in our TestApp UITest target which fails if you import XCTest.
    usleep(useconds_t(1_000_000 * timeout))
    task.cancel()

    injection.remove()

    try assertFulfillmentCount(
        fulfillmentCount,
        message,
        file: file,
        line: line
    )
}


private func setupXCTRuntimeAssertionInjector(
    fulfillmentCount: Counter,
    validateRuntimeAssertion: (@Sendable (String) -> Void)? = nil
) -> RuntimeAssertionInjection {
    let injection = RuntimeAssertionInjection(precondition: { condition, message, _, _  in
        if !condition() {
            // We execute the message closure independent of the availability of the `validateRuntimeAssertion` closure.
            let message = message()
            validateRuntimeAssertion?(message)
            fulfillmentCount.increment()
            neverReturn()
        }
    })

    injection.inject()

    return injection
}

private func assertFulfillmentCount(
    _ fulfillmentCount: Counter,
    _ message: () -> String,
    file: StaticString,
    line: UInt
) throws {
    // TODO: doesn't throw anymore!
    let counter = fulfillmentCount.count
    if counter <= 0 {
        XCTFail(
            """
            The precondition was never called.
            \(message()) at \(file):\(line)
            """
        )
    } else if counter > 1 {
        XCTFail(
            """
            The precondition was called multiple times (\(counter)).
            \(message()) at \(file):\(line)
            """
        )
    }
}
#endif
