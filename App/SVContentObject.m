// 
//  SVContentObject.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "KTAbstractElement.h"
#import "KTAbstractPluginDelegate.h"
#import "KTElementPlugin.h"
#import "SVHTMLTemplateParser.h"
#import "SVPageletBody.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSString+Karelia.h"


@implementation SVContentObject 

#pragma mark Lifecycle

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
    [_delegate setDelegateOwner:nil];
	[_delegate release];	_delegate = nil;
}

#pragma mark Plug-in

- (id)delegate
{
	if (!_delegate) 
	{
		Class delegateClass = [[[self plugin] bundle] principalClass];
        if (delegateClass)
        {                
            // It's possible that calling [self plugin] will have called this method again, so that we already have a delegate
            if (!_delegate)
            {
                _delegate = [[delegateClass alloc] init];
                OBASSERTSTRING(_delegate, @"plugin delegate cannot be nil!");
                
                [_delegate setDelegateOwner:self];
                
                
                // Let the delegate know that it's awoken
                if ([_delegate respondsToSelector:@selector(awakeFromBundleAsNewlyCreatedObject:)])
                {
                    [_delegate awakeFromBundleAsNewlyCreatedObject:[self isInserted]];
                }
            }
        }
    }
    
	return _delegate;
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
		[delegate plugin:(id)self didSetValue:value forPluginKey:key oldValue:oldValue];
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


#pragma mark Accessors

@dynamic plugInIdentifier;
@dynamic container;

#pragma mark HTML

@dynamic elementID;

- (NSString *)HTMLString;
{
    // For now, just parse the template
    NSString *template = [[self plugin] templateHTMLAsString];
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:template
                                                                        component:self];
    
    NSString *result = [parser parseTemplate];
    [parser release];
    
    return result;
}

- (NSString *)archiveHTMLString;
{
    NSString *result = [NSString stringWithFormat:@"<object id=\"%@\" />", [self elementID]];
    return result;
}

@end
