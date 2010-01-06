//
//  SVPageletBody.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

@class SVBodyElement;
@class SVPagelet;


@interface SVBody : SVContentObject  

+ (SVBody *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
+ (SVBody *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;


@property (nonatomic, retain, readonly) NSSet *elements;
- (NSArray *)orderedElements;       // not KVO-compliant
- (void)addElement:(SVBodyElement *)element;    // convenience
- (NSSet *)graphics;


@end