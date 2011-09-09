//
//  SVPlugInGraphic.m
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVPlugInGraphic.h"

#import "Sandvox.h"

#import "SVGraphicFactory.h"
#import "SVHTMLContext.h"
#import "SVIndexDOMController.h"
#import "SVLogoImage.h"
#import "SVMediaProtocol.h"
#import "KTPage.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"


static NSString *sPlugInPropertiesObservationContext = @"PlugInPropertiesObservation";
static void *sPlugInMinWidthObservationContext = &sPlugInMinWidthObservationContext;


@interface SVPlugInGraphic ()
@property(nonatomic, retain) SVPlugIn *primitivePlugIn;
- (void)setPlugIn:(SVPlugIn *)plugIn useSerializedProperties:(BOOL)serialize;
@end


#pragma mark -


@implementation SVPlugInGraphic

#pragma mark Lifecycle

+ (SVPlugInGraphic *)insertNewGraphicWithPlugInIdentifier:(NSString *)identifier
                                   inManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPlugInGraphic *result =
    [NSEntityDescription insertNewObjectForEntityForName:@"PlugInGraphic"    
                                  inManagedObjectContext:context];
    
    [result setValue:identifier forKey:@"plugInIdentifier"];
    [result loadPlugInAsNew:YES];
    
    return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    if ([[[self entity] attributesByName] objectForKey:@"plugInVersion"])
    {
        [self setPrimitiveValue:@"??" forKey:@"plugInVersion"];
    }
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    
    [self loadPlugInAsNew:NO];
    [[self plugIn] awakeFromFetch];
}

- (void)awakeFromNew;
{
    [[self plugIn] awakeFromNew];
    
    
    // Size
    [self makeOriginalSize];
}

- (void)awakeFromExtensiblePropertyUndoUpdateForKey:(NSString *)key;
{
    [super awakeFromExtensiblePropertyUndoUpdateForKey:key];
    
    // Need to pass the change onto our plug-in
    SVPlugIn *plugIn = [self plugIn];
    if ([[[plugIn class] plugInKeys] containsObject:key])
    {
        id value = [self extensiblePropertyForKey:key];
        [plugIn setSerializedValue:value forKey:key];
    }
}

- (void)pageDidChange:(id <SVPage>)page;
{
    [super pageDidChange:page];
    
    
    // Size to fit…
    NSNumber *width = [self width];
    if (width)
    {
        // …but only if actually appearing somewhere!
        if ([self textAttachment] ||
            [self isKindOfClass:[SVLogoImage class]] ||
            [[self sidebars] count])
        {
            NSUInteger maxWidth = [self maxWidthOnPage:page];
            
            NSUInteger elementWidth = [width unsignedIntegerValue] + [[[self plugIn] elementWidthPadding] unsignedIntegerValue];
            if (elementWidth > maxWidth)
            {
                maxWidth = MAX(maxWidth, [self minWidth]);
                [self setContentWidth:[NSNumber numberWithUnsignedInteger:maxWidth]];
            }
        }
    }
    
    NSNumber *height = [self height];
    NSUInteger maxHeight = [[self maxHeight] unsignedIntegerValue];
    if (height && maxHeight)
    {
        // …but only if actually appearing somewhere!
        if ([self textAttachment] ||
            [self isKindOfClass:[SVLogoImage class]] ||
            [[self sidebars] count])
        {
            NSUInteger elementHeight = [height unsignedIntegerValue] + [[[self plugIn] elementHeightPadding] unsignedIntegerValue];
            if (elementHeight > maxHeight)
            {
                maxHeight = MAX(maxHeight, [self minHeight]);
                [self setContentHeight:[NSNumber numberWithUnsignedInteger:maxHeight]];
            }
        }
    }
    
    
    // Pass on
    [[self plugIn] pageDidChange:page];
}

/*  Where possible (i.e. Leopard) tear down the plug-in early to avoid any KVO issues.
 *  
 *  Don't think this is required any more since plug-in is now a modelled property
 *
- (void)willTurnIntoFault
{
    [self setPlugIn:nil useSerializedProperties:NO];
}*/

#pragma mark Plug-in

- (void)populatePlugInValues:(SVPlugIn *)plugIn
{
    NSDictionary *plugInProperties = [self extensibleProperties];
    @try
    {
        for (NSString *aKey in [[plugIn class] plugInKeys])
        {
            id serializedValue = [plugInProperties objectForKey:aKey];
            [plugIn setSerializedValue:serializedValue forKey:aKey];
        }
    }
    @catch (NSException *exception)
    {
        // TODO: Log warning
    }
    
}

@dynamic plugIn;
@synthesize primitivePlugIn = _plugIn;
- (void)setPrimitivePlugIn:(SVPlugIn *)plugIn;
{
    // Tear down
    [_plugIn setValue:nil forKey:@"container"];
    [_plugIn removeObserver:self forKeyPaths:[[_plugIn class] plugInKeys]];
    [_plugIn removeObserver:self forKeyPath:@"minWidth"];
    
    // Store
    [plugIn retain];
    [_plugIn release]; _plugIn = plugIn;
    
    // Restore properties
    if (plugIn)
    {
        NSUndoManager *undoManager = [[self managedObjectContext] undoManager];
        if ([undoManager isUndoing] || [undoManager isRedoing])
        {
            [self populatePlugInValues:plugIn];
        }
    }
    
    // Observe the plug-in's properties so they can be synced back to the MOC
    [plugIn addObserver:self
            forKeyPaths:[[plugIn class] plugInKeys]
                options:0
                context:sPlugInPropertiesObservationContext];
    
    [plugIn addObserver:self forKeyPath:@"minWidth" options:0 context:sPlugInMinWidthObservationContext];
    
    // Connect
    [_plugIn setValue:self forKey:@"container"];
}

- (void)setPlugIn:(SVPlugIn *)plugIn useSerializedProperties:(BOOL)serialize;
{
    [self willChangeValueForKey:@"plugIn"];
    [self setPrimitivePlugIn:plugIn];      
    [self didChangeValueForKey:@"plugIn"];
}

- (void)loadPlugInAsNew:(BOOL)inserted;
{
    SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:[self plugInIdentifier]];
    Class plugInClass = [factory plugInClass];
    
    if (plugInClass)
    {                
        // Create plug-in object
        SVPlugIn *plugIn = [[plugInClass alloc] init];
        OBASSERTSTRING(plugIn, @"plug-in cannot be nil!");
        
        
        // When we want to start observing the plug-in depends on whether it's just been inserted, or is being de-serialized
        if (inserted)
        {
            [self setPrimitivePlugIn:plugIn];   // so as not to fire a KVO change notification
            //[self populatePlugInValues:plugIn];   // don't want this for new plug-ins
        }
        else
        {
            [plugIn setValue:self forKey:@"container"]; // cheat and call early so plug-in can locate pages
            [self populatePlugInValues:plugIn];
            
            [self setPlugIn:plugIn useSerializedProperties:NO];
            //[self setPrimitivePlugIn:plugIn];   // so as not to fire a KVO change notification
            // But wy didn't I want to fire a notification? Certainly want to for #90487
        }
        
        [plugIn release];
    }
}

@dynamic plugInIdentifier;

#pragma mark Plug-in settings storage

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sPlugInPropertiesObservationContext)
    {
        // Copy serialized value to MOC
        id serializedValue = [[self plugIn] serializedValueForKey:keyPath];
        if (serializedValue)
        {
            [self setExtensibleProperty:serializedValue forKey:keyPath];
        }
        else
        {
            [self removeExtensiblePropertyForKey:keyPath];
        }
    }
    else if (context == sPlugInMinWidthObservationContext)
    {
        NSUndoManager *undoManager = [[self managedObjectContext] undoManager];
        if (![undoManager isUndoing] && ![undoManager isRedoing])
        {
            NSNumber *minWidth = [[self plugIn] minWidth];
            if ([[self width] isLessThan:minWidth])
            {
                [self setWidth:minWidth];
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context
{
    [context incrementHeaderLevel];
    @try
    {
        NSUInteger openElements = [context openElementsCount];
            
        NSString *identifier = [self plugInIdentifier];
        if (![self shouldWriteHTMLInline])
        {
            [context startElement:@"div"];
            [context writeComment:[NSString stringWithFormat:@" %@ ", identifier]];
        }
        
        
        SVPlugIn *plugIn = [self plugIn];
        if (plugIn)
        {
            @try
            {
                [[self plugIn] writeHTML:context];
            }
            @catch (NSException *exception)
            {
                NSLog(@"Plug-in threw exception: %@ %@", [exception name], [exception reason]);
                
                // Correct open elements count if plug-in managed to break this. #88083
                if ([context openElementsCount] < openElements)
                {
                    [NSException raise:NSInternalInconsistencyException format:@"Plug-in %@ closed more elements than it opened", [self plugInIdentifier]];
                }
                else
                {
                    while ([context openElementsCount] > openElements)
                    {
                        [context endElement];
                    }
                }
            }
        }
        else
        {
            SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:[self plugInIdentifier]];
            if (factory)
            {
                [context writePlaceholderWithText:NSLocalizedString(@"Plug-in failed to load", "placeholder")
                                      options:0];
            }
            else
            {
                [context writePlaceholderWithText:[NSString stringWithFormat:NSLocalizedString(@"Plug-in not found (%@)", "placeholder"), [self plugInIdentifier]]
                                          options:0];
            }
        }
        
        
        if (![self shouldWriteHTMLInline])
        {
            [context writeComment:[NSString stringWithFormat:@" /%@ ", identifier]];
            [context endElement];
        }
    }
    @finally
    {
        [context decrementHeaderLevel];
    }
}

- (NSString *)inlineGraphicClassName;
{
    return [[self plugIn] valueForKey:@"inlineGraphicClassName"];
}

- (NSString *)parsedPlaceholderHTMLFromContext:(SVHTMLContext *)context;
{
    NSMutableString *result = [NSMutableString string];
    SVHTMLContext *context2 = [[SVHTMLContext alloc] initWithOutputWriter:result inheritFromContext:context];
    
    [[self plugIn] performSelector:@selector(writePlaceholderHTML:) withObject:context2];
    
    [context2 release];
    return result;
}

#pragma mark Metrics

- (void)setContentWidth:(NSNumber *)width;
{
    [self setWidth:width];
    
    NSNumber *ratio = [self constrainedProportionsRatio];
    if (ratio)
    {
        NSUInteger height = ([width floatValue] / [ratio floatValue]);
        if (height < 1) height = 1;
        [self setHeight:[NSNumber numberWithUnsignedInteger:height]];
    }
}
- (BOOL)validateContentWidth:(NSNumber **)width error:(NSError **)error;
{
    BOOL result = YES;
    
    if (*width && [*width unsignedIntegerValue] < [self minWidth])
    {
        *width = [NSNumber numberWithUnsignedInt:[self minWidth]];
    }
    
    return result;
}

- (NSNumber *)contentHeight;
{
    NSNumber *result = nil;
    if ([self isExplicitlySized])
    {
        result = [self height];
    }
    else
    {
        result = [super contentHeight];
    }
    
    return result;
}
- (void)setContentHeight:(NSNumber *)height;
{
    [self setHeight:height];
    
    NSNumber *ratio = [self constrainedProportionsRatio];
    if (ratio)
    {
        NSUInteger width = ([height floatValue] * [ratio floatValue]);
        if (width < 1) width = 1;
        [self setWidth:[NSNumber numberWithUnsignedInteger:width]];
    }
}
+ (NSSet *)keyPathsForValuesAffectingContentHeight; { return [NSSet setWithObject:@"plugIn.height"]; }
- (BOOL)validateContentHeight:(NSNumber **)height error:(NSError **)error;
{
    BOOL result = YES;
    
    if (*height && [*height unsignedIntegerValue] < [self minHeight])
    {
        *height = [NSNumber numberWithUnsignedInt:[self minHeight]];
    }
    
    return result;
}


- (void)makeOriginalSize; { [[self plugIn] makeOriginalSize]; }

- (NSUInteger)minWidth; { return [[[self plugIn] minWidth] unsignedIntegerValue]; }
- (NSUInteger)minHeight; { return [[[self plugIn] minHeight] unsignedIntegerValue]; }

- (BOOL)constrainsProportions; { return [[self plugIn] constrainedAspectRatio] != nil; }
- (void)setConstrainsProportions:(BOOL)constrain;
{
    [[self plugIn] setBool:constrain forKey:@"constrainsProportions"];
}

- (BOOL)isConstrainProportionsEditable;
{
    return ([[self plugIn] width] &&
            [[self plugIn] height] &&
            [[self plugIn] respondsToSelector:@selector(setConstrainedAspectRatio:)]);
}
+ (NSSet *)keyPathsForValuesAffectingIsConstrainProportionsEditable;
{
    return [NSSet setWithObjects:@"plugIn.width", @"plugIn.height", nil];
}

- (NSNumber *)constrainedProportionsRatio; { return [[self plugIn] constrainedAspectRatio]; }

- (NSNumber *)elementWidthPadding; { return [[self plugIn] elementWidthPadding]; }
- (NSNumber *)elementHeightPadding; { return [[self plugIn] elementHeightPadding]; }

#pragma mark Thumbnail

- (id <SVMedia>)thumbnailMedia;
{
    return nil;//return ([[self plugIn] thumbnailURL] ? self : nil);
}

- (NSURL *)mediaURL; { return nil; }//[[self plugIn] thumbnailURL]; }
- (NSData *)mediaData; { return nil; }
- (NSString *)preferredFilename; { return [[self mediaURL] ks_lastPathComponent]; }

- (id)imageRepresentation; { return [self mediaURL]; }
- (NSString *)imageRepresentationType;
{ 
    return ([self mediaURL] ? IKImageBrowserNSURLRepresentationType : nil);
}

#pragma mark Indexes

@dynamic indexedCollection;

#pragma mark Inspector

- (Class)inspectorFactoryClass; { return [[self plugIn] class]; }

- (id)objectToInspect; { return [self plugIn]; }

#pragma mark Pasteboard

- (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    return [[[self plugIn] class] readableTypesForPasteboard:pasteboard];
}

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    BOOL result = [super awakeFromPasteboardItems:items];
    if (result)
    {
        result = [[self plugIn] awakeFromPasteboardItems:items];
    }
    
    return result;
}

#pragma mark Serialization

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    // Deserializing identifier is tricky. #102564
    NSString *identifier = [propertyList objectForKey:@"indexedCollection"];
    if (identifier)
    {
        // Favour deserializing page over pre-existing to handle paste/duplicate nicely
        KTPage *pageToIndex = [KTPage deserializingPageForIdentifier:identifier];
        if (!pageToIndex)
        {
            pageToIndex = [KTPage pageWithUniqueID:identifier inManagedObjectContext:[self managedObjectContext]];
        }
        
        [self setIndexedCollection:pageToIndex];
    }
                               
    
    // Load plug-in
    [self loadPlugInAsNew:NO];
}

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Store indexed collection by identifier
    [propertyList setValue:[[self indexedCollection] identifier] forKey:@"indexedCollection"];
    
    // Put plug-in properties in their own dict
    [propertyList setObject:[self extensibleProperties] forKey:@"plugInProperties"];
}

#pragma mark DOM

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID
                                                  ancestorNode:(DOMNode *)node;
{
    if ([[self plugIn] isKindOfClass:[SVIndexPlugIn class]])
    {
        SVDOMController *result = [[SVIndexDOMController alloc] initWithIdName:elementID
                                                                             ancestorNode:node];
        [result setRepresentedObject:self];
        
        if ([self textAttachment])
        {
            [result bind:NSWidthBinding toObject:self withKeyPath:@"width" options:nil];
            [result setHorizontallyResizable:YES];
        }
        
        return result;
    }
    
    return [super newDOMControllerWithElementIdName:elementID ancestorNode:node];
}

- (BOOL)requiresPageLoad;
{
    return ([[self plugIn] respondsToSelector:_cmd] ? [(id)[self plugIn] requiresPageLoad] : NO);
}

@end

