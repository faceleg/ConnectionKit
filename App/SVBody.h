//
//  SVPageletBody.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVBodyElement;
@class SVPagelet;


@interface SVBody :  NSManagedObject  

@property (nonatomic, retain) SVPagelet *pagelet;


@property (nonatomic, retain, readonly) NSSet *elements;
- (NSArray *)orderedElements;       // not KVO-compliant
- (void)addElement:(SVBodyElement *)element;    // convenience

#pragma mark HTML

- (NSString *)HTMLString;

@end