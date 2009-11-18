//
//  SVBodyElement.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVPageletBody;

@interface SVBodyElement :  NSManagedObject  

@property (nonatomic, retain) SVPageletBody *body;


#pragma mark Elements Linked List

@property(nonatomic, retain, readonly) SVBodyElement *previousElement;
@property(nonatomic, retain, readonly) SVBodyElement *nextElement;

- (void)insertAfterElement:(SVBodyElement *)element;    // also use to move an already inserted element...
- (void)insertBeforeElement:(SVBodyElement *)element;   // ...does NOT set -body to match
- (void)removeFromElementsList;


#pragma mark HTML
- (NSString *)HTMLString;

// When editing, all SVBodyElements should generate a valid ID that can be used to identify them. Otherwise, they have free choice whether to supply an ID. Thus, this value is not required to be KVO-compliant, but subclasses may choose to do so.
- (NSString *)editingElementID;

@end



