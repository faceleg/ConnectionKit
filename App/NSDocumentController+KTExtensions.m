//
//  NSDocumentController+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 5/17/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "NSDocumentController+KTExtensions.h"

#import "KTDocument.h"

//@interface NSPersistentDocument (KTDocument)
//- (NSArray *)peerContexts;
//@end

@implementation NSDocumentController ( KTExtensions )

- (NSPersistentDocument *)documentForManagedObjectContext:(NSManagedObjectContext *)aContext
{
	NSArray *documents = [self documents];
	
	for ( NSPersistentDocument *document in documents )
	{
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
