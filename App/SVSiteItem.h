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

#pragma mark Dates
@property(nonatomic, copy) NSDate *creationDate;
@property(nonatomic, copy) NSDate *lastModificationDate;


#pragma mark Tree

//  .parentPage is marked as optional in the xcdatamodel file so subentities can choose their own rules. SVSiteItem programmatically makes .parentPage required. Override -validateParentPage:error: in a subclass to turn this off again.
@property(nonatomic, retain) KTPage *parentPage;
- (BOOL)validateParentPage:(KTPage **)page error:(NSError **)outError;

// Don't bother setting this manually, get KTPage or controller to do it
@property(nonatomic) short childIndex;

@end



