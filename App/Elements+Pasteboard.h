//
//  Elements+Pasteboard.h
//  Marvel
//
//  Created by Mike on 06/09/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Internal.h"

#import "KTPasteboardArchiving.h"


@interface KTAbstractElement (Pasteboard) <KTPasteboardArchiving>
@end


@interface KTPage (Pasteboard)
+ (KTPage *)pageWithPasteboardRepresentation:(NSDictionary *)archive parent:(KTPage *)parent;
@end