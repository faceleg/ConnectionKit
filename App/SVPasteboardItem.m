//
//  SVPasteboardItem.m
//  Sandvox
//
//  Created by Mike on 08/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVPasteboardItemInternal.h"

#import <iMedia/iMedia.h>


@implementation SVPasteboardItem

- (void)dealloc;
{
    [_title release];
    [_URL release];
    
    [super dealloc];
}

@end


#pragma mark -


// Irritatingly, trying to implement the real category gives build warnings claiming methods like -type aren't implemented
@implementation NSPasteboard (SVPasteboardItem_)

- (NSString *)title; { return [WebView URLTitleFromPasteboard:self]; }

- (NSURL *)URL { return [WebView URLFromPasteboard:self]; }

- (NSArray *)sv_pasteboardItems;
{
    // Start with iMedia
    IMBObjectsPromise *promise = [IMBObjectsPromise promiseFromPasteboard:self];
    
    // Redirect remote downloads from default location to temp dir. #106173
    if ([promise destinationDirectoryPath])
    {
        [promise setDestinationDirectoryPath:NSTemporaryDirectory()];
    }
    
    [promise start];
    [promise waitUntilFinished];
    
    NSArray *objects = [promise objects];
    if ([objects count])
    {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:[objects count]];
        for (IMBObject *anObject in objects)
        {
            NSURL *aURL = [promise fileURLForObject:anObject];
            [result addObject:[KSWebLocation webLocationWithURL:aURL title:[anObject name]]];
        }
        
        return result;
    }
    else
    {
        // Next comes raw data to handle dragged, linked images
        if ([self availableTypeFromArray:[NSBitmapImageRep imageTypes]])
        {
            return [NSArray arrayWithObject:self];
        }
        else
        {
            // Try to read in Web Locations
            NSArray *result = [self readWebLocations];
            if ([result count] == 0)
            {
                // Fall back to reading the pasteboard itself
                result = [NSArray arrayWithObject:self];
            }
            
            return result;
        }
    }
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
        return [NSMakeCollectable(CFURLCreateData(NULL,
                                                 (CFURLRef)[self URL],
                                                 kCFStringEncodingUTF8,
                                                 NO)) autorelease];
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
