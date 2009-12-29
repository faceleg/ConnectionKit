//
//  SVCallout.h
//  Sandvox
//
//  Created by Mike on 27/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyElement.h"

#import "SVGraphic.h"
#import "SVTemplate.h"


@class SVPagelet;


@interface SVCallout : SVBodyElement

@property(nonatomic, copy) NSSet *pagelets;   // To sort, use SVPagelet class method
- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;

@property(nonatomic, copy) SVContentObjectWrap *wrap;


#pragma mark HTML
+ (SVTemplate *)calloutHTMLTemplate;

@end


@interface SVCallout (CoreDataGeneratedAccessors)
- (void)addPageletsObject:(SVPagelet *)value;
- (void)removePageletsObject:(SVPagelet *)value;
- (void)addPagelets:(NSSet *)value;
- (void)removePagelets:(NSSet *)value;
@end
