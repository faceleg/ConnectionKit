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
- (void)setPlugIn:(NSObject <SVPlugIn> *)plugIn useSerializedProperties:(BOOL)serialize;
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

+ (SVPlugInGraphic *)insertNewGraphicWithPlugIn:(id <SVPlugIn>)plugIn
                         inManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPlugInGraphic *result =
    [NSEntityDescription insertNewObjectForEntityForName:@"PlugInPagelet"    
                                  inManagedObjectContext:context];
    
    [result setValue:[[plugIn class] plugInIdentifier] forKey:@"plugInIdentifier"];
    
    
    [result setPlugIn:plugIn useSerializedProperties:YES];  // pasing YES to copy the current properties out of the plug-in
    
    
    return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:@"??" forKey:@"plugInVersion"];
}

- (void)awakeFromInsertIntoPage:(KTPage *)page;
{
    [[self plugIn] awakeFromInsert];
    [super awakeFromInsertIntoPage:page];
}

- (void)awakeFromExtensiblePropertyUndoUpdateForKey:(NSString *)key;
{
    [super awakeFromExtensiblePropertyUndoUpdateForKey:key];
    
    // Need to pass the change onto our plug-in
    id value = [self extensiblePropertyForKey:key];
    [[self plugIn] setSerializedValue:value forKey:key];
}

- (void)didAddToPage:(id <SVPage>)page;
{
    [super didAddToPage:page];
    [[self plugIn] didAddToPage:page];
}

/*  Where possible (i.e. Leopard) tear down the delegate early to avoid any KVO issues.
 */
- (void)willTurnIntoFault
{
    [_plugIn removeObserver:self forKeyPaths:[[_plugIn class] plugInKeys]];
    [_plugIn setContainer:nil];
	[_plugIn release];	_plugIn = nil;
}

#pragma mark Plug-in

- (NSObject <SVPlugIn> *)plugIn
{
	if (!_plugIn && [self plugInIdentifier])    // during undo/redo, plugInIdentifier may not have been set up yet
	{
		[self loadPlugIn];
        
        // Let the plug-in know that it's awoken
        [[self plugIn] awakeFromFetch];
    }
    
	return _plugIn;
}

- (void)setPlugIn:(NSObject <SVPlugIn> *)plugIn useSerializedProperties:(BOOL)serialize;
{
    OBASSERT(!_plugIn);
    _plugIn = [plugIn retain];
               
    
    [plugIn setContainer:self];
    
    // Observe the plug-in's properties so they can be synced back to the MOC
    [plugIn addObserver:self
            forKeyPaths:[[plugIn class] plugInKeys]
                options:(serialize ? NSKeyValueObservingOptionInitial : 0)
                context:sPlugInPropertiesObservationContext];
}

- (void)loadPlugIn;
{
    Class plugInClass = [[[self plugInWrapper] bundle] principalClass];
    if (plugInClass)
    {                
        OBASSERT(!_plugIn);
        
        // Create plug-in object
        NSObject <SVPlugIn> *plugIn = [[plugInClass alloc] init];
        OBASSERTSTRING(plugIn, @"plug-in cannot be nil!");
        
        // Restore plug-in's properties
        NSDictionary *plugInProperties = [self extensibleProperties];
        @try
        {
            for (NSString *aKey in plugInProperties)
            {
                id serializedValue = [plugInProperties objectForKey:aKey];
                [plugIn setSerializedValue:serializedValue forKey:aKey];
            }
        }
        @catch (NSException *exception)
        {
            // TODO: Log warning
        }
        
        [self setPlugIn:plugIn useSerializedProperties:NO];
        [plugIn release];
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

- (void)writeBody:(SVHTMLContext *)context
{
    NSString *identifier = [self plugInIdentifier];
    
    NSUInteger level = [context currentHeaderLevel];
    [context setCurrentHeaderLevel:4];
    
    [context writeComment:[NSString stringWithFormat:@" %@ ", identifier]];
    
    @try
    {
        [[self plugIn] writeHTML:context];
    }
    @catch (NSException *exception)
    {
        // TODO: Log or report exception
    }
    
    [context writeComment:[NSString stringWithFormat:@" /%@ ", identifier]];
    
    [context setCurrentHeaderLevel:level];
}

#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail;
{
    return [[self plugIn] thumbnail];
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Put plug-in properties in their own dict
    [propertyList setObject:[self extensibleProperties] forKey:@"plugInProperties"];
}

@end
