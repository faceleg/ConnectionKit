//
//  SVPasteboardItem.m
//  Sandvox
//
//  Created by Mike on 08/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPasteboardItem.h"


@implementation SVPasteboardItem

- (void)dealloc;
{
    [_title release];
    [_URL release];
    
    [super dealloc];
}

@end



@implementation KSWebLocation (SVPasteboardItem)

- (NSArray *)types;
{
    return [[self class] webLocationPasteboardTypes];
}

- (NSString *)availableTypeFromArray:(NSArray *)types;
{
    // This is the poor man's version that checks only equality, not conformance
    return [types firstObjectCommonWithArray:[self types]];
}

- (NSData *)dataForType:(NSString *)type;
{
    if ([[NSWorkspace sharedWorkspace] type:type conformsToType:(NSString *)kUTTypeURL])
    {
        return NSMakeCollectable(CFURLCreateData(NULL,
                                                 (CFURLRef)[self URL],
                                                 kCFStringEncodingUTF8,
                                                 NO));
    }
    
    return nil;
}

- (NSString *)stringForType:(NSString *)type;
{
    if ([[NSWorkspace sharedWorkspace] type:type conformsToType:(NSString *)kUTTypeURL] ||
        [type isEqualToString:NSURLPboardType] ||
        [type isEqualToString:NSStringPboardType])
    {
        return [[self URL] absoluteString];
    }
    
    return nil;
}

- (id)propertyListForType:(NSString *)type;
{
    return [self stringForType:type];
}

@end
