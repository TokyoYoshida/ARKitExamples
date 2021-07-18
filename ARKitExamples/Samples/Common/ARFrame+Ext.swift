//
//  ARFrame+Ext.swift
//  ARKitExamples
//
//  Created by TokyoYoshida on 2021/07/18.
//

import ARKit

extension ARFrame {
    fileprivate func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int, textureCache: CVMetalTextureCache) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }

    func buildCapturedImageTextures(textureCache: CVMetalTextureCache) -> (textureY: CVMetalTexture, textureCbCr: CVMetalTexture)? {
        // Create two textures (Y and CbCr) from the provided frame's captured image
        let pixelBuffer = self.capturedImage
        
        guard CVPixelBufferGetPlaneCount(pixelBuffer) < 2 else {
            return nil
        }
        
        guard let capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0, textureCache: textureCache),
              let capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1, textureCache: textureCache) else {
            return nil
        }
        
        return (textureY: capturedImageTextureY, textureCbCr: capturedImageTextureCbCr)
    }
}
