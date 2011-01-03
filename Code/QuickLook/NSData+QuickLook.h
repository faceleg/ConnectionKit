//
//  NSData+QuickLook.h
//  SandvoxQuickLook
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSData (QuickLook)
+ (NSData *)dataWithBase64EncodedString:(NSString *)base64String;
@end
