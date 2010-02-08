//
//  SVParagraphHTMLContext.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  A rather specialised HTML Context that writes to a SVBodyParagraph object, splitting it between .archiveString and .links


#import "SVMutableStringHTMLContext.h"


@class SVBodyParagraph;


@interface SVParagraphHTMLContext : SVMutableStringHTMLContext
{
  @private
    SVBodyParagraph *_paragraph;
}

- (id)initWithParagraph:(SVBodyParagraph *)paragraph;
@property(nonatomic, retain, readonly) SVBodyParagraph *paragraph;


#pragma mark Tag Whitelist
+ (BOOL)isTagAllowed:(NSString *)tagName;
+ (BOOL)isTagParagraphContent:(NSString *)tagName;


@end
