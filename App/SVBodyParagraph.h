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
@property(nonatomic, copy) NSString *innerHTMLArchiveString;
@property (nonatomic, retain) NSSet* inlineGraphics;


#pragma mark HTML

- (NSString *)HTMLString;
- (void)setHTMLStringFromElement:(DOMHTMLElement *)element;

- (NSString *)innerHTMLString;

+ (NSString *)innerHTMLStringWithArchive:(NSString *)innerHTMLArchiveString
                    inlineContentObjects:(NSSet *)contentObjects;

@end


@interface SVBodyParagraph (CoreDataGeneratedAccessors)
- (void)addInlineGraphicsObject:(SVPlugInGraphic *)value;
- (void)removeInlineGraphicsObject:(SVPlugInGraphic *)value;
- (void)addInlineGraphics:(NSSet *)value;
- (void)removeInlineGraphics:(NSSet *)value;

@end

