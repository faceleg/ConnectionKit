//
//  SVHTMLContext+HTMLElements.m
//  Sandvox
//
//  Created by Mike on 11/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVHTMLContext.h"


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

- (void)writeStartTag:(NSString *)tagName idName:(NSString *)idName className:(NSString *)className;
{
    [self openTag:tagName];
    if (idName) [self writeAttribute:@"id" value:idName];
    if (className) [self writeAttribute:@"class" value:className];
    [self closeStartTag];
}

@end
