//
//  SVContentPlugIn.m
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVElementPlugIn.h"
#import "SVPageProtocol.h"

#import "KTAbstractHTMLPlugin.h"
#import "KTAbstractPage.h"
#import "SVRichText.h"
#import "SVDOMController.h"
#import "SVElementPlugInContainer.h"
#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "SVSidebar.h"
#import "KTSite.h"

#import "NSManagedObject+KTExtensions.h"


NSString *SVPageWillBeDeletedNotification = @"SVPageWillBeDeleted";


@interface SVElementPlugIn ()
@property(nonatomic, retain) id delegateOwner;
@end


@interface SVElementPlugIn (SVElementPlugInContainer) <SVElementPlugInContainer>
- (KTSite *)site;
@end


#pragma mark -


@implementation SVElementPlugIn

#pragma mark Init

+ (SVElementPlugIn *)elementPlugInWithArguments:(NSDictionary *)propertyStorage;
{
    return [[[self alloc] initWithArguments:propertyStorage] autorelease];
}

- (id)initWithArguments:(NSDictionary *)storage;
{
    self = [self init];
    
    _container = [[storage objectForKey:@"Container"] retain];
    if (!_container) _container = self;
    
    return self;
}

- (void)dealloc
{
    if (_container != self) [_container release];
    
    [super dealloc];
}

#pragma mark Content

- (void)writeHTML;
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    [context willBeginWritingContentObject:self];
    [self writeInnerHTML];
    [context didEndWritingContentObject];
    
    return;
    
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

- (KTAbstractPage *)page
{
    return [[[[self delegateOwner] sidebars] anyObject] page];
    
    
    SVRichText *body = [[self delegateOwner] enclosingBody];
    
    KTAbstractPage *result = nil;
    if ([[[body entity] name] isEqualToString:@"PageBody"])
    {
        result = [body valueForKey:@"page"];
    }
    else if ([[[body entity] name] isEqualToString:@"TextBoxBody"])
    {
        SVSidebar *aSidebar = [[(SVGraphic *)[body valueForKey:@"pagelet"] sidebars] anyObject];
        result = [aSidebar page];
    }
    
    return result;
}

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


@implementation SVElementPlugIn (SVElementPlugInContainer)

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


@implementation SVElementPlugIn (SVPage)

- (id <SVPage>)pageWithIdentifier:(NSString *)identifier;
{
    KTAbstractPage *result = [KTAbstractPage pageWithUniqueID:identifier
                                       inManagedObjectContext:[[self delegateOwner] managedObjectContext]];
    return result;
}

@end
