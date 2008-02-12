//
//  KTDesign+KTTransferController.m
//  Marvel
//
//  Created by Mike on 07/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTDesign+KTTransferController.h"


@implementation KTDesign (KTTransferController)

/*	Slightly hacky method that is called by KTTransferController once the
 *	design has been published.
 *	Finds the equivalent design ManagedObject and updates the published
 *	version.
 */
- (void)didPublishInDocument:(KTDocument *)document
{
	NSManagedObjectContext *moc = [document managedObjectContext];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", [self identifier]];
	
	NSArray *designPublishingInfo = [moc objectsWithEntityName:@"DesignPublishingInfo"
													 predicate:predicate
														 error:NULL];
															
	[designPublishingInfo setValue:[self version] forKey:@"versionLastPublished"];
}

@end
