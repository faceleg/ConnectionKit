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

- (id)initWithMutableString:(NSMutableString *)string;
{
    OBPRECONDITION(string);
    
    self = [self initWithStringStream:string];
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
	result = [result stringByRemovingMultipleNewlines];		// clean out empty lines
	
	return result;
}

@end
