//
//  SVPasteboardItem.h
//  Sandvox
//
//  Created by Mike on 08/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVPasteboardItem.h"
#import "KSWebLocationPasteboardUtilities.h"


@interface NSPasteboard (SVPasteboardItem) <SVPasteboardItem>
- (NSArray *)sv_pasteboardItems;
@end


#if (defined MAC_OS_X_VERSION_10_6) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
@interface NSPasteboardItem (SVPasteboardItem) <SVPasteboardItem>
@end
#endif


@interface KSWebLocation (SVPasteboardItem) <SVPasteboardItem>
@end


@interface SVPasteboardItem : KSWebLocation
{
  @private
    NSDictionary    *_metadata;
}

+ (id)pasteboardItemWithURL:(NSURL *)url title:(NSString *)title metadata:(NSDictionary *)metadata;

@end
