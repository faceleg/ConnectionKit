// 
//  SVTextAttachment.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTextAttachment.h"

#import "SVHTMLContext.h"


@implementation SVTextAttachment 

- (void)writeHTML;
{
    NSString *string = [[[self paragraph] archiveString] substringWithRange:[self range]];
    [[SVHTMLContext currentContext] writeString:string];
}

#pragma mark Range

@dynamic body;
@dynamic pagelet;


- (NSRange)range;
{
    NSRange result = NSMakeRange([[self location] unsignedIntegerValue],
                                 [[self length] unsignedIntegerValue]);
    return result;
}

@dynamic length;
@dynamic location;

@end
