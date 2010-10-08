//
//  SVPasteboardItem.h
//  Sandvox
//
//  Created by Mike on 08/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPasteboardItem.h"
#import "KSWebLocation.h"


@interface NSPasteboard (SVPasteboardItem) <SVPasteboardItem>
@end


#if (defined MAC_OS_X_VERSION_10_6) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
@interface NSPasteboardItem (SVPasteboardItem) <SVPasteboardItem>
@end
#endif


@interface KSWebLocation (SVPasteboardItem) <SVPasteboardItem>
@end


@interface SVPasteboardItem : NSObject
{
  @private
    NSString    *_title;
    NSURL       *_URL;
}

@end
