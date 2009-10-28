//
//  SVSidebar.h
//  Sandvox
//
//  Created by Mike on 28/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class KTAbstractPage;
@class SVPagelet;

@interface SVSidebar :  NSManagedObject  
{
}

@property (nonatomic, retain) NSSet* pagelets;
@property (nonatomic, retain) KTAbstractPage * page;

@end


@interface SVSidebar (CoreDataGeneratedAccessors)
- (void)addPageletsObject:(SVPagelet *)value;
- (void)removePageletsObject:(SVPagelet *)value;
- (void)addPagelets:(NSSet *)value;
- (void)removePagelets:(NSSet *)value;

@end

