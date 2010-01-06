//
//  SVMutableStringHTMLContext.m
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMutableStringHTMLContext.h"


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

- (void)writeHTMLString:(NSString *)html
{
    [[self mutableString] appendString:html];
}

@end
