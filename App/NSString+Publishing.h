//
//  NSString+Publishing.h
//  Marvel
//
//  Created by Mike on 22/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (Publishing)
- (NSString *)stringByAdjustingHTMLForPublishing;
@end


@interface NSString (FileSizeFormatting)
+ (NSString *)formattedFileSizeWithBytes:(NSNumber *)filesize;
@end


@interface NSString (KTPathHelper)
- (NSString *)stringByDeletingFirstPathComponent2;
- (NSString *)firstPathComponent;
@end


