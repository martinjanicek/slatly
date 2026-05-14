import Foundation

public actor OverkizClient {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let baseURL: URL
        public let somfyTokenURL: URL
        public let clientID: String
        public let clientSecret: String
        public let label: String

        public init(
            baseURL: URL,
            somfyTokenURL: URL,
            clientID: String,
            clientSecret: String,
            label: String = "Žaluzky"
        ) {
            self.baseURL = baseURL
            self.somfyTokenURL = somfyTokenURL
            self.clientID = clientID
            self.clientSecret = clientSecret
            self.label = label
        }

        public static let somfyEurope = Configuration(
            baseURL: URL(string: "https://ha101-1.overkiz.com/enduser-mobile-web/enduserAPI/")!,
            somfyTokenURL: URL(string: "https://accounts.somfy.com/oauth/oauth/v2/token/jwt")!,
            clientID: "0d8e920c-1478-11e7-a377-02dd59bd3041_1ewvaqmclfogo4kcsoo0c8k4kso884owg08sg8c40sk4go4ksg",
            clientSecret: "12k73w1n540g8o4cokg0cw84cog840k84cwggscwg884004kgk"
        )
    }

    public struct Credentials: Sendable, Equatable {
        public let username: String
        public let password: String
        public init(username: String, password: String) {
            self.username = username
            self.password = password
        }
    }

    // MARK: - Token state

    struct OAuthToken: Sendable, Equatable {
        var access: String
        var refresh: String
        var expiresAt: Date
    }

    private let config: Configuration
    private let credentials: Credentials
    private let urlSession: URLSession
    private let now: @Sendable () -> Date
    private var token: OAuthToken?

    public init(
        credentials: Credentials,
        configuration: Configuration = .somfyEurope,
        urlSession: URLSession = .shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.credentials = credentials
        self.config = configuration
        self.urlSession = urlSession
        self.now = now
    }

    // MARK: - Public API

    @discardableResult
    public func executeCommand(
        deviceURL: String,
        name: String,
        parameters: [CommandParameter] = []
    ) async throws -> String {
        let payload = ExecPayload(
            label: "\(config.label):\(name)",
            actions: [.init(deviceURL: deviceURL, commands: [.init(name: name, parameters: parameters)])]
        )
        let data = try JSONEncoder().encode(payload)

        let response: ExecResponse = try await authorizedJSON(
            path: "exec/apply",
            method: "POST",
            body: data
        )
        return response.execId
    }

    @discardableResult
    public func setOrientation(deviceURL: String, tilt: Int) async throws -> String {
        try await executeCommand(deviceURL: deviceURL, name: "setOrientation", parameters: [.int(tilt)])
    }

    @discardableResult
    public func setClosure(deviceURL: String, closure: Int) async throws -> String {
        try await executeCommand(deviceURL: deviceURL, name: "setClosure", parameters: [.int(closure)])
    }

    @discardableResult
    public func setClosureAndOrientation(deviceURL: String, closure: Int, tilt: Int) async throws -> String {
        try await executeCommand(
            deviceURL: deviceURL,
            name: "setClosureAndOrientation",
            parameters: [.int(closure), .int(tilt)]
        )
    }

    @discardableResult
    public func open(deviceURL: String) async throws -> String {
        try await executeCommand(deviceURL: deviceURL, name: "open")
    }

    @discardableResult
    public func close(deviceURL: String) async throws -> String {
        try await executeCommand(deviceURL: deviceURL, name: "close")
    }

    @discardableResult
    public func stop(deviceURL: String) async throws -> String {
        try await executeCommand(deviceURL: deviceURL, name: "stop")
    }

    @discardableResult
    public func my(deviceURL: String) async throws -> String {
        try await executeCommand(deviceURL: deviceURL, name: "my")
    }

    /// Lists all devices registered on the box. Use `OverkizDevice.isBlind` to filter to
    /// shutters/awnings/screens that respond to closure/orientation commands.
    public func getDevices() async throws -> [OverkizDevice] {
        try await authorizedJSON(path: "setup/devices", method: "GET", body: nil)
    }

    // MARK: - Auth

    func ensureAccessToken() async throws -> String {
        if let t = token, now() < t.expiresAt { return t.access }
        if let t = token {
            do {
                try await refreshAccessToken(using: t.refresh)
                return token!.access
            } catch {
                // Fall back to full password login on refresh failure.
            }
        }
        try await loginWithPassword()
        return token!.access
    }

    func loginWithPassword() async throws {
        let form = [
            "grant_type": "password",
            "username": credentials.username,
            "password": credentials.password,
            "client_id": config.clientID,
            "client_secret": config.clientSecret,
        ]
        token = try await fetchToken(form: form)
    }

    func refreshAccessToken(using refreshToken: String) async throws {
        let form = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientID,
            "client_secret": config.clientSecret,
        ]
        token = try await fetchToken(form: form)
    }

    private func fetchToken(form: [String: String]) async throws -> OAuthToken {
        var req = URLRequest(url: config.somfyTokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = OverkizClient.formEncode(form)

        let (data, response) = try await urlSession.data(for: req)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0

        if status == 400 || status == 401 {
            // Try to decode the typical Somfy invalid grant body before failing.
            if let err = try? JSONDecoder().decode(SomfyErrorBody.self, from: data),
               err.message == "error.invalid.grant" {
                throw OverkizError.badCredentials
            }
            throw OverkizError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        guard (200...299).contains(status) else {
            throw OverkizError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }

        let body: TokenResponse
        do {
            body = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw OverkizError.decoding("token: \(error)")
        }
        guard let access = body.access_token, let refresh = body.refresh_token, let expiresIn = body.expires_in else {
            throw OverkizError.noAccessToken
        }
        return OAuthToken(
            access: access,
            refresh: refresh,
            expiresAt: now().addingTimeInterval(TimeInterval(expiresIn - 30))
        )
    }

    // MARK: - Authorized JSON helper with 401 retry

    private func authorizedJSON<T: Decodable>(
        path: String,
        method: String,
        body: Data?
    ) async throws -> T {
        let access = try await ensureAccessToken()
        let result = try await sendJSON(path: path, method: method, body: body, accessToken: access)
        switch result {
        case .success(let data):
            do { return try JSONDecoder().decode(T.self, from: data) }
            catch { throw OverkizError.decoding("\(path): \(error)") }
        case .unauthorized:
            // Mark access expired so ensureAccessToken refreshes first (falls back to password login on failure).
            if var t = token {
                t.expiresAt = .distantPast
                token = t
            }
            let fresh = try await ensureAccessToken()
            let retry = try await sendJSON(path: path, method: method, body: body, accessToken: fresh)
            switch retry {
            case .success(let data):
                do { return try JSONDecoder().decode(T.self, from: data) }
                catch { throw OverkizError.decoding("\(path): \(error)") }
            case .unauthorized:
                throw OverkizError.http(status: 401, body: "unauthorized after retry")
            case .failure(let status, let bodyStr):
                throw OverkizError.http(status: status, body: bodyStr)
            }
        case .failure(let status, let bodyStr):
            throw OverkizError.http(status: status, body: bodyStr)
        }
    }

    private enum Outcome {
        case success(Data)
        case unauthorized
        case failure(status: Int, body: String)
    }

    private func sendJSON(path: String, method: String, body: Data?, accessToken: String) async throws -> Outcome {
        var req = URLRequest(url: config.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = body

        let (data, response) = try await urlSession.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { return .unauthorized }
        if (200...299).contains(status) { return .success(data) }
        return .failure(status: status, body: String(data: data, encoding: .utf8) ?? "")
    }

    // MARK: - Helpers

    static func formEncode(_ params: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = params.map { key, value -> String in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }
        return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    // MARK: - DTOs

    private struct TokenResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let token_type: String?
    }

    private struct SomfyErrorBody: Decodable {
        let message: String?
    }

    private struct ExecPayload: Encodable {
        struct Action: Encodable {
            let deviceURL: String
            let commands: [CommandBody]
        }
        struct CommandBody: Encodable {
            let name: String
            let parameters: [CommandParameter]
        }
        let label: String
        let actions: [Action]
    }

    private struct ExecResponse: Decodable {
        let execId: String
    }
}

// Test hook
extension OverkizClient {
    func _peekToken() -> OAuthToken? { token }
    func _setToken(_ t: OAuthToken?) { token = t }
}
