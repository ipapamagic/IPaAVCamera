//
//  IPaAVCameraView.swift
//  Pods
//
//  Created by IPa Chen on 2021/4/30.
//  Copyright 2021 ___ORGANIZATIONNAME___. All rights reserved.
//

import SwiftUI
import AVFoundation
@available(iOS 13.0, *)
public struct IPaAVCameraView: UIViewRepresentable {
    public var camera:IPaAVCamera
    public var videoGravity:AVLayerVideoGravity
    public init(camera:IPaAVCamera,videoGravity:AVLayerVideoGravity) {
        self.camera = camera
        self.videoGravity = videoGravity
    }
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        camera.setPreviewView(view, videoGravity: videoGravity)
        
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}

