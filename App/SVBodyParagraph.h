//
//  SVParagraph.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVBodyElement.h"

@class SVPlugInGraphic;

@interface SVBodyParagraph :  SVBodyElement  

#pragma mark Properties

@property (nonatomic, retain) NSString * tagName;
@property(nonatomic, copy) NSString *archiveString;
@property (nonatomic, retain) NSSet* inlineGraphics;


#pragma mark HTML

- (void)setHTMLStringFromElement:(DOMHTMLElement *)element;

- (void)writeInnerHTML;


@end


@interface SVBodyParagraph (CoreDataGeneratedAccessors)
- (void)addInlineGraphicsObject:(SVPlugInGraphic *)value;
- (void)removeInlineGraphicsObject:(SVPlugInGraphic *)value;
- (void)addInlineGraphics:(NSSet *)value;
- (void)removeInlineGraphics:(NSSet *)value;

@end

