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

- (id)init
{
    [super init];
    
    _htmlWritten = [[NSMutableString alloc] init];
    _attachmentsWritten = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_htmlWritten release];
    [_attachmentsWritten release];
    
    [super dealloc];
}

- (void)writeToPasteboard:(NSPasteboard *)pasteboard;
{
    NSDictionary *plist = [[NSDictionary alloc] initWithObjectsAndKeys:
                           _htmlWritten, @"HTMLString",
                           _attachmentsWritten, @"attachments",
                           nil];
    
    [pasteboard setPropertyList:plist forType:@"com.karelia.html+graphics"];
    [plist release];
}

- (void)writeGraphicController:(SVDOMController *)controller
                withHTMLWriter:(KSHTMLWriter *)writer;
{
    SVGraphic *graphic = [controller representedObject];
    SVTextAttachment *textAttachment = [graphic textAttachment];
    [_attachmentsWritten addObject:[textAttachment propertyList]];
}

- (BOOL)HTMLWriter:(KSHTMLWriter *)writer writeDOMElement:(DOMElement *)element;
{
    for (SVDOMController *aController in _graphicControllers)
    {
        if ([aController HTMLElement] == element)
        {
            [self writeGraphicController:aController withHTMLWriter:writer];
            return YES;
        }
    }
    
    
    return NO;
}

- (void)writeDOMRange:(DOMRange *)range graphicControllers:(NSArray *)graphicControllers;
{
    SVHTMLWriter *writer = [[SVHTMLWriter alloc] initWithStringWriter:_htmlWritten];
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
    SVAttributedHTMLWriter *writer = [[SVAttributedHTMLWriter alloc] init];
    [writer writeDOMRange:range graphicControllers:graphicControllers];
    [writer writeToPasteboard:pasteboard];
    [writer release];
}

@end
