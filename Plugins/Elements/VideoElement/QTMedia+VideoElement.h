//
//  QTMedia+VideoElement.h
//  KTPlugins
//
//  Created by Mike on 15/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>


@interface QTMedia (VideoElement)
- (OSType)sampleDescriptionCodec;
- (NSString *)sampleDescriptionCodecName;
@end
