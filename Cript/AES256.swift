
import Foundation
import CommonCrypto

struct AES256 {
    
    private var key: Data
    private var iv: Data
    
    public init(key: Data, iv: Data) throws {
        guard key.count == kCCKeySizeAES256 else {
            throw Error.badKeyLength
        }
        guard iv.count == kCCBlockSizeAES128 else {
            throw Error.badInputVectorLength
        }
        self.key = key
        self.iv = iv
    }
    
    public static func encrypt(text: String, key: String) -> Data? {
        guard let aes = AES256(key: key, isRandomIV: false) else { return nil }
        return aes.encrypt(text)
    }
    
    public static func decrypt(data: Data, key: String) -> String? {
        guard let aes = AES256(key: key, isRandomIV: false) else { return nil }
        return aes.decrypt(data)
    }
    
    init?(key: String, isRandomIV: Bool) {
        guard let data = key.data(using: .utf8),
            let keyData = try? AES256.createKey(password: data, salt: Data())
            else { return nil }
        
        self.key = keyData
        self.iv = isRandomIV ? AES256.randomIv() : AES256.staticIV()
    }
    
    enum Error: Swift.Error {
        case keyGeneration(status: Int)
        case cryptoFailed(status: CCCryptorStatus)
        case badKeyLength
        case badInputVectorLength
        case badData
    }
    
    func encrypt(_ string: String) -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        return try? encrypt(data)
    }
    
    func encrypt(_ digest: Data) throws -> Data {
        return try crypt(input: digest, operation: CCOperation(kCCEncrypt))
    }
    
    func decrypt(_ encrypted: Data) -> String? {
        guard let data = try? crypt(input: encrypted, operation: CCOperation(kCCDecrypt)) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func decrypt(_ encrypted: Data) throws -> Data {
        return try crypt(input: encrypted, operation: CCOperation(kCCDecrypt))
    }
    
    private func crypt(input: Data, operation: CCOperation) throws -> Data {
        var outLength = Int(0)
        var outBytes = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var status: CCCryptorStatus = CCCryptorStatus(kCCSuccess)
        input.withUnsafeBytes { encryptedBytes in
            iv.withUnsafeBytes { ivBytes in
                key.withUnsafeBytes { keyBytes in
                    status = CCCrypt(operation,
                                     CCAlgorithm(kCCAlgorithmAES128),            // algorithm
                        CCOptions(kCCOptionPKCS7Padding),           // options
                        keyBytes.baseAddress,                       // key
                        key.count,                                  // keylength
                        ivBytes.baseAddress,                        // iv
                        encryptedBytes.baseAddress,                 // dataIn
                        input.count,                                // dataInLength
                        &outBytes,                                  // dataOut
                        outBytes.count,                             // dataOutAvailable
                        &outLength)                                 // dataOutMoved
                }
            }
        }
        guard status == kCCSuccess else {
            throw Error.cryptoFailed(status: status)
        }
        return Data(bytes: UnsafePointer<UInt8>(outBytes), count: outLength)
    }
    
    static func createKey(password: Data, salt: Data) throws -> Data {
        let length = kCCKeySizeAES256
        var status = Int32(0)
        var derivedBytes = [UInt8](repeating: 0, count: length)
        password.withUnsafeBytes { passwordBytes in
            let passwordPonter = passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self)
            salt.withUnsafeBytes { saltBytes in
                let saltPointer = saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                status = CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),                  // algorithm
                    passwordPonter,                               // password
                    password.count,                               // passwordLen
                    saltPointer,                                  // salt
                    salt.count,                                   // saltLen
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),   // prf
                    10000,                                        // rounds
                    &derivedBytes,                                // derivedKey
                    length)                                       // derivedKeyLen
            }
        }
        guard status == 0 else {
            throw Error.keyGeneration(status: Int(status))
        }
        return Data(bytes: UnsafePointer<UInt8>(derivedBytes), count: length)
    }
    
    static func staticIV() -> Data {
        return Data([94, 9, 209, 2, 240, 200, 161, 232, 70, 110, 89, 173, 159, 178, 174, 82])
    }
    
    static func randomIv() -> Data {
        return randomData(length: kCCBlockSizeAES128)
    }
    
    static func randomSalt() -> Data {
        return randomData(length: 8)
    }
    
    static func randomData(length: Int) -> Data {
        var result: [UInt8] = []
        for _ in 0..<length {
            result.append(UInt8.random(in: 0...UInt8.max))
        }
        
        return Data(result)
    }
}
