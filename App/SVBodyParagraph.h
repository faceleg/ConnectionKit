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

@property (nonatomic, retain) NSString * tagName;
@property (nonatomic, retain) NSSet* inlineContentObjects;


- (NSString *)HTMLString;
- (NSString *)innerHTMLString;
- (void)setHTMLStringFromElement:(DOMHTMLElement *)element;
@property(nonatomic, copy) NSString *archivedInnerHTMLString;

@end


@interface SVBodyParagraph (CoreDataGeneratedAccessors)
- (void)addInlineContentObjectsObject:(SVPlugInContentObject *)value;
- (void)removeInlineContentObjectsObject:(SVPlugInContentObject *)value;
- (void)addInlineContentObjects:(NSSet *)value;
- (void)removeInlineContentObjects:(NSSet *)value;

@end

