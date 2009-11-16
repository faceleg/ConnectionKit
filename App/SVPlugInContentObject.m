//
//  SVPlugInContentObject.m
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugInContentObject.h"

#import "KTAbstractPluginDelegate.h"
#import "SVElementPlugIn.h"
#import "KTElementPlugin.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSString+Karelia.h"


@implementation SVPlugInContentObject

#pragma mark Lifecycle

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:[NSString UUIDString] forKey:@"elementID"];
    [self setPrimitiveValue:@"??" forKey:@"plugInVersion"];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	[self awakeFromBundleAsNewlyCreatedObject:NO];
}

/*  Where possible (i.e. Leopard) tear down the delegate early to avoid any KVO issues.
 */
- (void)willTurnIntoFault
{
    [_plugIn setDelegateOwner:nil];
	[_plugIn release];	_plugIn = nil;
}

/*!	Called when an object is done initializing; specifically, the bundle has been set.
 */
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	KTElementPlugin *plugin = [self plugin];
	
	if ( isNewlyCreatedObject )
	{
		NSDictionary *localizedInfoDictionary = [[plugin bundle] localizedInfoDictionary];
        NSDictionary *initialProperties = [plugin pluginPropertyForKey:@"KTPluginInitialProperties"];
        if (nil != initialProperties)
        {
            // TODO: deal with localization of initial properties
            NSMutableDictionary *storage = [NSMutableDictionary dictionary];    // yes, I'm faking it for now
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
				[storage setValue:value forKey:key];
            }
        }        
	}
	
	// Ensure our plug-in is loaded
	[self plugIn];
}

#pragma mark Plug-in

- (id <SVElementPlugIn>)plugIn
{
	if (!_plugIn) 
	{
		Class <SVElementPlugInFactory> plugInFactory = [[[self plugin] bundle] principalClass];
        if (plugInFactory)
        {                
            // It's possible that calling [self plugin] will have called this method again, so that we already have a delegate
            if (!_plugIn)
            {
                _plugIn = [[plugInFactory elementPlugInWithPropertiesStorage:[NSMutableDictionary dictionary]] retain];
                OBASSERTSTRING(_plugIn, @"plugin delegate cannot be nil!");
                
                [_plugIn setDelegateOwner:self];
                
                
                // Let the delegate know that it's awoken
                if ([_plugIn respondsToSelector:@selector(awakeFromBundleAsNewlyCreatedObject:)])
                {
                    [_plugIn awakeFromBundleAsNewlyCreatedObject:[self isInserted]];
                }
            }
        }
    }
    
	return _plugIn;
}

- (KTElementPlugin *)plugin
{
	KTElementPlugin *result = [self wrappedValueForKey:@"plugin"];
	
	if (!result)
	{
		NSString *identifier = [self valueForKey:@"plugInIdentifier"];
        if (identifier)
        {
            result = [KTElementPlugin pluginWithIdentifier:identifier];
            [self setPrimitiveValue:result forKey:@"plugin"];
        }
	}
	
	return result;
}

@dynamic plugInIdentifier;

/*	Whenever setting a value in the extensible properties inform our delegate if they're interested
 */
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	OBPRECONDITION(key);
    
    // Let our delegate know if possible
	id delegate = [self plugIn];
	if (delegate && [delegate respondsToSelector:@selector(plugin:didSetValue:forPluginKey:oldValue:)])
	{
		id oldValue = [self valueForUndefinedKey:key];
		[super setValue:value forUndefinedKey:key];
		[delegate plugin:(id)self didSetValue:value forPluginKey:key oldValue:oldValue];
	}
	else
	{
		[super setValue:value forUndefinedKey:key];
	}
}

/*	Whenever validating something, we give our delegate first crack at it if they wish
 */
- (BOOL)validateValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError
{
	BOOL result = YES;
	
	id delegate = [self plugIn];
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

#pragma mark Placement

@dynamic wrap;
- (BOOL)validateWrap:(SVContentObjectWrap **)wrap error:(NSError **)error
{
    BOOL result = YES;
    // FIXME: ensure it's one of the allowed values
    return result;
}

- (NSNumber *)wrapIsFloatOrBlock
{
    NSNumber *result = [self wrap];
    if ([result intValue] > 1) result = [NSNumber numberWithBool:YES];
    return result;
}

- (void)setWrapIsFloatOrBlock:(NSNumber *)useFloatOrBlock
{
    
}

- (NSSet *)keyPathsForValuesAffectingWrapIsFloatOrBlock
{
    return [NSSet setWithObject:@"wrap"];
}

#pragma mark HTML

- (NSString *)HTMLString;
{
    return [[self plugIn] HTMLString];
}

- (DOMElement *)DOMElementInDocument:(DOMDocument *)document;
{
    // Need to use the plug-in's ID rather than our own
    OBPRECONDITION(document);
    
    DOMElement *result = [document getElementById:[[self plugIn] elementID]];
    return result;
}

#pragma mark Deprecated

// Loads of old plug-ins rely on this property
- (id)delegate { return [self plugIn]; }

@end
