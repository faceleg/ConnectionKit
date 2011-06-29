//
//  SVJSONSerialization.m
//  Sandvox
//
//  Created by Mike on 29/06/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVJSONSerialization.h"

#import "JSONKit.h"


@implementation SVJSONSerialization

+ (NSData *)dataWithJSONObject:(id)obj options:(NSUInteger)opt error:(NSError **)error;
{
    return [obj JSONDataWithOptions:0 error:error];
}

@end
