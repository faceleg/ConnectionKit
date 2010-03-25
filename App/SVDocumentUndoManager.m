//
//  SVDocumentUndoManager.m
//  Sandvox
//
//  Created by Mike on 25/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDocumentUndoManager.h"

#import "NSApplication+Karelia.h"       // Karelia Cocoa additions
#import "NSURL+Karelia.h"


@implementation NSUndoManager (SVDeletedMedia)

- (NSURL *)deletedMediaDirectory; { return nil; }

- (BOOL)haveCreatedDeletedMediaDirectory; { return NO; }

- (BOOL)removeDeletedMediaDirectory:(NSError **)error; // returns YES if directory was never created
{
    return YES;
}

@end


#pragma mark -


@implementation SVDocumentUndoManager

- (void)dealloc
{
    if (![self removeDeletedMediaDirectory:NULL])
    {
        [_deletedMediaDirectory release];
    }
    
    [super dealloc];
}

#pragma mark Deleted Media

- (NSURL *)deletedMediaDirectory;
{	
    if (!_deletedMediaDirectory)
    {
        // Figure out location
        NSURL *sandvoxSupportDirectory = [NSURL fileURLWithPath:[NSApplication applicationSupportPath]
                                                    isDirectory:YES];
        
        NSURL *allDeletedMediaDirectory = [sandvoxSupportDirectory URLByAppendingPathComponent:@"Deleted Media"
                                                                                   isDirectory:YES];
        
        NSString *deletedMediaDirectoryName = [[NSProcessInfo processInfo] globallyUniqueString];
        
        _deletedMediaDirectory = [[allDeletedMediaDirectory
                                   URLByAppendingPathComponent:deletedMediaDirectoryName
                                   isDirectory:YES] copy];
        
        
        // Create the directory if needs be
        [[NSFileManager defaultManager] createDirectoryAtPath:[_deletedMediaDirectory path]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    
    
	OBPOSTCONDITION(_deletedMediaDirectory);
	return _deletedMediaDirectory;
}

- (BOOL)haveCreatedDeletedMediaDirectory;
{
    return (_deletedMediaDirectory != nil);
}

- (BOOL)removeDeletedMediaDirectory:(NSError **)error; // returns YES if directory was never created
{
    BOOL result = YES;
    
    if ([self haveCreatedDeletedMediaDirectory])
    {
        result = [[NSFileManager defaultManager]
                  removeItemAtPath:[[self deletedMediaDirectory] path]
                  error:error];
        
        if (result) 
        {
            [_deletedMediaDirectory release]; _deletedMediaDirectory = nil;
        }
    }
	
    return result;
}

#pragma mark Action Identifier

- (unsigned short)lastRegisteredActionIdentifier;
{
    return _lastRegisteredActionIdentifier;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    _lastRegisteredActionIdentifier++;
    return [super forwardInvocation:anInvocation];
}

- (void)registerUndoWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject
{
    _lastRegisteredActionIdentifier++;
    return [super registerUndoWithTarget:target selector:aSelector object:anObject];
}

- (void)undoNestedGroup
{
    _lastRegisteredActionIdentifier++;
    return [super undoNestedGroup];
}

- (void)redo
{
    _lastRegisteredActionIdentifier++;
    return [super redo];
}

@end
