//
//  Elements+Pasteboard.h
//  Marvel
//
//  Created by Mike on 06/09/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractElement.h"
#import "KTPagelet+Internal.h"

#import "KTPasteboardArchiving.h"


@interface KTAbstractElement (Pasteboard) <KTPasteboardArchiving>
@end


@interface KTPagelet (Pasteboard)
+ (KTPagelet *)pageletWithPasteboardRepresentation:(NSDictionary *)archive page:(KTPage *)page;
@end