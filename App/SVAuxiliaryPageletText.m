// 
//  SVAuxiliaryPageletText.m
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAuxiliaryPageletText.h"

#import "SVGraphic.h"
#import "SVHTMLTextBlock.h"


@implementation SVAuxiliaryPageletText 

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:@"<p><br /></p>" forKey:@"string"];
}

@dynamic pagelet;
@dynamic hidden;

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;
{
    SVHTMLTextBlock *textBlock = [[SVHTMLTextBlock alloc] init];
    [textBlock setHTMLSourceObject:[self pagelet]];
    [textBlock setHTMLSourceKeyPath:@"caption"];
    [textBlock setEditable:YES];
    [textBlock setImportsGraphics:YES];
    [textBlock setCustomCSSClassName:@"caption"];
    
    [textBlock writeHTML:context];
    [textBlock release];
}

- (BOOL)isPagelet; { return NO; }
- (BOOL)shouldWriteHTMLInline; { return YES; }

#pragma mark Metrics

- (NSNumber *)width;
{
    return [[self pagelet] extensiblePropertyForKey:@"captionWidth"];
}

- (void)setWidth:(NSNumber *)width;
{
    [[self pagelet] setExtensibleProperty:width forKey:@"captionWidth"];
}

- (NSNumber *)contentWidth;
{
    return [self width];
}

- (void) setContentWidth:(NSNumber *)width;
{
    [self setWidth:width];
}

@end
