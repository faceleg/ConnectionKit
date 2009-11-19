//
//  SVParagraphController.h
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@class SVBodyParagraph;

@interface SVParagraphController : NSObject
{
  @private
    DOMHTMLElement  *_HTMLElement;
    SVBodyParagraph *_paragraph;
}

- (id)initWithParagraph:(SVBodyParagraph *)paragraph HTMLElement:(DOMHTMLElement *)domElement;
@property(nonatomic, retain, readonly) SVBodyParagraph *paragraph;
@property(nonatomic, retain, readonly) DOMHTMLElement *paragraphHTMLElement;

@end
