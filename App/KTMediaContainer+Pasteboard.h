//
//  KTMediaContainer+Pasteboard.h
//  Marvel
//
//  Created by Mike on 30/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaContainer.h"


@interface KTMediaContainerPasteboardRepresentation : NSObject <NSCoding>
{
	BDAlias *myAlias;
}

- (id)initWithAlias:(BDAlias *)alias;
- (BDAlias *)alias;

@end


