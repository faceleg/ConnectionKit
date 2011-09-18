//
//  SVPageletTitleBox.m
//  Sandvox
//
//  Created by Mike on 15/03/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVPageletTitleBox.h"

#import "SVHTMLTextBlock.h"
#import "SVTextAttachment.h"
#import "SVTextDOMController.h"


@implementation SVPageletTitleBox

+ (NSString *)alignmentKeyPath; { return @"pagelet.titleAlignment"; }
+ (NSString *)textBaseWritingDirectionKeyPath; { return @"pagelet.titleWritingDirection"; }

@dynamic pagelet;

#pragma mark Validation

- (BOOL)validateForInsert:(NSError **)error;
{
    BOOL result = [super validateForInsert:error];
    if (result && [[self pagelet] textAttachment]) result = [[[self pagelet] textAttachment] validateWrapping:error];
    return result;
}

- (BOOL)validateForUpdate:(NSError **)error;
{
    BOOL result = [super validateForUpdate:error];
    if (result && [[self pagelet] textAttachment]) result = [[[self pagelet] textAttachment] validateWrapping:error];
    return result;
}

- (SVTextDOMController *)newTextDOMControllerWithIdName:(NSString *)elementID ancestorNode:(DOMNode *)node;
{
    SVTextDOMController *result = [super newTextDOMControllerWithIdName:elementID ancestorNode:node];
    [result setSelectable:YES];
    return result;
}

@end
