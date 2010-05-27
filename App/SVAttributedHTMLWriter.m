//
//  SVAttributedHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 19/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVAttributedHTMLWriter.h"
#import "SVAttributedHTML.h"

#import "SVGraphic.h"
#import "SVParagraphedHTMLWriter.h"
#import "SVRichText.h"
#import "SVTextAttachment.h"
#import "SVRichTextDOMController.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSString+Karelia.h"


@implementation SVAttributedHTMLWriter

- (id)initWithAttributedHTML:(NSMutableAttributedString *)attributedHTML;
{
    [super init];
    _attributedHTML = [attributedHTML retain];
    return self;
}

- (id)init
{
    NSMutableAttributedString *attributedHTML = [[NSMutableAttributedString alloc] init];
    self = [self initWithAttributedHTML:attributedHTML];
    [attributedHTML release];
    
    return self;
}

- (void)dealloc
{
    [_attributedHTML release];
    
    [super dealloc];
}

- (void)writeGraphicController:(SVDOMController *)controller
{
    // Write the graphic
    SVGraphic *graphic = [controller representedObject];
    
    NSAttributedString *attributedString =
    [[NSAttributedString alloc] initWithString:[NSString stringWithUnichar:NSAttachmentCharacter]
                                    attributes:[NSDictionary dictionaryWithObject:graphic
                                                                           forKey:@"SVAttachment"]];
    
    [_attributedHTML appendAttributedString:attributedString];
    [attributedString release];
}

- (DOMNode *)HTMLWriter:(KSHTMLWriter *)writer willWriteDOMElement:(DOMElement *)element;
{
    for (SVDOMController *aController in _graphicControllers)
    {
        if ([aController HTMLElement] == element)
        {
            [self writeGraphicController:aController];
            return [element nextSibling];
        }
    }
    
    
    return element;
}

- (void)writeDOMRange:(DOMRange *)range graphicControllers:(NSArray *)graphicControllers;
{
    SVHTMLWriter *writer = [[SVHTMLWriter alloc] initWithStringWriter:self];
    [writer setDelegate:self];
    
    _graphicControllers = graphicControllers;
    [writer writeDOMRange:range];
    _graphicControllers = nil;
    
    [writer release];
}

+ (void)writeDOMRange:(DOMRange *)range
         toPasteboard:(NSPasteboard *)pasteboard
   graphicControllers:(NSArray *)graphicControllers;
{
    // Add our own custom type to the pasteboard
    NSMutableAttributedString *attributedHTML = [[NSMutableAttributedString alloc] init];
    
    SVAttributedHTMLWriter *writer = [[self alloc] initWithAttributedHTML:attributedHTML];
    [writer writeDOMRange:range graphicControllers:graphicControllers];
    [writer release];
    
    [attributedHTML attributedHTMLStringWriteToPasteboard:pasteboard];
    [attributedHTML release];
}

#pragma mark KSStringWriter

- (void)writeString:(NSString *)string;
{
    NSRange range = NSMakeRange([_attributedHTML length], 0);
    [_attributedHTML replaceCharactersInRange:range withString:string];
    
    range.length = [string length];
    [_attributedHTML setAttributes:nil range:range];
}

- (void)close; { }

@end
