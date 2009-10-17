// 
//  SVContentObject.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "SVPageletBody.h"

#import "NSString+Karelia.h"


@implementation SVContentObject 

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:[NSString UUIDString] forKey:@"elementID"];
    [self setPrimitiveValue:@"??" forKey:@"plugInVersion"];
}

@dynamic elementID;
@dynamic plugInIdentifier;
@dynamic container;

- (NSString *)archiveHTMLString;
{
    NSString *result = [NSString stringWithFormat:@"<object id=\"%@\" />", [self elementID]];
    return result;
}

- (NSString *)editingHTMLString;
{
    // TODO: Return something real
    return @"<img src=\"foo://bar\" />";
}

@end
