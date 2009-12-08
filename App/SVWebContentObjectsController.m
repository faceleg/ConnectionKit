//
//  SVWebContentObjectsController.m
//  Sandvox
//
//  Created by Mike on 06/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentObjectsController.h"

#import "SVBody.h"
#import "SVBodyParagraph.h"
#import "KTPage.h"
#import "SVPagelet.h"
#import "SVSidebar.h"


@implementation SVWebContentObjectsController

- (void)dealloc
{
    [_page release];
    [super dealloc];
}

- (SVPagelet *)newPagelet;
{
    NSManagedObjectContext *moc = [[self page] managedObjectContext];
    SVPagelet *result = [SVPagelet insertNewPageletIntoManagedObjectContext:moc];
	OBASSERT(result);
    
    // Create matching first paragraph
    SVBodyParagraph *paragraph = [NSEntityDescription insertNewObjectForEntityForName:@"BodyParagraph"
                                                               inManagedObjectContext:moc];
    [paragraph setTagName:@"p"];
    [paragraph setInnerHTMLArchiveString:@"Test"];
    [[result body] addElement:paragraph];
    
    
    return [result retain]; // it's a -newFoo method
}

@synthesize page = _page;

- (void)willRemoveObject:(id)object;
{
    [super willRemoveObject:object];
    
    // For now I'm assuming all content is a pagelet
    // Remove pagelet from sidebar. Delete if appropriate
    SVPagelet *pagelet = object;
    
    [[[self page] sidebar] removePageletsObject:pagelet];
    
    if ([[pagelet sidebars] count] == 0)
    {
        [[pagelet managedObjectContext] deleteObject:pagelet];
    }
}

@end
