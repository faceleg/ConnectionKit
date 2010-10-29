//
//  SVPageTemplate.m
//  Sandvox
//
//  Created by Mike on 28/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageTemplate.h"

#import "KTElementPlugInWrapper.h"

#import "NSSet+Karelia.h"


@implementation SVPageTemplate

- (id)initWithCollectionPreset:(NSDictionary *)presetDict;
{
    [self init];
    [self setCollectionPreset:presetDict];
    
    NSString *bundleIdentifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
    
    KTElementPlugInWrapper *plugin = (bundleIdentifier ?
                                      [KTElementPlugInWrapper pluginWithIdentifier:bundleIdentifier] :
                                      nil);
    
    NSString *presetTitle = [presetDict objectForKey:@"KTPresetTitle"];
    if (plugin) presetTitle = [[plugin bundle] localizedStringForKey:presetTitle
                                                               value:presetTitle
                                                               table:nil];
    [self setTitle:presetTitle];
    
    
    id priorityID = [presetDict objectForKey:@"KTPluginPriority"];
    int priority = 5;
    if (nil != priorityID)
    {
        priority = [priorityID intValue];
    } 
    
    
    NSImage *icon = nil;
    if (plugin)
    {
        icon = [[plugin graphicFactory] icon];
#ifdef DEBUG
        if (nil == icon)
        {
            NSLog(@"nil pluginIcon for %@", presetTitle);
        }
#endif
    }
    else	// built-in, no bundle, so try to get icon directly
    {
        icon = [presetDict objectForKey:@"KTPluginIcon"];
    }
    [self setIcon:icon];
    
    
    
    return self;
}

- (void) dealloc;
{
    [_title release];
    [_icon release];
    [_collectionPreset release];
    [_graphicIdentifier release];
    
    [super dealloc];
}

+ (NSArray *)collectionPresets;
{
    // Order plug-ins first by priority, then by name
    //      I've turned off priority support for now to try a pure alphabetical approach - Mike
    //NSSortDescriptor *prioritySort = [[NSSortDescriptor alloc] initWithKey:@"priority"
    //                                                             ascending:YES];
    NSSortDescriptor *nameSort = [[NSSortDescriptor alloc]
                                  initWithKey:@"KTPresetTitle"
                                  ascending:YES
                                  selector:@selector(caseInsensitiveCompare:)];
    
    NSArray *sortDescriptors = [NSArray arrayWithObjects:/*prioritySort, */nameSort, nil];
    //[prioritySort release];
    [nameSort release];
    
    NSArray *result = [[KTElementPlugInWrapper collectionPresets]
                       KS_sortedArrayUsingDescriptors:sortDescriptors];
    return result;
}

+ (NSArray *)pageTemplates;
{
    static NSArray *result;
    
    if (!result)
    {
        NSMutableArray *buffer = [[NSMutableArray alloc] init];
        SVPageTemplate *aTemplate;
        
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Empty/Text", "New page pulldown button menu item title")];
        [aTemplate setIcon:[NSImage imageNamed:@"toolbar_empty_page"]];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Empty/Text – Without Sidebar", "menu item title")];
        [aTemplate setIcon:[NSImage imageNamed:@"toolbar_empty_page"]];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Photo/Video", "menu item title")];
        [aTemplate setIcon:[NSImage imageNamed:@"toolbar_empty_page"]];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Photo/Video – Without Sidebar", "menu item title")];
        [aTemplate setIcon:[NSImage imageNamed:@"toolbar_empty_page"]];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
        
        // Collection Presets
        for (NSDictionary *aPreset in [self collectionPresets])
        {
            aTemplate = [[SVPageTemplate alloc] initWithCollectionPreset:aPreset];            
            [buffer addObject:aTemplate];
            [aTemplate release];
        }
        
        
        // One-shot pages
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Contact Form", "menu item title")];
        [aTemplate setIcon:[NSImage imageNamed:@"toolbar_empty_page"]];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Sitemap", "menu item title")];
        [aTemplate setIcon:[NSImage imageNamed:@"toolbar_empty_page"]];
        [buffer addObject:aTemplate];
        [aTemplate release];
        
                
        result = [buffer copy];
        [buffer release];
    }
    
    return result;
}

@synthesize title = _title;
@synthesize icon = _icon;
@synthesize collectionPreset = _collectionPreset;
@synthesize graphicIdentifier = _graphicIdentifier;

- (NSMenuItem *)makeMenuItem;
{
    NSMenuItem *result = [[NSMenuItem alloc] initWithTitle:[self title]
                                                    action:@selector(addPage:)
                                             keyEquivalent:@""];
    
    NSImage *icon = [[self icon] copy];
    [icon setSize:NSMakeSize(48.0f, 48.0f)];
    [result setImage:icon];
    [icon release];
    
    [result setRepresentedObject:self];
    
    return [result autorelease];
}

+ (void)populateMenu:(NSMenu *)menu withPageTemplates:(NSArray *)templates index:(NSUInteger)index;
{
    for (SVPageTemplate *aTemplate in templates)
    {
        NSMenuItem *menuItem = [aTemplate makeMenuItem];
        [menu insertItem:menuItem atIndex:index];
        index++;
    }
}

@end
