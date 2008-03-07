//
//  KTUtilities.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Miscellaneous utility functions:
 Plugin utilities
 Unique MAC address to identify this computer
 
 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x
 
 IMPLEMENTATION NOTES & CAUTIONS:
	x
 
 TO DO:
	???? Should the plugin stuff be moved to the bundle manager?
 
 */

#import "KTUtilities.h"


#import "Debug.h"
#import "KT.h"
#import "KTAbstractElement.h"		// for the benefit of L'izedStringInKTComponents macro
#import "KTAbstractHTMLPlugin.h"
#import "KTManagedObjectContext.h"
#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSError+Karelia.h"
#import "NSException+Karelia.h"
#import "NSString+Karelia.h"
#import <Carbon/Carbon.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/network/IOEthernetController.h>
#import <IOKit/network/IOEthernetInterface.h>
#import <IOKit/network/IONetworkInterface.h>
#import <Security/Security.h>



@implementation KTUtilities

	
#pragma mark Core Data

/*! returns an autoreleased core data stack with file at aStoreURL */
+ (NSManagedObjectContext *)contextWithURL:(NSURL *)aStoreURL model:(NSManagedObjectModel *)aModel
{
	NSError *localError = nil;
	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:aModel];
	id store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
										 configuration:nil
												   URL:aStoreURL
											   options:nil
												 error:&localError];
	
	if ( nil == store )
	{
		[coordinator release];
		if ( nil != localError )
		{
			[[NSDocumentController sharedDocumentController] presentError:localError];
		}
		else
		{
			[NSException raise:kKareliaDocumentException 
						format:@"Unable create context from %@", aStoreURL];
		}
		return nil;
	}
	
	//==//NSManagedObjectContext *result = [[NSManagedObjectContext alloc] init];
	KTManagedObjectContext *result = [[KTManagedObjectContext alloc] init];
	[result setPersistentStoreCoordinator:coordinator];
	
	[coordinator release];
	
	return [result autorelease];	
}

/*! returns an autoreleaed model from KTComponents_aVersion.mom */
+ (NSManagedObjectModel *)modelWithVersion:(NSString *)aVersion
{
	// passing in nil for aVersion will return the standard KTComponents model
	
	NSString *resourceName = @"KTComponents";
	if ( nil != aVersion )
	{
		resourceName = [resourceName stringByAppendingString:[NSString stringWithFormat:@"_%@", aVersion]];
	}
	NSString *resourceNameWithExtension = [resourceName stringByAppendingPathExtension:@"mom"];
	
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForResource:resourceName
									  ofType:@"mom"];
								 //inDirectory:@"Models"];
	NSURL *modelURL = [NSURL fileURLWithPath:path];
	
	if ( nil == modelURL )
	{
		[NSException raise:kKareliaDocumentException 
					format:@"Unable to locate %@", resourceNameWithExtension];
		return nil;
	}
	
	NSManagedObjectModel *result = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	
	if ( nil == result )
	{
		[NSException raise:kKareliaDocumentException 
					format:@"Unable create model from %@", resourceNameWithExtension];
		return nil;
	}
	
	return [result autorelease];
}

/*! returns an autoreleaed model from KTComponents_aVersion.mom with all
	Class references set to NSManagedObject, except Storage classes
*/
+ (NSManagedObjectModel *)genericModelWithVersion:(NSString *)aVersion
{
	NSManagedObjectModel *model = [self modelWithVersion:aVersion];
	[model retain];
	
	if ( nil != model )
	{
		NSEnumerator *e = [[model entities] objectEnumerator];
		NSEntityDescription *entity = nil;
		while ( entity = [e nextObject] )
		{
			//FIXME: these classes no longer exist, is this method still required?
			if ( ![[entity managedObjectClassName] isEqualToString:@"KTStoredDictionary"] 
				 && ![[entity managedObjectClassName] isEqualToString:@"KTStoredArray"]
				 && ![[entity managedObjectClassName] isEqualToString:@"KTStoredSet"] )
			[entity setManagedObjectClassName:[NSManagedObject className]];
		}
	}
	
	return [model autorelease];
}


#pragma mark File Management

// NOTE: For Leopard, we can use:  - (BOOL)createDirectoryAtPath:(NSString *)pathwithIntermediateDirectories:(BOOL)createIntermediatesattributes:(NSDictionary *)attributeserror:(NSError **)error

+ (BOOL)createPathIfNecessary:(NSString *)storeDirectory error:(NSError **)outError
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    BOOL success = NO;
    
    int i, c;
    NSArray *components = [storeDirectory pathComponents];
    NSString *current = @"";
    c = [components count];  
    for ( i = 0; i < c; i++ ) 
	{
        NSString *anIndex = [components objectAtIndex:i];
        NSString *next = [current stringByAppendingPathComponent:anIndex];
        current = next;
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:next] ) 
		{
            success = [defaultManager createDirectoryAtPath:next attributes:nil];
            if ( !success ) 
			{
				NSString *errorDescription = [NSString stringWithFormat:NSLocalizedString(@"Unable to create directory at path (%@).",@"Error: Unable to create directory at path (%@)."), next];
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
												code:NSFileWriteUnknownError
								localizedDescription:errorDescription];
                return NO;
            }
        } 
    }
    
    return YES;
}

@end

