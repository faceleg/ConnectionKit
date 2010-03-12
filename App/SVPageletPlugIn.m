//
//  SVContentPlugIn.m
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletPlugIn.h"
#import "SVPageProtocol.h"

#import "KTAbstractHTMLPlugin.h"
#import "KTPage.h"
#import "SVRichText.h"
#import "SVDOMController.h"
#import "SVPlugIn.h"
#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "SVSidebar.h"
#import "KTSite.h"

#import "NSManagedObject+KTExtensions.h"


NSString *SVPageWillBeDeletedNotification = @"SVPageWillBeDeleted";


@interface SVPageletPlugIn ()
@property(nonatomic, retain) id delegateOwner;
@end


@interface SVPageletPlugIn (SVPageletPlugInContainer) <SVPageletPlugInContainer>
- (KTSite *)site;
@end


#pragma mark -


@implementation SVPageletPlugIn

#pragma mark Initialization & Tear Down

+ (id <SVPageletPlugIn>)newPlugInWithArguments:(NSDictionary *)propertyStorage;
{
    return [[self alloc] initWithArguments:propertyStorage];
}

- (id)initWithArguments:(NSDictionary *)storage;
{
    self = [self init];
    
    _container = [[storage objectForKey:@"Container"] retain];
    if (!_container) _container = self;
    
    return self;
}

- (void)awakeFromFetch;
{
    [self awakeFromBundleAsNewlyCreatedObject:NO];
}

- (void)awakeFromInsertIntoPage:(id <SVPage>)page
                     pasteboard:(NSPasteboard *)pasteboard
                       userInfo:(NSDictionary *)info
{
    // Load initial properties from bundle
    NSBundle *bundle = [self bundle];
    NSDictionary *localizedInfoDictionary = [bundle localizedInfoDictionary];
    NSDictionary *initialProperties = [bundle objectForInfoDictionaryKey:@"KTPluginInitialProperties"];
    
    for (NSString *aKey in initialProperties)
    {
        #warning FIXME -- temp until this is fixed.
        if ([aKey isEqualToString:@"showBorder"]) break;
        
        id value = [initialProperties objectForKey:aKey];
        if ([value isKindOfClass:[NSString class]])
        {
            // Try to localize the string
            NSString *localized = [localizedInfoDictionary objectForKey:aKey];
            if (localized) value = localized;
        }
        
        [self setSerializedValue:value forKey:aKey];
    }
    
    
    // Legacy
    [self awakeFromBundleAsNewlyCreatedObject:YES];
    if (pasteboard) [self awakeFromDragWithDictionary:info];
}

- (void)dealloc
{
    if (_container != self) [_container release];
    
    [super dealloc];
}

#pragma mark Content

- (void)writeHTML;
{
    [self writeInnerHTML];
    
    return;
    
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    [context writeStartTag:@"div" idName:[self elementID] className:nil];
    [self writeInnerHTML];
    [context writeEndTag];
}

- (NSString *)elementID
{
    NSString *result = [NSString stringWithFormat:@"%p", self];
    return result;
}

- (void)writeInnerHTML;
{
    // Parse our built-in template
    NSString *template = [[[self delegateOwner] plugin] templateHTMLAsString];
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:template
                                                                        component:self];
    
    [parser parse];
    [parser release];
}

#pragma mark Storage

+ (NSSet *)plugInKeys; { return nil; }

- (id)serializedValueForKey:(NSString *)key;
{
    id result = [self valueForKey:key];
    
    if (![result isKindOfClass:[NSString class]] &&
        ![result isKindOfClass:[NSNumber class]] &&
        ![result isKindOfClass:[NSDate class]])
    {
        result = [NSKeyedArchiver archivedDataWithRootObject:result];
    }
    
    return result;
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;
{
    if ([serializedValue isKindOfClass:[NSData class]])
    {
        serializedValue = [NSKeyedUnarchiver unarchiveObjectWithData:serializedValue];
    }
    
    [self setValue:serializedValue forKey:key];
}

#pragma mark The Wider World

- (NSBundle *)bundle { return [NSBundle bundleForClass:[self class]]; }

#pragma mark Undo Management

- (void)disableUndoRegistration;
{
    NSUndoManager *undoManager = [[[self site] managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    
    [undoManager disableUndoRegistration];
}

- (void)enableUndoRegistration;
{
    NSUndoManager *undoManager = [[[self site] managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    
    [undoManager enableUndoRegistration];
}

#pragma mark UI

+ (Class)inspectorViewControllerClass; { return nil; }
+ (Class)DOMControllerClass; { return [SVDOMController class]; }

#pragma mark Other

@synthesize elementPlugInContainer = _container;

#pragma mark Legacy

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject { }
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary { }		// we may want to do something different.

@synthesize delegateOwner = _delegateOwner;

@end


#pragma mark -


@implementation SVPageletPlugIn (SVPageletPlugInContainer)

- (KTSite *)site;
{
    KTSite *result = [[self page] site];
    return result;
}

- (NSString *)siteObjectIDURIRepresentationString;  // unique per site. used by Badge plug-in
{
    return [[self site] URIRepresentationString];
}

- (NSString *)languageCode;	// used by ContactElementDelegate
{
	NSString *language = [[[self page] master] language];
	return language;
}

@end


#pragma mark -


@implementation SVPageletPlugIn (SVPage)

- (id <SVPage>)pageWithIdentifier:(NSString *)identifier;
{
    KTPage *result = [KTPage pageWithUniqueID:identifier
                                       inManagedObjectContext:[[self delegateOwner] managedObjectContext]];
    return result;
}

@end
