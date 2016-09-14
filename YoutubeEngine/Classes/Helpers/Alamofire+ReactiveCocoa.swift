import Foundation
import Alamofire
import SwiftyJSON
import ReactiveCocoa

extension Manager {

   final func signalForJSON(method: Alamofire.Method,
                            _ URLString: URLStringConvertible,
                              parameters: [String: AnyObject]? = nil,
                              headers: [String: String]? = nil,
                              logger: Logger?) -> SignalProducer<JSON, NSError> {
      return SignalProducer {
         observer, disposable in
         let encoding: ParameterEncoding = method == .GET ? .URL : .JSON
         let request = self.request(method, URLString, parameters: parameters, encoding: encoding, headers: headers)

         logger?.logRequest(request.request!, parameters: parameters)

         request.responseJSON {
            response in

            if let HTTPResponse = response.response {
               logger?.logResponse(HTTPResponse, body: response.data)
            }

            switch response.result {
            case .Success(let value):
               guard let json = JSON(rawValue: value) else {
                  observer.sendFailed(NSError(domain: YoutubeErrorDomain, code: 1, userInfo: nil))
                  return
               }

               if let error = NSError.errorWithJSON(json) {
                  observer.sendFailed(error)
               } else {
                  observer.sendNext(json)
                  observer.sendCompleted()
               }
            case .Failure(let error):
               if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                  observer.sendInterrupted()
               } else {
                  observer.sendFailed(error)
               }
            }
         }
         disposable.addDisposable {
            request.cancel()
         }
         }
         .on(failed: {
            error in
            logger?.logError(error)
         })
         .retainWhileWorking(self)
   }
}

private extension SignalProducerType {
   final func retainWhileWorking(object: AnyObject) -> SignalProducer<Self.Value, Self.Error> {
      var retainedObject: AnyObject? = object
      return self.on(terminated: {
         retainedObject = nil
      })
   }
}

