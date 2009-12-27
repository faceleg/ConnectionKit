//
//  SVSidebar.h
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class KTAbstractPage;
@class SVPagelet;

@interface SVSidebar : NSManagedObject  

@property (nonatomic, retain) KTAbstractPage * page;

@property(nonatomic, retain) NSSet *pagelets;   // To sort, use SVPagelet class method
- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;


#pragma mark HTML
- (NSString *)pageletsHTMLString;

@end


@interface SVSidebar (CoreDataGeneratedAccessors)
- (void)addPageletsObject:(SVPagelet *)value;
- (void)removePageletsObject:(SVPagelet *)value;
- (void)addPagelets:(NSSet *)value;
- (void)removePagelets:(NSSet *)value;

@end

