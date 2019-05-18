import Foundation
import Alamofire

typealias LoginCallback = (_ response: APIResponse<User>) -> Void
typealias ServersCallback = (_ response: APIResponse<[Server]>) -> Void
typealias RecoveryPasswordCallback = (_ response: APIResponse<Int>) -> Void

enum APIResponse<Type: Decodable> {
    case success(data: Type?)
    case error(message: String, code: Int)
}

struct ErrorResponse: Decodable {
    let code: Int
}

class ServerAPI {
    static let shared = ServerAPI()
    
    private var token = ""
    
    let headers: [String: String] = [:
        //"Authorization" : "token",
        //"User-Agent"    : "ipvpnGUI-iOS/0.1"
    ]

    let baseURL = "http://ec2-18-222-129-187.us-east-2.compute.amazonaws.com:8282/api/"

    public func login(token: String, callback: @escaping LoginCallback) {
        makeRequest(method: .login, params:  ["token": token], callback: callback)
    }
    
    private func makeRequest<Type>(method: Method, params: Parameters?, callback: @escaping (_ response: APIResponse<Type>) -> Void) {
        let url = baseURL + method.uri
        
        Alamofire.request(url, method: method.type, parameters: params, encoding: URLEncoding.default, headers: headers).responseData { response in
            let response: APIResponse<Type> = ServerAPI.createAPIResponse(response: response)
            callback(response)
        }
    }
    
    // TODO: Add localization
    private static func createAPIResponse<Type>(response: DataResponse<Data>) -> APIResponse<Type> {
        guard let http = response.response else { return .error(message: "No HTTP Response", code: -1) }
        
        let result: APIResponse<Type>
        let decoder = JSONDecoder()
        
        if http.statusCode == 200 {
            if let data = response.data, !data.isEmpty {
                do {
                    let decoded = try decoder.decode(Type.self, from: data)
                    result = .success(data: decoded)
                } catch {
                    result = .error(message: "Decoding failed", code: 200)
                }
            } else {
                result = .success(data: nil)
            }
        } else if let data = response.data {
            do {
                let decoded = try decoder.decode(ErrorResponse.self, from: data)
                result = .error(message: String(decoded.code), code: http.statusCode)
            } catch {
                result = .error(message: "Failed to decode error response", code: http.statusCode)
            }
        } else {
            result = .error(message: "Failed to decode error response", code: http.statusCode)
        }

        return result
    }
    
    enum Method: String {
        case login
        
        var uri: String {
            switch self {
            case .login:          return "login"
            }
        }
        
        var type: HTTPMethod {
            switch self {
            case .login:
                return .post
            }
        }
    }
}
