// 
//  SVContentObject.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "SVPageletBody.h"

@implementation SVContentObject 

@dynamic elementID;
@dynamic container;

- (NSString *)archiveHTMLString;
{
    NSString *result = [NSString stringWithFormat:@"<object id=\"%@\" />", [self elementID]];
    return result;
}

- (NSString *)editingHTMLString;
{
    // TODO: Return something real
    return @"<img />";
}

@end
