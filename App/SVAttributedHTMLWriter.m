//
//  SVAttributedHTMLWriter.m
//  Sandvox
//
//  Created by Mike on 19/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAttributedHTMLWriter.h"

#import "SVGraphic.h"
#import "SVParagraphedHTMLWriter.h"
#import "SVRichText.h"
#import "SVTextAttachment.h"
#import "SVBodyTextDOMController.h"

#import "NSString+Karelia.h"


@implementation SVAttributedHTMLWriter

+ (void)writeContentsOfTextDOMController:(SVTextDOMController *)domController
                        toAttributedHTML:(SVRichText *)textObject;
{
    SVAttributedHTMLWriter *writer = [[self alloc] init];
    
    //  Write the whole out using a special stream
        
    SVParagraphedHTMLWriter *context = 
    [[SVParagraphedHTMLWriter alloc] initWithStringWriter:writer->_htmlWritten];
    
    [context setDelegate:writer];
    [context setBodyTextDOMController:(id)domController];
    
    
    writer->_textDOMController = domController;
    
    
    // Top-level nodes can only be: paragraph, newline, or graphic. Custom DOMNode addition handles this
    DOMNode *aNode = [[domController textHTMLElement] firstChild];
    while (aNode)
    {
        aNode = [aNode topLevelBodyTextNodeWriteToStream:context];
    }
    
    
    if (![writer->_htmlWritten isEqualToString:[textObject string]])
    {
        [textObject setString:writer->_htmlWritten
                  attachments:writer->_attachmentsWritten];
    }
    
    
    // Tidy up
    [context release];
    [writer release];
}

- (id)init
{
    [super init];
    
    _htmlWritten = [[NSMutableString alloc] init];
    _attachmentsWritten = [[NSMutableSet alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_htmlWritten release];
    [_attachmentsWritten release];
    
    [super dealloc];
}

- (void)writeGraphicController:(SVDOMController *)controller
                withHTMLWriter:(KSHTMLWriter *)writer;
{
    SVGraphic *graphic = [controller representedObject];
    SVTextAttachment *textAttachment = [graphic textAttachment];
    
    
    
    // Set attachment location
    [writer writeString:[NSString stringWithUnichar:NSAttachmentCharacter]];
    
    NSUInteger location = [_htmlWritten length] - 1;
    if ([textAttachment range].location != location)
    {
        [textAttachment setLocation:[NSNumber numberWithUnsignedInteger:location]];
        [textAttachment setLength:[NSNumber numberWithShort:1]];
    }
    
    [_attachmentsWritten addObject:[[controller representedObject] textAttachment]];
}

- (BOOL)HTMLWriter:(KSHTMLWriter *)writer writeDOMElement:(DOMElement *)element;
{
    NSArray *graphicControllers = [(id)_textDOMController graphicControllers];
    
    for (SVDOMController *aController in graphicControllers)
    {
        if ([aController HTMLElement] == element)
        {
            [self writeGraphicController:aController withHTMLWriter:writer];
            return YES;
        }
    }
    
    
    return NO;
}

+ (void)writeDOMRange:(DOMRange *)range
         toPasteboard:(NSPasteboard *)pasteboard
   graphicControllers:(NSArray *)graphicControllers;
{
    // Add our own custom type to the pasteboard
    NSMutableString *html = [[NSMutableString alloc] init];
    SVHTMLWriter *writer = [[SVHTMLWriter alloc] initWithStringWriter:html];
    [writer setDelegate:self];
    
    [writer writeDOMRange:range];
    [writer release];
    
    [pasteboard setString:html forType:@"com.karelia.html+graphics"];
    [html release];
}

@end
