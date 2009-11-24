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
- (NSArray *)orderedElements;       // not KVO-compliant


#pragma mark HTML

- (NSString *)HTMLString;

// Acts kind of like a binding & a formatter in one. The receiver is edited to match the element, but the element may also be "standardised" too
- (void)updateWithHTMLElement:(DOMHTMLElement *)element;

@end