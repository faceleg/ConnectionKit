//
//  SVContentPlugIn.m
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletPlugIn.h"
#import "SVPageProtocol.h"

#import "KTDataSourceProtocol.h"
#import "KTHTMLPlugInWrapper.h"
//#import "KTPage.h"
#import "SVRichText.h"
#import "SVDOMController.h"
#import "SVPlugIn.h"
#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "SVSidebar.h"
#import "SVTemplate.h"

#import "NSBundle+KTExtensions.h"

#import "NSManagedObject+KTExtensions.h"


NSString *SVPageWillBeDeletedNotification = @"SVPageWillBeDeleted";


@interface SVPageletPlugIn ()
@end


#pragma mark -


@implementation SVPageletPlugIn

#pragma mark Initialization & Tear Down

- (void)awakeFromFetch;
{
    [self awakeFromBundleAsNewlyCreatedObject:NO];
}

- (void)awakeFromInsertIntoPage:(id <SVPage>)page;
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
}

- (void)dealloc
{
    if (_container != self) [_container release];
    
    [super dealloc];
}

#pragma mark Content

- (void)writeHTML:(id <SVPlugInContext>)context;
{
    [self writeInnerHTML:context];
    
    return;
        
    [[context HTMLWriter] writeStartTag:@"div" idName:[self elementID] className:nil];
    [self writeInnerHTML:context];
    [[context HTMLWriter] writeEndTag];
}

- (NSString *)elementID
{
    NSString *result = [NSString stringWithFormat:@"%p", self];
    return result;
}

- (void)writeInnerHTML:(id <SVPlugInContext>)context;
{
    // Parse our built-in template
    SVTemplate *template = [[self bundle] HTMLTemplate];
	
    SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[template templateString]
                                                                        component:self];
    
    [parser parseIntoHTMLContext:(SVHTMLContext *)context];
    [parser release];
}

#pragma mark Identifier

+ (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
    NSBundle *bundle = [NSBundle bundleForClass:self];
    NSString *result = [bundle bundleIdentifier];
    return result;
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

- (void)setNilValueForKey:(NSString *)key;  // default implementation calls -setValue:forKey: with 0 number
{
    [self setValue:[NSNumber numberWithInteger:0] forKey:key];
}

#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail; { return nil; }

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

#pragma mark Pasteboard

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    NSArray *result = nil;
    if ([self conformsToProtocol:@protocol(KTDataSource)])
    {
        result = [(Class <KTDataSource>)self supportedPasteboardTypesForCreatingPagelet:YES];
    }
    
    return result;
}

#pragma mark Legacy

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject { }
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary { }		// we may want to do something different.

@end


#pragma mark -


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
