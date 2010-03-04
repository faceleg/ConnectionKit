//
//  KTMediaManager2.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaManager.h"
#import "KTMediaManager.h"

#import "KT.h"
#import "KTDocument.h"
#import "KTMediaFile.h"
#import "KTMediaContainer.h"
#import "KTSite.h"

#import "NSApplication+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSURL+Karelia.h"

#import <Connection/KTLog.h>
#import "BDAlias.h"

#import "Debug.h"


NSString *KTMediaLogDomain = @"Media";


@implementation KTMediaManager

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithDocument:(KTDocument *)document
{
	[super init];
	
	_document = document;	// Weak ref
	
    return self;
}

- (void)dealloc
{
    [myMediaContainerIdentifiersCache release];
	
	[super dealloc];
}

#pragma mark Accessors

- (KTDocument *)document { return _document; }

#pragma mark Missing media

- (NSSet *)missingMediaFiles
{
	NSMutableSet *result = [NSMutableSet set];
    return result;
    
    
    
    
	
	NSEnumerator *mediaFileEnumerator = [[self externalMediaFiles] objectEnumerator];
	KTMediaFile *aMediaFile;
	
	while (aMediaFile = [mediaFileEnumerator nextObject])
	{
		NSString *path = [aMediaFile currentPath];
		if (!path ||
            [path isEqualToString:@""] ||
            [path isEqualToString:[[NSBundle mainBundle] pathForImageResource:@"qmark"]] ||
            ![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			if ([(NSSet *)[aMediaFile valueForKey:@"containers"] count] > 0)
            {
                [result addObject:aMediaFile];
            }
		}
	}
	
	return result;
}

#pragma mark Errors

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	KTLog(KTMediaLogDomain, KTLogError, ([NSString stringWithFormat:@"Caught file manager error:\n%@", errorInfo]));
	return NO;
}

@end
