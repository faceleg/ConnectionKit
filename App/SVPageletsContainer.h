//
//  SVPageletsContainer.h
//  Sandvox
//
//  Created by Mike on 27/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVPagelet;


@interface SVPageletsContainer : NSManagedObject

@property(nonatomic, retain) NSSet *pagelets;   // To sort, use SVPagelet class method
- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;

@end


@interface SVPageletsContainer (CoreDataGeneratedAccessors)
- (void)addPageletsObject:(SVPagelet *)value;
- (void)removePageletsObject:(SVPagelet *)value;
- (void)addPagelets:(NSSet *)value;
- (void)removePagelets:(NSSet *)value;
@end

