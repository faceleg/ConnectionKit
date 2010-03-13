//
//  SVPlugInGraphic.m
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugInGraphic.h"

#import "SVDOMController.h"
#import "SVPageletPlugIn.h"
#import "KTElementPlugInWrapper.h"
#import "SVHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"


static NSString *sPlugInPropertiesObservationContext = @"PlugInPropertiesObservation";


@interface SVPlugInGraphic ()
- (void)loadPlugIn;
@end


#pragma mark -


@implementation SVPlugInGraphic

#pragma mark Lifecycle

+ (SVPlugInGraphic *)insertNewGraphicWithPlugInIdentifier:(NSString *)identifier
                                   inManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPlugInGraphic *result =
    [NSEntityDescription insertNewObjectForEntityForName:@"PlugInPagelet"    
                                  inManagedObjectContext:context];
    
    [result setValue:identifier forKey:@"plugInIdentifier"];
    [result loadPlugIn];
    
    return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:@"??" forKey:@"plugInVersion"];
}

/*  Where possible (i.e. Leopard) tear down the delegate early to avoid any KVO issues.
 */
- (void)willTurnIntoFault
{
    [_plugIn removeObserver:self forKeyPaths:[[_plugIn class] plugInKeys]];
    [_plugIn setDelegateOwner:nil];
	[_plugIn release];	_plugIn = nil;
}

#pragma mark Plug-in

- (NSObject <SVPageletPlugIn> *)plugIn
{
	if (!_plugIn) 
	{
		[self loadPlugIn];
        
        // Let the plug-in know that it's awoken
        [[self plugIn] awakeFromFetch];
    }
    
	return _plugIn;
}

- (void)loadPlugIn;
{
    Class <SVPageletPlugInFactory> plugInFactory = [[[self plugInWrapper] bundle] principalClass];
    if (plugInFactory)
    {                
        OBASSERT(!_plugIn);
        
        // Create plug-in object
        NSDictionary *arguments = [NSDictionary dictionaryWithObject:[NSMutableDictionary dictionary] forKey:@"PropertiesStorage"];
        _plugIn = [plugInFactory newPlugInWithArguments:arguments];
        OBASSERTSTRING(_plugIn, @"plugin delegate cannot be nil!");
        
        [_plugIn setDelegateOwner:self];
        
        // Restore plug-in's properties
        NSDictionary *plugInProperties = [self extensibleProperties];
        NSObject <SVPageletPlugIn> *plugIn = [self plugIn];
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
    }
}

- (KTElementPlugInWrapper *)plugInWrapper
{
	KTElementPlugInWrapper *result = [self wrappedValueForKey:@"plugin"];
	
	if (!result)
	{
		NSString *identifier = [self valueForKey:@"plugInIdentifier"];
        if (identifier)
        {
            result = [KTElementPlugInWrapper pluginWithIdentifier:identifier];
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

#pragma mark HTML

- (void)writeBody
{
    NSString *identifier = [self plugInIdentifier];
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    NSUInteger level = [context currentHeaderLevel];
    [context setCurrentHeaderLevel:4];
    
    [context writeComment:[NSString stringWithFormat:@" %@ ", identifier]];
    [[self plugIn] writeHTML];
    [context writeComment:[NSString stringWithFormat:@" /%@ ", identifier]];
    
    [context setCurrentHeaderLevel:level];
}

- (Class)DOMControllerClass
{
    // Ask the plug-in what it would like, but don't let it chose something wacky
    Class result = [[[self plugIn] class] DOMControllerClass];
    if (![result isSubclassOfClass:[super DOMControllerClass]])
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
