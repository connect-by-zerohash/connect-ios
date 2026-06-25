import Foundation

@MainActor
protocol UIWebViewMessageRouterDelegate: AnyObject {
    func uiWebViewRouterDidReceiveContentReady(_ router: UIWebViewMessageRouter)
    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveNavigate url: String, mobileTarget: String?)
    func uiWebViewRouterDidReceiveClose(_ router: UIWebViewMessageRouter)
    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveError data: [String: Any], jsonString: String)
    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveEvent data: [String: Any], jsonString: String)
    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveDeposit data: [String: Any], jsonString: String)
    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveWithdrawal data: [String: Any], jsonString: String)
}
