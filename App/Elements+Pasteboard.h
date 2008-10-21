//
//  Elements+Pasteboard.h
//  Marvel
//
//  Created by Mike on 06/09/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPage+Internal.h"
#import "KTPagelet+Internal.h"

#import "KTPasteboardArchiving.h"


@interface KTAbstractElement (Pasteboard) <KTPasteboardArchiving>
@end


@interface KTPage (Pasteboard)
+ (KTPage *)pageWithPasteboardRepresentation:(NSDictionary *)archive parent:(KTPage *)parent;
@end


@interface KTPagelet (Pasteboard)
+ (KTPagelet *)pageletWithPasteboardRepresentation:(NSDictionary *)archive page:(KTPage *)page;
@end