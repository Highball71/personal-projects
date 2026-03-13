//
//  CameraPermissionService.swift
//  Family Meal Planner
//
//  Wraps AVCaptureDevice camera authorization checks.

import AVFoundation

enum CameraPermissionService {

    static func checkStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
