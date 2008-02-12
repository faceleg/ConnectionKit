//
//  NSDocumentController+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 5/17/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSDocumentController+KTExtensions.h"

//@interface NSPersistentDocument (KTDocument)
//- (NSArray *)peerContexts;
//@end

@implementation NSDocumentController ( KTExtensions )

- (NSPersistentDocument *)documentForManagedObjectContext:(NSManagedObjectContext *)aContext
{
	NSArray *documents = [self documents];
	int i;
	
	for ( i=0; i<[documents count]; i++ )
	{
		NSPersistentDocument *document = [documents objectAtIndex:i];
		if ([[document managedObjectContext] isEqual:aContext] ||
			([document isKindOfClass:[KTDocument class]] && [[(KTDocument *)document mediaManager] managedObjectContext] == aContext))
		{
			return document;
		}
//		else if ( [[document peerContexts] containsObject:aContext] )
//		{
//			return document;
//		}
	}
	
	return nil;
}

@end
