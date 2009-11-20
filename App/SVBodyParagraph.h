//
//  SVParagraph.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVBodyElement.h"

@class SVPlugInContentObject;

@interface SVBodyParagraph :  SVBodyElement  

#pragma mark Properties

@property (nonatomic, retain) NSString * tagName;
@property(nonatomic, copy) NSString *innerHTMLArchiveString;
@property (nonatomic, retain) NSSet* inlineContentObjects;


#pragma mark HTML

- (NSString *)HTMLString;
- (void)setHTMLStringFromElement:(DOMHTMLElement *)element;

- (NSString *)innerHTMLString;

@end


@interface SVBodyParagraph (CoreDataGeneratedAccessors)
- (void)addInlineContentObjectsObject:(SVPlugInContentObject *)value;
- (void)removeInlineContentObjectsObject:(SVPlugInContentObject *)value;
- (void)addInlineContentObjects:(NSSet *)value;
- (void)removeInlineContentObjects:(NSSet *)value;

@end

