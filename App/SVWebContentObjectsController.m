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
#import "SVCallout.h"
#import "KTPage.h"
#import "SVPagelet.h"
#import "SVSidebar.h"
#import "SVTextField.h"


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
    
    if ([object isKindOfClass:[SVPagelet class]])
    {
        // Remove pagelet from sidebar/callout. Delete if appropriate
        SVPagelet *pagelet = object;
        
        [[[self page] sidebar] removePageletsObject:pagelet];
        
        SVCallout *callout = [pagelet callout];
        [callout removePageletsObject:pagelet];
        if ([[callout pagelets] count] == 0)
        {
            [[[self page] managedObjectContext] deleteObject:callout];
        }
        
        if ([[pagelet sidebars] count] == 0 && ![pagelet callout])
        {
            [[pagelet managedObjectContext] deleteObject:pagelet];
        }
    }
    else if ([object isKindOfClass:[SVTextField class]])
    {
        [[[self page] managedObjectContext] deleteObject:object];
    }
}

@end
