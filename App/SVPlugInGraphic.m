//
//  SVPlugInGraphic.m
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugInGraphic.h"

#import "SVDOMController.h"
#import "SVMediaProtocol.h"
#import "SVPlugIn.h"
#import "SVGraphicFactory.h"
#import "SVHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"


static NSString *sPlugInPropertiesObservationContext = @"PlugInPropertiesObservation";


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

+ (SVPlugInGraphic *)insertNewGraphicWithPlugIn:(SVPlugIn *)plugIn
                         inManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPlugInGraphic *result =
    [NSEntityDescription insertNewObjectForEntityForName:@"PlugInGraphic"    
                                  inManagedObjectContext:context];
    
    [result setValue:[[plugIn class] plugInIdentifier] forKey:@"plugInIdentifier"];
    
    
    [result setPlugIn:plugIn useSerializedProperties:YES];  // passing YES to copy the current properties out of the plug-in
    
    
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

- (void)awakeFromNew; { [[self plugIn] awakeFromNew]; }

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
    
    // Start off at a decent size
    if ([[[self plugIn] class] isExplicitlySized])
    {
        NSUInteger maxWidth = 490;
        if ([self isPagelet]) maxWidth = 200;
        
        NSUInteger elementWidth = [[self width] unsignedIntegerValue] + [[[self plugIn] elementWidthPadding] unsignedIntegerValue];
        if (elementWidth > maxWidth)
        {
            [self setSizeWithWidth:[NSNumber numberWithUnsignedInteger:maxWidth] height:nil];
        }
    }
    
    // Pass on
    [[self plugIn] didAddToPage:page];
}

/*  Where possible (i.e. Leopard) tear down the delegate early to avoid any KVO issues.
 */
- (void)willTurnIntoFault
{
    [self setPlugIn:nil useSerializedProperties:NO];
}

#pragma mark Plug-in

@dynamic plugIn;
@synthesize primitivePlugIn = _plugIn;
- (void)setPrimitivePlugIn:(SVPlugIn *)plugIn;
{
    // Tear down
    [_plugIn setValue:nil forKey:@"container"];
    [_plugIn removeObserver:self forKeyPaths:[[_plugIn class] plugInKeys]];
    
    // Store
    [plugIn retain];
    [_plugIn release]; _plugIn = plugIn;
    
    // Observe the plug-in's properties so they can be synced back to the MOC
    [plugIn addObserver:self
            forKeyPaths:[[plugIn class] plugInKeys]
                options:0
                context:sPlugInPropertiesObservationContext];
    
    // Connect
    [_plugIn setValue:self forKey:@"container"];
}

- (void)setPlugIn:(SVPlugIn *)plugIn useSerializedProperties:(BOOL)serialize;
{
    [self willChangeValueForKey:@"plugIn"];
    [self setPrimitivePlugIn:plugIn];      
    [self didChangeValueForKey:@"plugIn"];
}

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
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context
{
    NSString *identifier = [self plugInIdentifier];
    
    NSUInteger openElements = [context openElementsCount];
    
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
        
        // Correct open elements count if plug-in managed to break this. #88083
        while ([context openElementsCount] > openElements)
        {
            [context endElement];
        }
    }
    
    [context writeComment:[NSString stringWithFormat:@" /%@ ", identifier]];
    
    [context setCurrentHeaderLevel:level];
}

// This was an experiment with including plug-in's classname up at the highest level, but that ruins sizing
- (void)XbuildClassName:(SVHTMLContext *)context;
{
    [super buildClassName:context];
    
    if ([[self placement] intValue] == SVGraphicPlacementInline)
    {
        NSString *className = [[self plugIn] inlineGraphicClassName];
        if (className) [context pushClassName:className];
    }
}

- (NSString *)inlineGraphicClassName;
{
    return [[self plugIn] inlineGraphicClassName];
}

#pragma mark Metrics

- (void)setSizeWithWidth:(NSNumber *)width height:(NSNumber *)height;
{
    if ([self constrainProportions])
    {
        CGFloat constraintRatio = [[[self plugIn] constrainedAspectRatio] floatValue];
        
        
        if (width && height)
        {
            CGFloat aspectRatio = [width floatValue] / [height floatValue];
            
            if (aspectRatio < constraintRatio)
            {
                width = nil;
            }
            else
            {
                height = nil;
            }
        }
        
        
        // Apply the constraint
        OBASSERT(!(width && height));
        
        if (width)
        {
            height = [NSNumber numberWithUnsignedInteger:([width floatValue] / constraintRatio)];
        }
        else if (height)
        {
            width = [NSNumber numberWithUnsignedInteger:([height floatValue] * constraintRatio)];
        }
    }
    else
    {
        if (!height) height = [self height];
        if (!width) width = [self width];
    }
    
    // Store
    [[self plugIn] setWidth:width height:height];
}

- (NSNumber *)contentWidth;
{
    NSNumber *result = nil;
    if ([self isExplicitlySized] || [[self placement] intValue] == SVGraphicPlacementInline)
    {
        result = [self width];
    }
    else
    {
        result = NSNotApplicableMarker;
    }
    
    return result;
}
- (void)setContentWidth:(NSNumber *)width;
{
    [self setSizeWithWidth:width height:nil];
}
+ (NSSet *)keyPathsForValuesAffectingContentWidth; { return [NSSet setWithObject:@"width"]; }
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
        result = NSNotApplicableMarker;
    }
    
    return result;
}
- (void)setContentHeight:(NSNumber *)height;
{
    [self setSizeWithWidth:nil height:height];
}
+ (NSSet *)keyPathsForValuesAffectingContentHeight; { return [NSSet setWithObject:@"height"]; }
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

- (BOOL)isExplicitlySized; { return [[[self plugIn] class] isExplicitlySized]; }

- (NSUInteger)minWidth; { return [[self plugIn] minWidth]; }
- (NSUInteger)minHeight; { return [[self plugIn] minHeight]; }


- (BOOL)constrainProportions; { return [[self plugIn] constrainedAspectRatio] != nil; }
- (void)setConstrainProportions:(BOOL)constrain;
{
    [[self plugIn] setBool:constrain forKey:@"constrainProportions"];
}

- (BOOL)isConstrainProportionsEditable;
{
    return ([self width] &&
            [self height] &&
            [[self plugIn] respondsToSelector:@selector(setConstrainedAspectRatio:)]);
}

- (NSNumber *)constrainedProportionsRatio; { return [[self plugIn] constrainedAspectRatio]; }

#pragma mark Thumbnail

- (id <SVMedia>)thumbnailMedia;
{
    return ([[self plugIn] thumbnailURL] ? self : nil);
}

- (CGFloat)thumbnailAspectRatio;
{
    CIImage *image = [[CIImage alloc] initWithContentsOfURL:[self mediaURL]];
    CGSize size = [image extent].size;
    CGFloat result = size.width / size.height;
    [image release];
    return result;
}

- (NSURL *)mediaURL; { return [[self plugIn] thumbnailURL]; }
- (NSData *)mediaData; { return nil; }
- (NSString *)preferredFilename; { return [[self mediaURL] ks_lastPathComponent]; }

- (id)imageRepresentation; { return [self mediaURL]; }
- (NSString *)imageRepresentationType;
{ 
    return ([self mediaURL] ? IKImageBrowserNSURLRepresentationType : nil);
}

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
    return [[self plugIn] awakeFromPasteboardItems:items];
}

#pragma mark Serialization

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    [self loadPlugInAsNew:NO];
}

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Put plug-in properties in their own dict
    [propertyList setObject:[self extensibleProperties] forKey:@"plugInProperties"];
}

@end
