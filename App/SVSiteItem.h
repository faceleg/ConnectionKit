//
//  SVSiteItem.h
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVExtensibleManagedObject.h"


@class KTPage;

@interface SVSiteItem : SVExtensibleManagedObject  
{
}

@property (nonatomic, retain) KTPage *parentPage;

@end



