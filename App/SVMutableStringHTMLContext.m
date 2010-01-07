//
//  SVMutableStringHTMLContext.m
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMutableStringHTMLContext.h"

#import "NSString+Karelia.h"


@implementation SVMutableStringHTMLContext

- (id)initWithMutableString:(NSMutableString *)string;  // designated initializer
{
    OBPRECONDITION(string);
    
    [super init];
    _mutableString = [string retain];
    return self;
}

- (id)init; // Uses an empty NSMutableString
{
    NSMutableString *string = [[NSMutableString alloc] init];
    self = [self initWithMutableString:string];
    [string release];
    
    return self;
}

@synthesize mutableString = _mutableString;

- (NSString *)markupString;
{
    NSString *result = [[[self mutableString] copy] autorelease];
    
    if (![self isXHTML])	// convert /> to > for HTML 4.0.1 compatibility
	{
		result = [result stringByReplacing:@"/>" with:@">"];
	}
	
	result = [result stringByEscapingCharactersOutOfEncoding:[self encoding]];
    
	
	return result;
}

- (void)writeString:(NSString *)html
{
    [[self mutableString] appendString:html];
}

@end
