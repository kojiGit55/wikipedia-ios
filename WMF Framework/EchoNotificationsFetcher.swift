
import Foundation

public class EchoNotificationsFetcher: Fetcher {
    
    public enum EchoError: Error {
        case failureToGenerateUrl
        case failureToPullNotificationIdForMarkAsRead
        case serverFailureMarkingAsRead
    }
    
    private func queryParameters(projectFilters: [String]) -> [String: Any] {
        
        let paramWikis = projectFilters.joined(separator: "|")
        return [
            "action": "query",
            "meta": "notifications",
            "notwikis": paramWikis,
            "notlimit": 50,
            "notprop": "count|list|seenTime",
            "notformat": "model",
            "format": "json"]
    }
    
    public  func url(subdomain: String) -> URL? {
        return URL(string: "https://\(subdomain).wikipedia.org/w/api.php")
    }
    
    public func key(projectFilters: [String], subdomain: String) throws -> URL {

        let queryParameters = queryParameters(projectFilters: projectFilters)
        
        guard let url = url(subdomain: subdomain) else {
            throw EchoError.failureToGenerateUrl
        }
        
        guard let fullURL = configuration.mediaWikiAPIURLForURL(url, with: queryParameters) else {
            throw EchoError.failureToGenerateUrl
        }
        
        return fullURL
    }
    
    public struct RemoteEchoNotificationFetchResponse {
        public let notifications: [RemoteEchoNotification]
        public let continueString: String?
    }
    
    public func fetchNotifications(projectFilters: [String], subdomain: String, continueId: String?, completion: @escaping (Result<RemoteEchoNotificationFetchResponse, Error>) -> Void) -> CancellationKey? {
        
        //TODO: Use Configuration.swift, which wiki do we use, which targetwikis
        
        var queryParameters = queryParameters(projectFilters: projectFilters)
        
        if let continueId = continueId {
            queryParameters["notcontinue"] = continueId
        }
        
        guard let url = url(subdomain: subdomain) else {
            completion(.failure(EchoError.failureToGenerateUrl))
            return nil
        }
        
        return self.performTokenizedDecodableMediaWikiAPIGET(tokenType: .csrf, to: url, with: queryParameters, cancellationKey: nil, reattemptLoginOn401Response: true) { (result: Result<RemoteEchoNotificationResponse, Error>) in
            switch result {
            case .success(let response):
                let fetchResponse = RemoteEchoNotificationFetchResponse(notifications: response.query.notifications.list, continueString: response.query.notifications.continueString)
                completion(.success(fetchResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
