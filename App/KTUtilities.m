//
//  KTUtilities.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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
#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSError+Karelia.h"
#import "NSException+Karelia.h"
#import "NSManagedObjectModel+KTExtensions.h"
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
	NSManagedObjectContext *result = [[NSManagedObjectContext alloc] init];
	[result setPersistentStoreCoordinator:coordinator];
	
	[coordinator release];
	
	return [result autorelease];	
}

@end

