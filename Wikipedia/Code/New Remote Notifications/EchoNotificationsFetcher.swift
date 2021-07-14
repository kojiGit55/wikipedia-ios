
import Foundation

class EchoNotificationsFetcher: Fetcher {
    
    enum EchoError: Error {
        case failureToGenerateUrl
    }
    
    func registerForEchoNotificationsWithDeviceTokenString(deviceTokenString: String, completion: @escaping (Bool, Error?) -> Void) {
        //TODO: Use Configuration.swift, which wiki do we use
        //working: https://en.wikipedia.org/w/api.php?action=echopushsubscriptions&format=json&command=create&token=9a49637fab9cd98c0327849ef757fec760cd0091%2B%5C&provider=apns&providertoken=115414e7a529c0b2fb9ed65a6d26d29c6882b2c5264a9e5e4d9ce8ea43e96a2b&topic=org.wikimedia.wikipedia
        guard let bundleID = Bundle.main.bundleIdentifier else {
            completion(false, nil)
            return
        }
        guard let url = URL(string: "https://en.wikipedia.org") else {
            completion(false, nil)
            return
        }
        
        let bodyParameters: [String: String] = [
            "action": "echopushsubscriptions",
            "format": "json",
            "command": "create",
            "provider": "apns",
            "providertoken": deviceTokenString,
            "topic": bundleID
        ]
        print("🤷‍♀️deviceToken:\(deviceTokenString)")
        self.performTokenizedMediaWikiAPIPOST(to: url, with: bodyParameters) { result, response, error in
            guard error == nil else {
                completion(false, error)
                return
            }
            
            //todo: use RequestError instead here
            guard response?.statusCode == 200 else {
                completion(false, nil)
                return
            }
            
            if let errorDict = result?["error"] {
                completion(false, nil)
                return
            }
            
            completion(true, nil)
        }
    }
    
    func deregisterForEchoNotificationsWithDeviceTokenString(deviceTokenString: String, completion: @escaping (Bool, Error?) -> Void) {
        //TODO: Use Configuration.swift, which wiki do we use
        guard let url = URL(string: "https://en.wikipedia.org/w/api.php?action=echopushsubscriptions&command=delete&providertoken=\(deviceTokenString)") else {
            completion(false, nil)
            return
        }
        
        let bodyParameters: [String: String] = [
            "action": "echopushsubscriptions",
            "format": "json",
            "command": "delete",
            "providertoken": deviceTokenString
        ]
        
        self.performTokenizedMediaWikiAPIPOST(to: url, with: bodyParameters) { result, response, error in
            guard error != nil else {
                completion(false, error)
                return
            }
            
            guard response?.statusCode == 200 else {
                completion(false, nil)
                return
            }
            
            completion(true, nil)
        }
    }
    
    private func queryParameters(notwikis: String) -> [String: Any] {
        return [
            "action": "query",
            "meta": "notifications",
            "notwikis": notwikis,
            "notlimit": 3,
            "notprop": "count|list|seenTime",
            "notformat": "model",
            "format": "json"]
    }
    
    private func url(subdomain: String) -> URL? {
        return URL(string: "https://\(subdomain).wikipedia.org/w/api.php")
    }
    
    func key(notwikis: String, subdomain: String) throws -> URL {

        let queryParameters = queryParameters(notwikis: notwikis)
        
        guard let url = url(subdomain: subdomain) else {
            throw EchoError.failureToGenerateUrl
        }
        
        guard let fullURL = configuration.mediaWikiAPIURLForURL(url, with: queryParameters) else {
            throw EchoError.failureToGenerateUrl
        }
        
        return fullURL
    }
    
    struct RemoteEchoNotificationFetchResponse {
        let notifications: [RemoteEchoNotification]
        let continueString: String?
    }
    
    func fetchNotifications(notwikis: String, subdomain: String, continueId: String?, completion: @escaping (Result<RemoteEchoNotificationFetchResponse, Error>) -> Void) -> CancellationKey? {
        
        //TODO: Use Configuration.swift, which wiki do we use, which targetwikis
        
        var queryParameters = queryParameters(notwikis: notwikis)
        
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
