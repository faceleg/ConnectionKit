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


@interface SVPageletBody :  NSManagedObject  

@property (nonatomic, retain) SVPagelet *pagelet;

@property (nonatomic, retain, readonly) NSSet *elements;
- (void)addElement:(SVBodyElement *)element;    // must follow up by sending element a -move… call

@end