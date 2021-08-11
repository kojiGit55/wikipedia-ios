import CocoaLumberjackSwift

class RemoteNotificationsAPIController: Fetcher {
    // MARK: NotificationsAPI constants

    private struct NotificationsAPI {
        static let components: URLComponents = {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.mediawiki.org"
            components.path = "/w/api.php"
            return components
        }()
    }

    // MARK: Decodable: NotificationsResult

    struct ResultError: Decodable {
        let code, info: String?
    }

    struct NotificationsResult: Decodable {
        struct Notification: Decodable, Hashable {
            let wiki: String?
            let type: String?
            let category: String?
            let id: String?
            let message: Message?
            let timestamp: Timestamp?
            let agent: Agent?
            let affectedPageID: AffectedPageID?

            enum CodingKeys: String, CodingKey {
                case wiki
                case type
                case category
                case id
                case message = "*"
                case timestamp
                case agent
                case affectedPageID = "title"
            }

            init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                wiki = try values.decode(String.self, forKey: .wiki)
                type = try values.decode(String.self, forKey: .type)
                category = try values.decode(String.self, forKey: .category)
                do {
                    id = String(try values.decode(Int.self, forKey: .id))
                } catch {
                    id = try? values.decode(String.self, forKey: .id)
                }
                message = try values.decode(Message.self, forKey: .message)
                timestamp = try values.decode(Timestamp.self, forKey: .timestamp)
                agent = try values.decode(Agent.self, forKey: .agent)
                affectedPageID = try? values.decode(AffectedPageID.self, forKey: .affectedPageID)
            }
        }
        struct Notifications: Decodable {
            let list: [Notification]
            let `continue`: String?
        }
        struct Query: Decodable {
            let notifications: Notifications?
        }
        struct Message: Decodable, Hashable {
            let header: String?
        }
        struct Timestamp: Decodable, Hashable {
            let utciso8601: String?
        }
        struct Agent: Decodable, Hashable {
            let name: String?
        }
        struct AffectedPageID: Decodable, Hashable {
            let full: String?
        }
        let error: ResultError?
        let query: Query?
    }

    // MARK: Decodable: MarkReadResult

    struct MarkReadResult: Decodable {
        let query: Query?
        let error: ResultError?

        var succeeded: Bool {
            return query?.markAsRead?.result == .success
        }

        struct Query: Decodable {
            let markAsRead: MarkedAsRead?

            enum CodingKeys: String, CodingKey {
                case markAsRead = "echomarkread"
            }
        }
        struct MarkedAsRead: Decodable {
            let result: Result?
        }
        enum Result: String, Decodable {
            case success
        }
    }

    enum MarkReadError: LocalizedError {
        case noResult
        case unknown
        case multiple([Error])
    }

    private func notifications(from result: NotificationsResult?) -> Set<NotificationsResult.Notification>? {
        guard let result = result else {
            return nil
        }
        guard let list = result.query?.notifications?.list else {
            return nil
        }
        return Set(list)
    }
    
    public func getAllNotifications(from languageCode: String, continueId: String?, completion: @escaping (NotificationsResult.Notifications?, Error?) -> Void) {
        let completion: (NotificationsResult?, URLResponse?, Error?) -> Void = { result, _, error in
            guard error == nil else {
                completion(nil, error)
                return
            }
            completion(result?.query?.notifications, result?.error)
        }
        
        request(languageCode: languageCode, queryParameters: Query.notifications(from: [languageCode], limit: .max, filter: .none, continueId: continueId), completion: completion)
    }

    public func getAllUnreadNotifications(from languageCodes: [String], completion: @escaping (Set<NotificationsResult.Notification>?, Error?) -> Void) {
        let completion: (NotificationsResult?, URLResponse?, Error?) -> Void = { result, _, error in
            guard error == nil else {
                completion([], error)
                return
            }
            let notifications = self.notifications(from: result)
            completion(notifications, result?.error)
        }
        request(languageCode: nil, queryParameters: Query.notifications(from: languageCodes, limit: .max, filter: .unread), completion: completion)
    }

    public func markAsRead(_ notifications: Set<RemoteNotification>, completion: @escaping (Error?) -> Void) {
        let maxNumberOfNotificationsPerRequest = 50
        let notifications = Array(notifications)
        let split = notifications.chunked(into: maxNumberOfNotificationsPerRequest)

        split.asyncCompactMap({ (notifications, completion: @escaping (Error?) -> Void) in
            request(languageCode: nil, queryParameters: Query.markAsRead(notifications: notifications), method: .post) { (result: MarkReadResult?, _, error) in
                if let error = error {
                    completion(error)
                    return
                }
                guard let result = result else {
                    assertionFailure("Expected result; make sure MarkReadResult maps the expected result correctly")
                    completion(MarkReadError.noResult)
                    return
                }
                if let error = result.error {
                    completion(error)
                    return
                }
                if !result.succeeded {
                    completion(MarkReadError.unknown)
                    return
                }
                completion(nil)
            }
        }) { (errors) in
            if errors.isEmpty {
                completion(nil)
            } else {
                DDLogError("\(errors.count) of \(split.count) mark as read requests failed")
                completion(MarkReadError.multiple(errors))
            }
        }
    }

    private func request<T: Decodable>(languageCode: String?, queryParameters: Query.Parameters?, method: Session.Request.Method = .get, completion: @escaping (T?, URLResponse?, Error?) -> Void) {
        
        let url: URL?
        if let languageCode = languageCode {
            if languageCode == "wikidata" {
                url = configuration.wikidataAPIURLComponents(with: queryParameters).url
            } else {
                url = configuration.mediaWikiAPIURLForWikiLanguage(languageCode, with: queryParameters).url
            }
        } else {
            var components = NotificationsAPI.components
            components.replacePercentEncodedQueryWithQueryParameters(queryParameters)
            url = components.url
        }
        
        guard let url = url else {
            return
        }
        
        if method == .get {
            session.jsonDecodableTask(with: url, method: .get, completionHandler: completion)
        } else {
            requestMediaWikiAPIAuthToken(for: url, type: .csrf) { (result) in
                switch result {
                case .failure(let error):
                    completion(nil, nil, error)
                case .success(let token):
                    self.session.jsonDecodableTask(with: url, method: method, bodyParameters: ["token": token.value], bodyEncoding: .form, completionHandler: completion)
                }
            }
        }
    }

    // MARK: Query parameters

    private struct Query {
        typealias Parameters = [String: String]

        enum Limit {
            case max
            case numeric(Int)

            var value: String {
                switch self {
                case .max:
                    return "max"
                case .numeric(let number):
                    return "\(number)"
                }
            }
        }

        enum Filter: String {
            case read = "read"
            case unread = "!read"
            case none = "read|!read"
        }

        static func notifications(from languageCodes: [String] = [], limit: Limit = .max, filter: Filter = .none, continueId: String? = nil) -> Parameters {
            var dictionary = ["action": "query",
                    "format": "json",
                    "formatversion": "2",
                    "notformat": "model",
                    "meta": "notifications",
                    "notlimit": limit.value,
                    "notfilter": filter.rawValue]
            
            if let continueId = continueId {
                dictionary["notcontinue"] = continueId
            }

            let wikis = languageCodes.compactMap { $0.replacingOccurrences(of: "-", with: "_").appending("wiki") }
            dictionary["notwikis"] = wikis.joined(separator: "|")
            return dictionary
        }

        static func markAsRead(notifications: [RemoteNotification]) -> Parameters? {
            let IDs = notifications.compactMap { $0.id }
            let wikis = notifications.compactMap { $0.wiki }
            return ["action": "echomarkread",
                    "format": "json",
                    "wikis": wikis.joined(separator: "|"),
                    "list":  IDs.joined(separator: "|")]
        }
    }
}

extension RemoteNotificationsAPIController.ResultError: LocalizedError {
    var errorDescription: String? {
        return info
    }
}

extension RemoteNotificationsAPIController {
    var isAuthenticated: Bool {
        return session.hasValidCentralAuthCookies(for: Configuration.current.mediaWikiCookieDomain)
    }
}
