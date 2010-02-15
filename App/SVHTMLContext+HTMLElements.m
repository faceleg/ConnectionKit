//
//  SVHTMLContext+HTMLElements.m
//  Sandvox
//
//  Created by Mike on 11/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVHTMLContext.h"

#import "NSString+Karelia.h"


@implementation SVHTMLContext (HTMLElements)

#pragma mark Higher-level Tag Writing

- (void)writeAnchorStartTagWithHref:(NSString *)href title:(NSString *)titleString target:(NSString *)targetString rel:(NSString *)relString;
{
	[self openTag:@"a"];
	if (href) [self writeAttribute:@"href" value:href];
	if (targetString) [self writeAttribute:@"target" value:targetString];
	if (titleString) [self writeAttribute:@"title" value:titleString];
	if (relString) [self writeAttribute:@"rel" value:relString];
	[self closeStartTag];
}

- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                         src:(NSString *)src
                         alt:(NSString *)alt
                       width:(NSString *)width
                      height:(NSString *)height;
{
    [self openTag:@"img"];
    
    if (idName) [self writeAttribute:@"id" value:idName];
    if (className) [self writeAttribute:@"class" value:className];
    
    [self writeAttribute:@"src" value:src];
    if (alt) [self writeAttribute:@"alt" value:alt];
    if (width) [self writeAttribute:@"width" value:width];
    if (height) [self writeAttribute:@"height" value:height];
    
    [self closeEmptyElementTag];
}

// TODO: disable indentation & newlines when we are in an anchor tag, somehow.

#pragma mark Link

- (void)writeLinkWithHref:(NSString *)href
                     type:(NSString *)type
                      rel:(NSString *)rel
                    title:(NSString *)title
                    media:(NSString *)media;
{
    [self openTag:@"link"];
    
    if (rel) [self writeAttribute:@"rel" value:rel];
    if (type) [self writeAttribute:@"type" value:type];
    [self writeAttribute:@"href" value:href];
    if (title) [self writeAttribute:@"title" value:title];
    if (media) [self writeAttribute:@"media" value:media];
    
    [self closeEmptyElementTag];
}

- (void)writeLinkToStylesheet:(NSString *)href
                        title:(NSString *)title
                        media:(NSString *)media;
{
    [self writeLinkWithHref:href type:@"text/css" rel:@"stylesheet" title:title media:media];
}

- (void)includeStylesheetAtURL:(NSURL *)stylesheetURL;
{
    if ([self isEditable])
    {
        [self writeLinkToStylesheet:[stylesheetURL absoluteString] title:nil media:nil];
        [self writeNewline];
    }
    else if ([self isForQuickLookPreview])
    {
        NSString *stylesheet = [NSString stringWithContentsOfURL:stylesheetURL
                                                fallbackEncoding:0
                                                           error:NULL];
        if (stylesheet)
        {
            [self writeStyleStartTagWithType:@"text/css"];
            [self writeHTMLString:stylesheet];
            [self writeEndTag];
        }
    }
}

#pragma mark Style

- (void)writeStyleStartTagWithType:(NSString *)type;
{
    [self openTag:@"style"];
    if (type) [self writeAttribute:@"type" value:type];
    [self closeStartTag];
}

#pragma mark General

- (void)writeStartTag:(NSString *)tagName idName:(NSString *)idName className:(NSString *)className;
{
    [self openTag:tagName];
    if (idName) [self writeAttribute:@"id" value:idName];
    if (className) [self writeAttribute:@"class" value:className];
    [self closeStartTag];
}

@end
