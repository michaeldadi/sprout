//
//  AppDelegateInAppMessageUIExt.swift
//  Sprout
//
//  Created by Michael Dadi on 8/21/25.
//

import UIKit
import BrazeKit
import BrazeUI
import StoreKit


extension AppDelegate: BrazeInAppMessageUIDelegate {

  func inAppMessage(
    _ ui: BrazeInAppMessageUI,
    prepareWith context: inout BrazeInAppMessageUI.PresentationContext
  ) {
    let inAppMessageUI = BrazeInAppMessageUI()
    inAppMessageUI.delegate = self
    AppDelegate.braze?.inAppMessagePresenter = inAppMessageUI

    BrazeInAppMessageUI.ModalImageView.Attributes.defaults.dismissOnBackgroundTap = true
    
    context.statusBarHideBehavior = .visible
    context.preferredOrientation = .portrait

    var cardAttrs = BrazeContentCardUI.ViewController.Attributes.defaults.cellAttributes

    cardAttrs.cornerRadius = 20
    cardAttrs.classicImageCornerRadius = 10

    if #available(iOS 13.0, *) {
      cardAttrs.cornerCurve = .continuous
    }
  }


  func inAppMessage(
    _ ui: BrazeInAppMessageUI,
    didPresent message: Braze.InAppMessage,
    view: InAppMessageView
  ) {
    // Executed when `message` is presented to the user
  }
  
  func inAppMessage(_ ui: BrazeInAppMessageUI, displayChoiceForMessage message: Braze.InAppMessage) -> BrazeInAppMessageUI.DisplayChoice {
    if message.extras["AppStore Review"] != nil,
       let messageUrl = message.clickAction.url {
      UIApplication.shared.open(messageUrl, options: [:], completionHandler: nil)
      return .discard
    } else if !showMessage {
      return .reenqueue
    } else {
      return .now
    }
  }

  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    let urlString = url.absoluteString.removingPercentEncoding
    if (urlString == "com.sprout:app-store-review") {
      if let scene = UIApplication.shared.connectedScenes .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
          SKStoreReviewController.requestReview(in: scene)
      }
      return true
    }
    return false
  }
}
