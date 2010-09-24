//
//  SVContentPlugIn.m
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugIn.h"
#import "SVPageProtocol.h"

#import "KTDataSourceProtocol.h"
#import "KTElementPlugInWrapper.h"
#import "SVRichText.h"
#import "SVDOMController.h"
#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "SVInspectorViewController.h"
#import "SVIndexInspectorViewController.h"
#import "SVIndexPlugIn.h"
#import "KTPage.h"
#import "SVPlugIn.h"
#import "SVSidebar.h"
#import "SVTemplate.h"

#import "NSBundle+KTExtensions.h"

#import "NSManagedObject+KTExtensions.h"


NSString *SVPageWillBeDeletedNotification = @"SVPageWillBeDeleted";


@interface SVPlugIn ()
@property(nonatomic, assign, readwrite) id container;
@end


#pragma mark -


@implementation SVPlugIn

#pragma mark Initialization & Tear Down

- (void)awakeFromFetch;
{
    [self awakeFromBundleAsNewlyCreatedObject:NO];
}

- (void)awakeFromNew;
{
    // Load initial properties from bundle
    NSBundle *bundle = [self bundle];
    NSDictionary *localizedInfoDictionary = [bundle localizedInfoDictionary];
    NSDictionary *initialProperties = [bundle objectForInfoDictionaryKey:@"KTPluginInitialProperties"];
    
    for (NSString *aKey in initialProperties)
    {
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
    
    
    // Size
    [self makeOriginalSize];
}

- (void)dealloc
{
    [_template release];
    
    [super dealloc];
}

#pragma mark HTML

static id <SVPlugInContext> sCurrentContext;

- (void)writeHTML:(id <SVPlugInContext>)context;
{
    // add any KTPluginCSSFilesNeeded
    NSArray *cssFiles = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"KTPluginCSSFilesNeeded"];
    for ( NSString *filename in cssFiles )
    {
        NSString *cssPath = [[NSBundle bundleForClass:[self class]] pathForResource:filename ofType:nil];
        if ( cssPath )
        {
            NSURL *cssURL = [NSURL fileURLWithPath:cssPath];
            [context addCSSWithURL:cssURL];
        }
    }
    
    
    sCurrentContext = context;
    [self writeInnerHTML:context];
    sCurrentContext = nil;
}

+ (id <SVPlugInContext>)currentContext; { return sCurrentContext; }

- (SVTemplate *)HTMLTemplate;
{
    if (!_template)
    {
        // Is there already a globally cached template for us to use?
        NSString *templateName = [self className];
        _template = [SVTemplate templateNamed:templateName];    // it'll be retained in a mo'
        if (_template)
        {
            [_template retain];
        }
        else
        {
            // Have to read in from disk directly then
            NSString *fileName = [[self bundle] objectForInfoDictionaryKey:@"KTTemplateName"];
            if ( !fileName )
            {
                NSString *className = [[self bundle] objectForInfoDictionaryKey:@"NSPrincipalClass"]; OBASSERT(className);
                fileName = [className stringByReplacing:@"PlugIn" with:@"Template"];
            }
            if (!fileName) fileName = @"template";
            
            NSString *path = [[self bundle] pathForResource:fileName ofType:@"html"];
            if (path)
            {
                _template = [[SVTemplate alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
                
                // Add to global cache for benefit of other plug-in instances
                [(SVTemplate *)_template setName:templateName];
            }
        }
    }
    
    return _template;
}

- (void)writeInnerHTML:(id <SVPlugInContext>)context;
{
    // Parse our built-in template
    SVTemplate *template = [self HTMLTemplate];
    if ( template )
    {
        SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[template templateString]
                                                                            component:self];
        
        [parser parseIntoHTMLContext:(SVHTMLContext *)context];
        [parser release];
    }
    else if ( [[self bundle] objectForInfoDictionaryKey:@"KTTemplateName"] )
    {
        OBPRECONDITION(template); // we're defining a template in Info.plist but there isn't one there!
    }	
}

- (NSString *)inlineGraphicClassName;
{
    NSString *result = [[self bundle] objectForInfoDictionaryKey:@"KTCSSClassName"];
    return result;
}

#pragma mark Identifier

+ (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
    NSBundle *bundle = [NSBundle bundleForClass:self];
    NSString *result = [bundle bundleIdentifier];
    return result;
}

#pragma mark Storage

+ (NSArray *)plugInKeys; { return [NSArray array]; }

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

#pragma mark Layout

- (NSString *)title { return [_container title]; }
- (void)setTitle:(NSString *)title { [_container setTitle:title]; }

- (BOOL)showsTitle { return [_container showsTitle]; }
- (void)setShowsTitle:(BOOL)show { [_container setShowsTitle:show]; }

- (BOOL)showsIntroduction { return [_container showsIntroduction]; }
- (void)setShowsIntroduction:(BOOL)show { [_container setShowsIntroduction:show]; }

- (BOOL)showsCaption { return [_container showsCaption]; }
- (void)setShowsCaption:(BOOL)show { [_container setShowsCaption:show]; }

- (BOOL)isBordered { return [_container isBordered]; }
- (void)setBordered:(BOOL)show { [_container setBordered:show]; }

#pragma mark Metrics

- (NSUInteger)width; { return [[(SVGraphic *)[self container] width] unsignedIntegerValue]; }
- (void)setWidth:(NSUInteger)width;
{
    NSNumber *widthValue = (width ? [NSNumber numberWithUnsignedInteger:width] : nil);
    [(SVGraphic *)[self container] setWidth:widthValue];
}
+ (NSSet *)keyPathsForValuesAffectingWidth;
{
    return [NSSet setWithObject:@"container.width"];
}

- (NSUInteger)height; { return [[(SVGraphic *)[self container] height] unsignedIntegerValue]; }
- (void)setHeight:(NSUInteger)height;
{
    NSNumber *heightValue = (height ? [NSNumber numberWithUnsignedInteger:height] : nil);
    [(SVGraphic *)[self container] setHeight:heightValue];
}
+ (NSSet *)keyPathsForValuesAffectingHeight;
{
    return [NSSet setWithObject:@"container.height"];
}

- (NSUInteger)minWidth; { return 200; }
- (NSUInteger)minHeight; { return 1; }

- (BOOL)constrainProportions; { return NO; }

- (void)makeOriginalSize;
{
    [self setWidth:200];
    [self setHeight:0];
}

+ (BOOL)isExplicitlySized; { return NO; }

#pragma mark Pages

- (void)didAddToPage:(id <SVPage>)page; { }

#pragma mark Thumbnail

- (NSURL *)thumbnailURL; { return nil; }

#pragma mark The Wider World

- (NSBundle *)bundle { return [NSBundle bundleForClass:[self class]]; }

#if DEBUG
- (id)link; { return NSNotApplicableMarker; }   // dirty hack to stop Inspector throwing exceptions
#endif

#pragma mark UI

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = nil;
    
    // Take a stab at Inspector class name
    NSString *className = [NSStringFromClass([self class])
                           stringByReplacing:@"PlugIn" with:@"Inspector"];
    
    
    // Take a stab at Inspector nib
    NSBundle *bundle = [NSBundle bundleForClass:self];
    NSString *nibName = [bundle objectForInfoDictionaryKey:@"KTPluginNibFile"];
    if ( !nibName ) nibName = className;
    
    Class class = NSClassFromString(className);
    if (!class && nibName)
    {
        // are we an Index?
        Class PrincipalClass = [bundle principalClass];
        if ( [PrincipalClass isSubclassOfClass:[SVIndexPlugIn class]] )
        {
            class = [SVIndexInspectorViewController class];
        }
        else 
        {
            class = [SVInspectorViewController class];
        }
    }
    else if (![class isSubclassOfClass:[SVInspectorViewController class]])
    {
        class = nil;
    }
    
    if ( nil == [bundle pathForResource:nibName ofType:@"nib"] )
    {
        nibName = nil;
    }
    
    
    // Make Inspector
    if (nibName || class)
    {
        result = [[class alloc] initWithNibName:nibName bundle:bundle];
        [result setTitle:[[bundle localizedInfoDictionary] objectForKey:@"KTPluginName"]];
        [result autorelease];
    }
    
    return result;
}

#pragma mark Undo

- (void)disableUndoRegistration;
{
    NSUndoManager *undoManager = [[_container managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    
    [undoManager disableUndoRegistration];
}

- (void)enableUndoRegistration;
{
    NSUndoManager *undoManager = [[_container managedObjectContext] undoManager];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    
    [undoManager enableUndoRegistration];
}

#pragma mark Other

@synthesize container = _container;

#pragma mark Legacy

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard; { return nil; }

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject { }
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary { }		// we may want to do something different.

@end


#pragma mark -


@implementation SVPlugIn (SVPage)

- (id <SVPage>)pageWithIdentifier:(NSString *)identifier;
{
    KTPage *result = [KTPage
                      pageWithUniqueID:identifier
                      inManagedObjectContext:[(NSManagedObject *)[self container] managedObjectContext]];
    return result;
}

@end
