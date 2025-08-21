//
//  TopBannerView.swift
//  Sprout
//
//  Created by Michael Dadi on 8/21/25.
//

import BrazeKit
import BrazeUI
import SwiftUI
 
@available(iOS 13.0, *)
struct BannerViewController: View {
  
  static let bannerPlacementID = "top-1"
  
  @State var hasBannerForPlacement: Bool = false
  @State var contentHeight: CGFloat = 0
  
  var body: some View {
    Group {
      if let braze = AppDelegate.braze,
         hasBannerForPlacement
      {
        BrazeBannerUI.BannerView(
          placementId: BannerViewController.bannerPlacementID,
          braze: braze,
          processContentUpdates: { result in
            switch result {
            case .success(let updates):
              if let height = updates.height {
                self.contentHeight = height
              }
            case .failure:
              return
            }
          }
        )
        .frame(height: min(contentHeight, 80))
      }
    }
    .onAppear {
      AppDelegate.braze?.banners.getBanner(
        for: BannerViewController.bannerPlacementID,
        { banner in
          hasBannerForPlacement = banner != nil
        }
      )
    }
  }
}
