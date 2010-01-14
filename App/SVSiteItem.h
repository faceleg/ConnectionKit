//
//  SVSiteItem.h
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Everything you see in the Site Outline should be a subclass of SVSiteItem. It:
//  -   Holds a reference to the parent page.
//  -   Returns NSNotApplicableMarker instead of throwing an exception for unknown keys


#import "SVExtensibleManagedObject.h"


@class KTPage, KTMediaContainer;


@interface SVSiteItem : SVExtensibleManagedObject  

#pragma mark Dates
@property(nonatomic, copy) NSDate *creationDate;
@property(nonatomic, copy) NSDate *lastModificationDate;


#pragma mark Tree

@property(nonatomic, copy, readonly) NSSet *childItems;

//  .parentPage is marked as optional in the xcdatamodel file so subentities can choose their own rules. SVSiteItem programmatically makes .parentPage required. Override -validateParentPage:error: in a subclass to turn this off again.
@property(nonatomic, retain) KTPage *parentPage;
- (BOOL)validateParentPage:(KTPage **)page error:(NSError **)outError;

// Don't bother setting this manually, get KTPage or controller to do it
@property(nonatomic) short childIndex;


#pragma mark Site Outline

@property(nonatomic, readonly) BOOL isCollection;
@property(nonatomic, retain, readonly) KTMediaContainer *customSiteOutlineIcon;


@end



