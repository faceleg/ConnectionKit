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
#import "KTAbstractPluginDelegate.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTMediaManager.h"
#import "KTMediaContainer.h"
#import "KTPage.h"
#import "KTPersistentStoreCoordinator.h"

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
#pragma mark Class Methods

+ (void)initialize
{
	[self setKey:@"titleHTML" triggersChangeNotificationsForDependentKey:@"titleText"];
}

#pragma mark -
#pragma mark Core Data

/*!	Called when an object is done initializing; specifically, the bundle has been set.
*/
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	KTElementPlugin *plugin = [self plugin];
	
	if ( isNewlyCreatedObject )
	{
		NSString *marketingVersion = @"";
		if ([plugin bundle])
		{
			marketingVersion = [plugin marketingVersion];
		}
		if (nil == marketingVersion)
		{
			marketingVersion = @"0";		// fallback for unspecified
		}
		[self setWrappedValue:marketingVersion forKey:@"pluginVersion"];
		
		NSDictionary *localizedInfoDictionary = [[plugin bundle] localizedInfoDictionary];
        NSDictionary *initialProperties = [plugin pluginPropertyForKey:@"KTPluginInitialProperties"];
        if (nil != initialProperties)
        {
// TODO: deal with localization of initial properties
            NSEnumerator *theEnum = [initialProperties keyEnumerator];
            id key;
            
            while (nil != (key = [theEnum nextObject]) )
            {
                id value = [initialProperties objectForKey:key];
				if ([value isKindOfClass:[NSString class]])
				{
					// Try to localize the string
					NSString *localized = [localizedInfoDictionary objectForKey:key];
					if (nil != localized)
					{
						value = localized;
					}
				}
                if ([value respondsToSelector:@selector(mutableCopyWithZone:)])
                {
                    value = [[value mutableCopyWithZone:[value zone]] autorelease];
                }
				/// we can't use setWrappedValue:forKey: here as key is likely not a modeled property of self
				//[self lockPSCAndMOC];
				[self setValue:value forKey:key];
				//[self unlockPSCAndMOC];
            }
        }        
	}
	
	// Ensure our delegate is setup
	[self delegate];
}

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	[self setWrappedValue:[NSString shortUUIDString] forKey:@"uniqueID"];
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
#pragma mark Delegate / Plugin

- (id)delegate
{
	if (!myDelegate) 
	{
		// HACK: We don't want to load up the delegate during a Save As operation
        KTPersistentStoreCoordinator *PSC = (id)[[self managedObjectContext] persistentStoreCoordinator];
        if (PSC && [PSC isKindOfClass:[KTPersistentStoreCoordinator class]] && [PSC document])
        {
            Class delegateClass = [[[self plugin] bundle] principalClass];
            if (delegateClass)
            {                
                // It's possible that calling [self plugin] will have called this method again, so that we already have a delegate
                if (!myDelegate)
                {
                    myDelegate = [[delegateClass alloc] init];
                    OBASSERTSTRING(myDelegate, @"plugin delegate cannot be nil!");
                    
                    [myDelegate setDelegateOwner:self];
                    
                    
                    // Let the delegate know that it's awoken
                    if ([myDelegate respondsToSelector:@selector(awakeFromBundleAsNewlyCreatedObject:)])
                    {
                        [myDelegate awakeFromBundleAsNewlyCreatedObject:[self isTemporaryObject]];
                    }
                }
            }
        }
    }
        
	return myDelegate;
}

- (KTElementPlugin *)plugin
{
	KTElementPlugin *result = [self wrappedValueForKey:@"plugin"];
	
	if (!result)
	{
		NSString *identifier = [self valueForKey:@"pluginIdentifier"];
        if (identifier)
        {
            result = [KTElementPlugin pluginWithIdentifier:identifier];
            [self setPrimitiveValue:result forKey:@"plugin"];
        }
	}
	
	return result;
}

- (void)setPlugin:(KTAbstractElement *)plugin { OBASSERT_NOT_REACHED("Please don't call -setPlugin:"); }


- (id)valueForUndefinedKey:(NSString *)key
{
	if ([key isEqualToString:@"root"])
	{
		OBASSERT_NOT_REACHED("You should never call -root on an element.");
	}
	
	return [super valueForUndefinedKey:key];
}

/*	Whenever setting a value in the extensible properties inform our delegate if they're interested
 */
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	OBPRECONDITION(key);
    
    // Let our delegate know if possible
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(plugin:didSetValue:forPluginKey:oldValue:)])
	{
		id oldValue = [self valueForUndefinedKey:key];
		[super setValue:value forUndefinedKey:key];
		[delegate plugin:self didSetValue:value forPluginKey:key oldValue:oldValue];
	}
	else
	{
		[super setValue:value forUndefinedKey:key];
	}
}

/*	Whenver validating something, we give our delegate first crack at it if they wish
 */
- (BOOL)validateValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError
{
	BOOL result = YES;
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(validatePluginValue:forKeyPath:error:)])
	{
		result = [delegate validatePluginValue:ioValue forKeyPath:inKeyPath error:outError];
	}
	
	if (result)
	{
		result = [super validateValue:ioValue forKeyPath:inKeyPath error:outError];
	}
	
	return result;
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

- (KTDocument *)document
{
	KTDocument *result = nil;
    
    KTPersistentStoreCoordinator *PSC =
        (KTPersistentStoreCoordinator *)[[self managedObjectContext] persistentStoreCoordinator];
    if (PSC && [PSC isKindOfClass:[KTPersistentStoreCoordinator class]])
    {
        result = [PSC document];
    }
    
	return result;
}

/*	Simply pulls the value from the plugin's Info.plist
 */
- (BOOL)allowIntroduction
{
	return [[[self plugin] pluginPropertyForKey:@"KTElementAllowsIntroduction"] boolValue];
}

#pragma mark title

- (NSString *)titleHTML { return [self wrappedValueForKey:@"titleHTML"]; }

/*	Very simple accessor for setting the titleHTML. Page subclasses override this to do additional work
 */
- (void)setTitleHTML:(NSString *)value
{
	[self setWrappedValue:value forKey:@"titleHTML"];
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
	KTMediaManager *result = [[self document] mediaManager];
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
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:selector])
	{
		[delegate performSelector:selector withObject:(id)anObject withObject:page];
	}
	else if ([self respondsToSelector:selector])
	{
		[self performSelector:selector withObject:(id)anObject withObject:page];
	}
}


// Called via recursiveComponentPerformSelector
- (void)addResourcesToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	NSBundle *bundle = [[self plugin] bundle];
	NSString *resourcePath = [bundle resourcePath];
    if (resourcePath)
    {
        NSArray *resourcesNeeded = [[self plugin] pluginPropertyForKey:@"KTPluginResourcesNeeded"];
        NSEnumerator *theEnum = [resourcesNeeded objectEnumerator];
        NSString *fileName;
        
        while (nil != (fileName = [theEnum nextObject]) )
        {
            NSString *path = [resourcePath stringByAppendingPathComponent:fileName];
            OBASSERT(path);
            [aSet addObject:path];
        }
    }
}

- (void)addCSSFilePathToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	NSBundle *bundle = [[self plugin] bundle];
	
	if ( nil == bundle ) return;
	
	NSString *resourcePath = [bundle resourcePath];
	NSArray *cssFilesNeeded = [[self plugin] pluginPropertyForKey:@"KTPluginCSSFilesNeeded"];
	NSEnumerator *theEnum = [cssFilesNeeded objectEnumerator];
	NSString *fileName;
	
	while (nil != (fileName = [theEnum nextObject]) )
	{
		NSString *path = [resourcePath stringByAppendingPathComponent:fileName];
//		LOG((@"%@ adding css file:%@", [self class], path));
        OBASSERT(path);
		[aSet addObject:path];
	}
}

- (NSString *)spotlightHTML
{
	NSString *result = nil;
	
	// default implementation just calls delegate
	id delegate = [self delegate];
	if ( [delegate respondsToSelector:@selector(spotlightHTML)] )
	{
		result = [delegate spotlightHTML];
	}
	
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

/*	If we have a template use that. If not, fallback to our element's.
 */
- (NSString *)templateHTML
{
	NSString *result = [[self plugin] templateHTMLAsString];
	return result;
}

- (NSString *)cssClassName
{
	[self subclassResponsibility:_cmd];
	return nil;
}

@end

