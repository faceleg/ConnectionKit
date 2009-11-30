//
//  KTAbstractElement.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "KTAbstractElement.h"

#import "Debug.h"
#import "KT.h"
#import "KTAbstractElement+Internal.h"
#import "KTDocument.h"
#import "KTMediaManager.h"
#import "KTMediaContainer.h"
#import "KTPage.h"

#import "NSBundle+KTExtensions.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+Karelia.h"


@implementation KTAbstractElement

#pragma mark -
#pragma mark Core Data

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	[self setPrimitiveValue:[NSString shortUUIDString] forKey:@"uniqueID"];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	[self awakeFromBundleAsNewlyCreatedObject:NO];
}

/*!	Called after all the other awake messages, to populate from a drag.  Handles calling the delegate.
*/
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary;
{
    if ([[self delegate] respondsToSelector:@selector(awakeFromDragWithDictionary:)])
	{
		[[self delegate] awakeFromDragWithDictionary:aDictionary];
	}
}

/*  Where possible (i.e. Leopard) tear down the delegate early to avoid any KVO issues.
 */
- (void)willTurnIntoFault
{
    [myDelegate setDelegateOwner:nil];
	[myDelegate release];	myDelegate = nil;
}

- (void)didTurnIntoFault
{
	// Dispose of delegate
	[myDelegate setDelegateOwner:nil];
	[myDelegate release];	myDelegate = nil;
	
	
	[super didTurnIntoFault];
}

#pragma mark -
#pragma mark Accessors

- (KTPage *)page
{
	[self subclassResponsibility:_cmd];
	return nil;
}

- (NSString *)uniqueID 
{
	NSString *result = [self wrappedValueForKey:@"uniqueID"];
	return result;
}

#pragma mark title

- (NSString *)titleHTML { return [self wrappedValueForKey:@"titleHTML"]; }

/*	Very simple accessor for setting the titleHTML. Page subclasses override this to do additional work
 */
- (void)setTitleHTML:(NSString *)value
{
	[self setWrappedValue:value forKey:@"titleHTML"];
}

+ (NSSet *)keyPathsForValuesAffectingTitleText
{
    return [NSSet setWithObject:@"titleHTML"];
}

- (NSString *)titleText	// get title, but without attributes
{
	NSString *html = [self titleHTML];
	NSString *result = [html stringByConvertingHTMLToPlainText];
	return result;
}

- (void)setTitleText:(NSString *)value
{
	[self setTitleHTML:[value stringByEscapingHTMLEntities]];
}

#pragma mark -
#pragma mark Media

- (KTMediaManager *)mediaManager
{
	KTMediaManager *result = [[[[self page] site] document] mediaManager];
	return result;
}

/*	By default we require no media so just ask delegate for anything
 */
- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet set];
    
    [result unionSet:[KTMediaContainer mediaContainerIdentifiersInHTML:[self valueForKey:@"introductionHTML"]]];
	
	if ([[self delegate] respondsToSelector:@selector(requiredMediaIdentifiers)])
	{
		NSSet *delegateMedia = [[self delegate] performSelector:@selector(requiredMediaIdentifiers)];
        if (delegateMedia) [result unionSet:delegateMedia];
	}
	
	return result;
}

#pragma mark -
#pragma mark Support

/*	As the title suggests, performs the selector upon either self or the delegate. Delegate takes preference.
 *	At present the recursive flag is only used by pages.
 */
- (void)makeSelfOrDelegatePerformSelector:(SEL)selector
							   withObject:(void *)anObject
								 withPage:(KTPage *)page
								recursive:(BOOL)recursive
{
	if ([self isDeleted])
	{
		return; // stop these calls if we're not really there any more
	}
	
	if ([self respondsToSelector:selector])
	{
		[self performSelector:selector withObject:(id)anObject withObject:page];
	}
}


- (NSString *)spotlightHTML
{
	NSString *result = nil;
	
	// TODO: Figure a nice way to get reasonable plain text out of our body
	if ( nil == result )
	{
		result = @"";
	}
		
	return result;
}

#pragma mark -
#pragma mark HTML

- (NSString *)elementTemplate;	// instance method too for key paths to work in tiger
{
	static NSString *result;
	
	if (!result)
	{
		NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"KTElementTemplate" ofType:@"html"];
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
}

- (NSString *)commentsTemplate	// instance method too for key paths to work in tiger
{
	static NSString *result;
	
	if (!result)
	{
		NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"KTCommentsTemplate" ofType:@"html"];
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
}

- (NSString *)cssClassName
{
	[self subclassResponsibility:_cmd];
	return nil;
}

@end

