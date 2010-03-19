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

- (void)writeContentsOfTextDOMController:(SVTextDOMController *)domController
                        toAttributedHTML:(SVRichText *)textObject;
{
    //  Write the whole out using a special stream
    
    _htmlWritten = [[NSMutableString alloc] init];
    
    SVParagraphedHTMLWriter *context = 
    [[SVParagraphedHTMLWriter alloc] initWithStringWriter:_htmlWritten];
    
    [context setDelegate:self];
    [context setBodyTextDOMController:(id)domController];
    
    
    _textDOMController = domController;
    _attachmentsWritten = [[NSMutableSet alloc] init];
    
    
    // Top-level nodes can only be: paragraph, newline, or graphic. Custom DOMNode addition handles this
    DOMNode *aNode = [[domController textHTMLElement] firstChild];
    while (aNode)
    {
        aNode = [aNode topLevelBodyTextNodeWriteToStream:context];
    }
    
    
    if (![_htmlWritten isEqualToString:[textObject string]])
    {
        [textObject setString:_htmlWritten
                  attachments:_attachmentsWritten];
    }
    
    
    // Tidy up
    [context release];
    [_htmlWritten release];
    [_attachmentsWritten release];
    _textDOMController = nil;
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

    
@end
