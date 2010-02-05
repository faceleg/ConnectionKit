//
//  SVPlugInContentObject.m
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugInGraphic.h"

#import "KTAbstractPluginDelegate.h"
#import "SVDOMController.h"
#import "SVElementPlugIn.h"
#import "KTElementPlugin.h"
#import "SVHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"


static NSString *sPlugInPropertiesObservationContext = @"PlugInPropertiesObservation";


@implementation SVPlugInGraphic

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
    [_plugIn removeObserver:self forKeyPaths:[[_plugIn class] plugInKeys]];
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
				
                // Send the value to the plug-in. Our KVO will persist it too if appropriate
                [[self plugIn] setSerializedValue:value forKey:key];
            }
        }        
	}
	
	// Ensure our plug-in is loaded
	[self plugIn];
}

#pragma mark Plug-in

- (SVElementPlugIn *)plugIn
{
	if (!_plugIn) 
	{
		Class <SVElementPlugInFactory> plugInFactory = [[[self plugin] bundle] principalClass];
        if (plugInFactory)
        {                
            // It's possible that calling [self plugin] will have called this method again, so that we already have a delegate
            if (!_plugIn)
            {
                // Create plug-in object
                NSDictionary *arguments = [NSDictionary dictionaryWithObject:[NSMutableDictionary dictionary] forKey:@"PropertiesStorage"];
                _plugIn = [[plugInFactory elementPlugInWithArguments:arguments] retain];
                OBASSERTSTRING(_plugIn, @"plugin delegate cannot be nil!");
                
                [_plugIn setDelegateOwner:self];
                
                // Restore plug-in's properties
                NSDictionary *plugInProperties = [self extensibleProperties];
                SVElementPlugIn *plugIn = [self plugIn];
                for (NSString *aKey in plugInProperties)
                {
                    id serializedValue = [plugInProperties objectForKey:aKey];
                    [plugIn setSerializedValue:serializedValue forKey:aKey];
                }
                
                // Observe the plug-in's properties so they can be synced back to the MOC
                [plugIn addObserver:self
                        forKeyPaths:[[plugIn class] plugInKeys]
                            options:0
                            context:sPlugInPropertiesObservationContext];
                
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

#pragma mark Plug-in settings storage

- (BOOL)usesExtensiblePropertiesForUndefinedKey:(NSString *)key
{
    NSSet *keys = [[[self plugIn] class] plugInKeys];
    BOOL result = [keys containsObject:key];
    return result;
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sPlugInPropertiesObservationContext)
    {
        // Copy serialized value to MOC
        [self setExtensibleProperty:[[self plugIn] serializedValueForKey:keyPath]
                             forKey:keyPath];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
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
    if (![result isEqualToNumber:SVContentObjectWrapNone])
    {
        result = [NSNumber numberWithBool:YES];
    }
    return result;
}

- (void)setWrapIsFloatOrBlock:(NSNumber *)useFloatOrBlock
{
    [self setWrap:useFloatOrBlock];
}

+ (NSSet *)keyPathsForValuesAffectingWrapIsFloatOrBlock
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsFloatLeft
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapFloatLeft];
    return result;
}
- (void)setWrapIsFloatLeft:(BOOL)floatLeft
{
    [self setWrap:(floatLeft ? SVContentObjectWrapFloatLeft : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsFloatLeft
{
    return [NSSet setWithObject:@"wrap"];
}
    
- (BOOL)wrapIsFloatRight
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapFloatRight];
    return result;
}
- (void)setWrapIsFloatRight:(BOOL)FloatRight
{
    [self setWrap:(FloatRight ? SVContentObjectWrapFloatRight : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsFloatRight
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsBlockLeft
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapBlockLeft];
    return result;
}
- (void)setWrapIsBlockLeft:(BOOL)BlockLeft
{
    [self setWrap:(BlockLeft ? SVContentObjectWrapBlockLeft : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsBlockLeft
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsBlockCenter
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapBlockCenter];
    return result;
}
- (void)setWrapIsBlockCenter:(BOOL)BlockCenter
{
    [self setWrap:(BlockCenter ? SVContentObjectWrapBlockCenter : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsBlockCenter
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsBlockRight
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapBlockRight];
    return result;
}
- (void)setWrapIsBlockRight:(BOOL)BlockRight
{
    [self setWrap:(BlockRight ? SVContentObjectWrapBlockRight : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsBlockRight
{
    return [NSSet setWithObject:@"wrap"];
}

#pragma mark HTML

- (NSString *)editingElementID { return [[self plugIn] elementID]; }
- (BOOL)shouldPublishEditingElementID { return YES; }

- (void)writeHTML
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    [context openTag:@"div"];
    [context writeAttribute:@"style" value:@"float:right;"];
    [context closeStartTag];
    
    [[self plugIn] writeHTML];
    
    [context writeEndTag];
}

- (DOMElement *)elementForEditingInDOMDocument:(DOMDocument *)document;
{
    // Need to use the plug-in's ID rather than our own
    OBPRECONDITION(document);
    
    DOMElement *result = [document getElementById:[[self plugIn] elementID]];
    return result;
}

- (Class)DOMControllerClass
{
    // Ask the plug-in what it would like, but don't let it chose something wacky
    Class result = [[[self plugIn] class] DOMControllerClass];
    if (![result isSubclassOfClass:[SVDOMController class]])
    {
        // TODO: Log a warning
        result = [super DOMControllerClass];
    }
    
    return result;
}

#pragma mark Deprecated

// Loads of old plug-ins rely on this property
- (id)delegate { return [self plugIn]; }

@end
