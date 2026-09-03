import Foundation
@testable import CoreGraphQL

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: ((URLRequest) throws -> (Int, Data, [String: String]))?
    nonisolated(unsafe) private static var _requests: [URLRequest] = []

    static var handler: ((URLRequest) throws -> (Int, Data, [String: String]))? {
        get {
            lock.lock(); defer { lock.unlock() }
            return _handler
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _handler = newValue
        }
    }

    static var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    static func reset() {
        lock.lock()
        _handler = nil
        _requests = []
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let captured = Self.copyRequestMaterializingBody(request)

        Self.lock.lock()
        Self._requests.append(captured)
        let handler = Self._handler
        Self.lock.unlock()

        do {
            guard let handler else {
                throw URLError(.badServerResponse)
            }
            let (status, data, headers) = try handler(captured)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: headers
                  ) else {
                throw URLError(.badServerResponse)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func copyRequestMaterializingBody(_ request: URLRequest) -> URLRequest {
        if request.httpBody != nil { return request }
        guard let stream = request.httpBodyStream else { return request }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 16_384
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }

        var copy = request
        copy.httpBody = data
        return copy
    }
}
