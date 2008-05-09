//
//  KTAbstractElement.m
//  KTComponents
//
//  Copyright (c) 2004-2006 Karelia Software. All rights reserved.
//

#import "KTAbstractElement.h"

#import "Debug.h"
#import "KT.h"
#import "KTAbstractPluginDelegate.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTExtensiblePluginPropertiesArchivedObject.h"
#import "KTMediaManager.h"
#import "KTPage.h"
#import "NSBundle+KTExtensions.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSMutableSet+Karelia.h"
#import "NSObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+Karelia.h"


@interface NSObject ( delegateMethods )
- (void)awakenedDidTurnIntoFaultSupport;
@end


@interface NSDocumentController ( MarvelHack )
- (KTDocument *)lastSavedDocument;
@end


#pragma mark -


@implementation KTAbstractElement

#pragma mark -
#pragma mark Core Data

/*!	Called when an object is done initializing; specifically, the bundle has been set.
*/
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	KTElementPlugin *plugin = [self plugin];
	
	if ( isNewlyCreatedObject )
	{
		NSString *version = @"";
		if ([plugin bundle])
		{
			version = [plugin version];
		}
		if (nil == version)
		{
			version = @"0";		// fallback for unspecified
		}
		[self setWrappedValue:version forKey:@"pluginVersion"];
		
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
				[self lockPSCAndMOC];
				[self setValue:value forKey:key];
				[self unlockPSCAndMOC];
            }
        }        
	}
	
	// Ensure our delegate is setup
	//[[[self document] pluginDelegatesManager] delegateForPlugin:self];
}

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	[self setWrappedValue:[NSString shortGUIDString] forKey:@"uniqueID"];
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

- (void)didTurnIntoFault
{
	// Call the support method to do deallocation only for properties initialized from the awake.
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(awakenedDidTurnIntoFaultSupport)] )
	{
		[delegate awakenedDidTurnIntoFaultSupport];
	}
	
	
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
		Class delegateClass = [[[self plugin] bundle] principalClass];
		if (delegateClass)
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
	
	return myDelegate;
}

- (KTElementPlugin *)plugin
{
	KTElementPlugin *result = [self wrappedValueForKey:@"plugin"];
	
	if (!result)
	{
		result = [KTElementPlugin pluginWithIdentifier:[self valueForKey:@"pluginIdentifier"]];
		[self setPrimitiveValue:result forKey:@"plugin"];
	}
	
	return result;
}

- (void)setPlugin:(KTAbstractElement *)plugin { OBASSERT_NOT_REACHED("Please don't call -setPlugin:"); }

/*	Whenever setting a value in the extensible properties inform our delegate if they're interested
 */
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
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
#pragma mark Plugin Properties

/*	These 2 methods allow us to store and retrieve managed object even though they dont't conform to <NSCoding>
 *	Instead though they must conform to the KTArchivableManagedObject protocol
 */
- (NSDictionary *)unarchiveExtensibleProperties:(NSData *)propertiesData
{
	NSDictionary *result = [super unarchiveExtensibleProperties:propertiesData];
	
	// Go through all dictionary entries and swap any KTArchivedManagedObjects for the real thing
	NSEnumerator *keysEnumerator= [[NSDictionary dictionaryWithDictionary:result] keyEnumerator];
	NSString *aKey;
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [result objectForKey:aKey];
		if ([anObject isKindOfClass:[KTExtensiblePluginPropertiesArchivedObject class]])
		{
			KTExtensiblePluginPropertiesArchivedObject *archivedObject = (KTExtensiblePluginPropertiesArchivedObject *)anObject;
			NSManagedObject *realObject = [archivedObject realObjectInDocument:[self document]];
			[result setValue:realObject forKey:aKey];
		}
	}
	
	return result;
}

- (NSData *)archiveExtensibleProperties:(NSDictionary *)properties
{
	// Replace any managed objects conforming to KTArchivableManagedObject with KTArchivedManagedObject
	NSMutableDictionary *correctedProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
	NSEnumerator *keysEnumerator = [properties keyEnumerator];
	NSString *aKey;
	
	while (aKey = [keysEnumerator nextObject])
	{
		id anObject = [properties objectForKey:aKey];
		if ([anObject isKindOfClass:[NSManagedObject class]] &&
			[anObject conformsToProtocol:@protocol(KTExtensiblePluginPropertiesArchiving)])
		{
			KTExtensiblePluginPropertiesArchivedObject *archivedObject =
			 [[[KTExtensiblePluginPropertiesArchivedObject alloc] initWithObject:anObject] autorelease];
			
			[correctedProperties setValue:archivedObject forKey:aKey];
		}
	}
	
	NSData *result = [super archiveExtensibleProperties:correctedProperties];
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

// if we're saving as, document will always be nil, even for root
- (KTDocument *)document
{
	return [[self page] document];
}

- (NSUndoManager *)undoManager { return [[self managedObjectContext] undoManager]; }

/*	Simply pulls the value from the plugin's Info.plist
 */
- (BOOL)allowIntroduction
{
	return [[[self plugin] pluginPropertyForKey:@"KTElementAllowsIntroduction"] boolValue];
}

#pragma mark -
#pragma mark Media

- (KTMediaManager *)mediaManager
{
	return [[[self managedObjectContext] document] mediaManager];
}

/*	By default we require no media so just ask delegate for anything
 */
- (NSSet *)requiredMediaIdentifiers
{
	NSSet *result = nil;
	
	if ([[self delegate] respondsToSelector:@selector(requiredMediaIdentifiers)])
	{
		result = [[self delegate] performSelector:@selector(requiredMediaIdentifiers)];
	}
	
	return result;
}

#pragma mark -
#pragma mark Inspector

/*	For all of these methods if we have no Inspector nib, then instead point to the main
 *	element's nib.
 */
- (id)inspectorObject { return self; }

- (NSBundle *)inspectorNibBundle
{
	NSBundle *result = [[self plugin] bundle];
	return result;
}

- (NSString *)inspectorNibName
{
	NSString *key = @"KTPluginNibFile";
	if ([self isKindOfClass:[KTPage class]])
	{
		key = @"KTPageNibFile";
	}
	
	NSString *result = [[self plugin] pluginPropertyForKey:key];
	return result;
}

- (id)inspectorNibOwner
{
	id result = self;
	if ([result delegate])
	{
		result = [result delegate];
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
	NSArray *resourcesNeeded = [[self plugin] pluginPropertyForKey:@"KTPluginResourcesNeeded"];
	NSEnumerator *theEnum = [resourcesNeeded objectEnumerator];
	NSString *fileName;
	
	while (nil != (fileName = [theEnum nextObject]) )
	{
		NSString *path = [resourcePath stringByAppendingPathComponent:fileName];
		OFF((@"%@ adding resource:%@", [self class], path));
		[aSet addObject:path];
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

