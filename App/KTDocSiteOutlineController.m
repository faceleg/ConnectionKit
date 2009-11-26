//
//  KTDocSiteOutlineController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDocSiteOutlineController.h"
#import "SVSiteOutlineViewController.h"

#import "Debug.h"
#import "KTAbstractElement.h"
#import "KTAppDelegate.h"
#import "KTElementPlugin+DataSourceRegistration.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTHTMLInspectorController.h"
#import "KTImageTextCell.h"
#import "KTMaster.h"
#import "KTPage.h"

#import "NSAttributedString+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSString+Karelia.h"


/*	These strings are localizations for case https://karelia.fogbugz.com/default.asp?4736
 *	Not sure when we're going to have time to implement it, so strings are placed here to ensure they are localized.
 *
 *	NSLocalizedString(@"There is already a page with the file name \\U201C%@.\\U201D Do you wish to rename it to \\U201C%@?\\U201D",
					  "Alert message when changing the file name or extension of a page to match an existing file");
 *	NSLocalizedString(@"There are already some pages with the same file name as those you are adding. Do you wish to rename them to be different?",
					  "Alert message when pasting/dropping in pages whose filenames conflict");
 */


#pragma mark -


@implementation KTDocSiteOutlineController

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"selectedPages"])
	{
		return NO;
	}
	else
	{
		return [super automaticallyNotifiesObserversForKey:key];
	}
}

#pragma mark -
#pragma mark Init/Dealloc/Awake

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
	if ( nil != self )
	{
		// Prepare tree controller parameters
		[self setObjectClass:[KTPage class]];
        [self setEntityName:@"Page"];
		
		[self setAvoidsEmptySelection:NO];
		[self setPreservesSelection:YES];
		[self setSelectsInsertedObjects:NO];
	}
	
	return self;
}

#pragma mark -
#pragma mark Accessors

- (NSString *)childrenKeyPath { return @"sortedChildren"; }

#pragma mark -
#pragma mark KVC

/*	When the user customizes the filename, we want it to become fixed on their choice
 */
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
	[super setValue:value forKeyPath:keyPath];
	
	if ([keyPath isEqualToString:@"selection.fileName"])
	{
		[self setValue:[NSNumber numberWithBool:NO] forKeyPath:@"selection.shouldUpdateFileNameWhenTitleChanges"];
	}
}

@end

