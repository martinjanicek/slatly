import Foundation
import Testing
@testable import OverkizKit

@Suite(.serialized)
struct OverkizClientTests {

    static let tokenURL = URL(string: "https://accounts.somfy.com/oauth/oauth/v2/token/jwt")!
    static let baseURL = URL(string: "https://ha101-1.overkiz.com/enduser-mobile-web/enduserAPI/")!
    static let execURL = URL(string: "https://ha101-1.overkiz.com/enduser-mobile-web/enduserAPI/exec/apply")!

    static func makeClient(now: @escaping @Sendable () -> Date = { Date() }) -> OverkizClient {
        OverkizClient(
            credentials: .init(username: "user@example.com", password: "secret&%pw"),
            configuration: .init(
                baseURL: baseURL,
                somfyTokenURL: tokenURL,
                clientID: "cid",
                clientSecret: "csecret",
                label: "test"
            ),
            urlSession: MockURLProtocol.makeSession(),
            now: now
        )
    }

    static func tokenBody(access: String = "tok-a", refresh: String = "tok-r", expires: Int = 3600) -> Data {
        // swiftlint:disable:next line_length
        Data(#"{"access_token":"\#(access)","refresh_token":"\#(refresh)","expires_in":\#(expires),"token_type":"bearer"}"#.utf8)
    }

    static func execBody(execId: String = "exec-123") -> Data {
        Data(#"{"execId":"\#(execId)"}"#.utf8)
    }

    // MARK: - Form encoding

    @Test func formEncodesReservedCharacters() {
        let data = OverkizClient.formEncode([
            "grant_type": "password",
            "username": "user@example.com",
            "password": "p+a=s&w/d",
        ])
        let s = String(data: data, encoding: .utf8)!
        let parts = Set(s.split(separator: "&").map(String.init))
        #expect(parts.contains("grant_type=password"))
        #expect(parts.contains("username=user%40example.com"))
        #expect(parts.contains("password=p%2Ba%3Ds%26w%2Fd"))
    }

    // MARK: - Login + exec happy path

    @Test func loginAndExecuteCommand() async throws {
        MockURLProtocol.install { request in
            switch request.url {
            case Self.tokenURL:
                return (http(Self.tokenURL, 200), Self.tokenBody())
            case Self.execURL:
                return (http(Self.execURL, 200), Self.execBody())
            default:
                throw URLError(.badURL)
            }
        }
        let client = Self.makeClient()
        let id = try await client.setOrientation(deviceURL: "io://x/y", tilt: 50)
        #expect(id == "exec-123")

        let reqs = MockURLProtocol.capturedRequests
        #expect(reqs.count == 2)

        // Token request: form body, no Authorization header
        let tokenReq = reqs[0]
        #expect(tokenReq.url == Self.tokenURL)
        #expect(tokenReq.httpMethod == "POST")
        #expect(tokenReq.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let tokenForm = String(data: tokenReq.capturedBody, encoding: .utf8) ?? ""
        #expect(tokenForm.contains("grant_type=password"))
        #expect(tokenForm.contains("client_id=cid"))
        #expect(tokenForm.contains("username=user%40example.com"))

        // Exec request: JSON body + Bearer header
        let execReq = reqs[1]
        #expect(execReq.url == Self.execURL)
        #expect(execReq.httpMethod == "POST")
        #expect(execReq.value(forHTTPHeaderField: "Authorization") == "Bearer tok-a")
        #expect(execReq.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try #require(try JSONSerialization.jsonObject(with: execReq.capturedBody) as? [String: Any])
        #expect(json["label"] as? String == "test:setOrientation")
        let actions = try #require(json["actions"] as? [[String: Any]])
        #expect(actions.count == 1)
        #expect(actions[0]["deviceURL"] as? String == "io://x/y")
        let commands = try #require(actions[0]["commands"] as? [[String: Any]])
        #expect(commands[0]["name"] as? String == "setOrientation")
        #expect((commands[0]["parameters"] as? [Int]) == [50])
    }

    // MARK: - Cached token reuse

    @Test func cachedTokenReusedAcrossCalls() async throws {
        MockURLProtocol.install { request in
            switch request.url {
            case Self.tokenURL:
                return (http(Self.tokenURL, 200), Self.tokenBody())
            case Self.execURL:
                return (http(Self.execURL, 200), Self.execBody())
            default:
                throw URLError(.badURL)
            }
        }
        let client = Self.makeClient()
        _ = try await client.stop(deviceURL: "io://x/1")
        _ = try await client.stop(deviceURL: "io://x/2")
        _ = try await client.stop(deviceURL: "io://x/3")

        let methods = MockURLProtocol.capturedRequests.map { $0.url?.absoluteString ?? "" }
        #expect(methods.filter { $0.contains("/token/jwt") }.count == 1)
        #expect(methods.filter { $0.contains("/exec/apply") }.count == 3)
    }

    // MARK: - Expired token triggers refresh grant

    @Test func expiredTokenUsesRefreshGrant() async throws {
        let calls = TestCounter()
        MockURLProtocol.install { request in
            if request.url == Self.tokenURL {
                let body = request.capturedBody
                let form = String(data: body, encoding: .utf8) ?? ""
                calls.increment(form.contains("grant_type=refresh_token") ? "refresh" : "password")
                return (http(Self.tokenURL, 200), Self.tokenBody(access: "fresh"))
            }
            if request.url == Self.execURL {
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh")
                return (http(Self.execURL, 200), Self.execBody())
            }
            throw URLError(.badURL)
        }
        // Inject an expired token directly
        let client = Self.makeClient()
        await client._setToken(.init(access: "stale", refresh: "rt-1", expiresAt: .distantPast))
        _ = try await client.open(deviceURL: "io://x/y")

        #expect(calls.value("refresh") == 1)
        #expect(calls.value("password") == 0)
    }

    // MARK: - 401 on exec → refresh + retry

    @Test func unauthorizedOnExecTriggersRefreshAndRetry() async throws {
        let execCalls = TestCounter()
        let tokenCalls = TestCounter()
        MockURLProtocol.install { request in
            if request.url == Self.tokenURL {
                let form = String(data: request.capturedBody, encoding: .utf8) ?? ""
                let grant = form.contains("refresh_token") ? "refresh" : "password"
                tokenCalls.increment(grant)
                let access = grant == "refresh" ? "after-refresh" : "first"
                return (http(Self.tokenURL, 200), Self.tokenBody(access: access))
            }
            if request.url == Self.execURL {
                let n = execCalls.increment("exec")
                if n == 1 {
                    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer first")
                    return (http(Self.execURL, 401), Data())
                } else {
                    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer after-refresh")
                    return (http(Self.execURL, 200), Self.execBody(execId: "retried"))
                }
            }
            throw URLError(.badURL)
        }
        let client = Self.makeClient()
        let id = try await client.close(deviceURL: "io://x/y")
        #expect(id == "retried")
        #expect(execCalls.value("exec") == 2)
        #expect(tokenCalls.value("password") == 1)
        #expect(tokenCalls.value("refresh") == 1)
    }

    // MARK: - Bad credentials

    @Test func badCredentialsThrowsTyped() async throws {
        MockURLProtocol.install { _ in
            (http(Self.tokenURL, 400), Data(#"{"message":"error.invalid.grant","data":[]}"#.utf8))
        }
        let client = Self.makeClient()
        await #expect(throws: OverkizError.badCredentials) {
            _ = try await client.stop(deviceURL: "io://x/y")
        }
    }

    // MARK: - getDevices

    static let devicesURL = URL(string: "https://ha101-1.overkiz.com/enduser-mobile-web/enduserAPI/setup/devices")!

    @Test func getDevicesReturnsParsedListWithBlindFilter() async throws {
        let body = Data(#"""
        [
          {"deviceURL":"io://x/1","label":"Roh velké","uiClass":"ExteriorVenetianBlind","widget":"unknown"},
          {"deviceURL":"io://x/2","label":"Loznice","uiClass":"ExteriorVenetianBlind","widget":"unknown"},
          {"deviceURL":"box://1","label":"Box","uiClass":"Pod","widget":"unknown"},
          {"deviceURL":"io://x/3","label":"HOMEKIT","uiClass":"ProtocolGateway","widget":null}
        ]
        """#.utf8)

        MockURLProtocol.install { request in
            switch request.url {
            case Self.tokenURL: return (http(Self.tokenURL, 200), Self.tokenBody())
            case Self.devicesURL: return (http(Self.devicesURL, 200), body)
            default: throw URLError(.badURL)
            }
        }
        let client = Self.makeClient()
        let devices = try await client.getDevices()
        #expect(devices.count == 4)
        let blinds = devices.filter(\.isBlind)
        #expect(blinds.count == 2)
        #expect(blinds.map(\.label) == ["Roh velké", "Loznice"])

        // Verify GET + Authorization header
        let req = MockURLProtocol.capturedRequests.first { $0.url == Self.devicesURL }!
        #expect(req.httpMethod == "GET")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer tok-a")
    }

    // MARK: - setClosureAndOrientation parameter order

    @Test func closureAndOrientationParameters() async throws {
        MockURLProtocol.install { request in
            switch request.url {
            case Self.tokenURL: return (http(Self.tokenURL, 200), Self.tokenBody())
            case Self.execURL: return (http(Self.execURL, 200), Self.execBody())
            default: throw URLError(.badURL)
            }
        }
        let client = Self.makeClient()
        _ = try await client.setClosureAndOrientation(deviceURL: "io://x/y", closure: 100, tilt: 25)
        let execReq = MockURLProtocol.capturedRequests.first { $0.url == Self.execURL }!
        let json = try JSONSerialization.jsonObject(with: execReq.capturedBody) as! [String: Any]
        let cmd = (json["actions"] as! [[String: Any]])[0]["commands"] as! [[String: Any]]
        #expect(cmd[0]["name"] as? String == "setClosureAndOrientation")
        #expect((cmd[0]["parameters"] as? [Int]) == [100, 25])
    }
}

/// Simple thread-safe counter so test handler closures (which the type system treats
/// as Sendable) can record per-key call counts.
final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]

    @discardableResult
    func increment(_ key: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        counts[key, default: 0] += 1
        return counts[key]!
    }

    func value(_ key: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return counts[key] ?? 0
    }
}
