//
//  CIImage+KTExtensions.h
//  Marvel
//
//  Created by Mike on 13/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTImageScalingSettings;


@interface CIImage (KTExtensions)

- (CIImage *)imageByApplyingScalingSettings:(KTImageScalingSettings *)settings
                                opaqueEdges:(BOOL)anOpaqueEdges;

@end
