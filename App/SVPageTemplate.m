//
//  SVPageTemplate.m
//  Sandvox
//
//  Created by Mike on 28/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageTemplate.h"


@implementation SVPageTemplate

- (void) dealloc;
{
    [_title release];
    [_icon release];
    [_collectionPreset release];
    [_graphicIdentifier release];
    
    [super dealloc];
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
        
        aTemplate = [[SVPageTemplate alloc] init];
        [aTemplate setTitle:NSLocalizedString(@"Empty Collection", "menu item title")];
        [aTemplate setIcon:[NSImage imageNamed:@"toolbar_empty_page"]];
        //[buffer addObject:aTemplate];
        [aTemplate release];
        
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
    
    //[result setRepresentedObject:self];
    
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
