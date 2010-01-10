// 
//  SVStringAttribute.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVStringAttribute.h"

#import "SVBodyParagraph.h"
#import "SVHTMLContext.h"


@implementation SVStringAttribute 

- (void)writeHTML;
{
    NSString *string = [[[self paragraph] archiveString] substringWithRange:[self range]];
    [[SVHTMLContext currentContext] writeString:string];
}

#pragma mark Range

@dynamic length;
@dynamic location;
- (NSRange)range;
{
    NSRange result = NSMakeRange([[self location] unsignedIntegerValue],
                                 [[self length] unsignedIntegerValue]);
    return result;
}

#pragma mark Paragraph

@dynamic paragraph;

@end
