//
//  SVAttributedHTML.m
//  Sandvox
//
//  Created by Mike on 20/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAttributedHTML.h"

#import "SVHTMLContext.h"


@implementation SVAttributedHTML

#pragma mark Init & Dealloc

- (id)init;
{
    [super init];
    _string = [[NSMutableString alloc] init];
    return self;
}

- (id)initWithString:(NSString *)str;
{
    [super init];
    _string = [str mutableCopy];
    return self;
}

- (void)dealloc
{
    [_string release];
    [super dealloc];
}

#pragma mark Primitives

- (NSString *)string { return [[_string copy] autorelease]; }

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range;
{
    
}

- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString
{
    
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
    
}

#pragma mark Output

- (void)writeHTMLToContext:(SVHTMLContext *)context;
{
    [context writeHTMLString:[self string]];
}

@end
