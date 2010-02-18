//
//  SVSidebar.h
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class KTAbstractPage;
@class SVGraphic;

@interface SVSidebar : NSManagedObject  

@property (nonatomic, retain) KTAbstractPage * page;

@property(nonatomic, retain) NSSet *pagelets;   // To sort, use SVGraphic class method
- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;


#pragma mark HTML
- (void)writePageletsHTML;

@end


@interface SVSidebar (CoreDataGeneratedAccessors)
- (void)addPageletsObject:(SVGraphic *)value;
- (void)removePageletsObject:(SVGraphic *)value;
- (void)addPagelets:(NSSet *)value;
- (void)removePagelets:(NSSet *)value;

@end

